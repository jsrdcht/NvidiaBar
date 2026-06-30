import Foundation

struct SSHInvocation {
    let executablePath: String
    let arguments: [String]
    let cleanupURLs: [URL]

    init(
        executablePath: String,
        arguments: [String],
        cleanupURLs: [URL] = []
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.cleanupURLs = cleanupURLs
    }

    func cleanup() {
        let fileManager = FileManager.default
        for url in cleanupURLs {
            try? fileManager.removeItem(at: url)
        }
    }
}

struct SSHInvocationBuilder {
    let timeout: TimeInterval

    init(timeout: TimeInterval = 15) {
        self.timeout = timeout
    }

    func build(for config: ServerConfig, remoteCommand: String) throws -> SSHInvocation {
        if config.usesPasswordAuthentication {
            return try buildPasswordInvocation(for: config, remoteCommand: remoteCommand)
        }

        let sshArguments = try buildSSHArguments(for: config, remoteCommand: remoteCommand, batchMode: true)
        return SSHInvocation(
            executablePath: "/usr/bin/env",
            arguments: ["ssh"] + sshArguments
        )
    }

    /// 构建一条常驻的 SSH 本地端口转发命令（`ssh -N -L ...`）。
    func buildForwarding(
        for config: ServerConfig,
        localPort: Int,
        remoteHost: String,
        remotePort: Int
    ) throws -> SSHInvocation {
        if config.usesPasswordAuthentication {
            let arguments = try buildForwardingArguments(
                for: config,
                localPort: localPort,
                remoteHost: remoteHost,
                remotePort: remotePort,
                batchMode: false
            )
            let scriptURL = try writeExpectScript(prefix: "NvidiaBarTunnel", content: tunnelExpectScript)
            return SSHInvocation(
                executablePath: "/usr/bin/expect",
                arguments: [scriptURL.path, config.trimmedPassword] + arguments,
                cleanupURLs: [scriptURL]
            )
        }

        let arguments = try buildForwardingArguments(
            for: config,
            localPort: localPort,
            remoteHost: remoteHost,
            remotePort: remotePort,
            batchMode: true
        )
        return SSHInvocation(
            executablePath: "/usr/bin/env",
            arguments: ["ssh"] + arguments
        )
    }

    private func buildForwardingArguments(
        for config: ServerConfig,
        localPort: Int,
        remoteHost: String,
        remotePort: Int,
        batchMode: Bool
    ) throws -> [String] {
        // 仅绑定到本机回环地址，避免把转发端口暴露到局域网。
        var arguments = [
            "-o", "ConnectTimeout=\(Int(timeout))",
            "-o", "ExitOnForwardFailure=yes",
            "-o", "ServerAliveInterval=30",
            "-o", "ServerAliveCountMax=3",
            "-S", "none",
            "-N",
            "-L", "127.0.0.1:\(localPort):\(remoteHost):\(remotePort)"
        ]

        if batchMode {
            arguments += ["-o", "BatchMode=yes"]
        }

        if config.connectionMode == .direct {
            arguments += ["-p", String(config.normalizedPort)]

            let identityFile = config.expandedIdentityFile
            if !identityFile.isEmpty {
                arguments += ["-i", identityFile]
            }
        }

        arguments.append(try config.sshTarget())
        return arguments
    }

    private func buildPasswordInvocation(for config: ServerConfig, remoteCommand: String) throws -> SSHInvocation {
        let sshArguments = try buildSSHArguments(for: config, remoteCommand: remoteCommand, batchMode: false)
        let scriptURL = try writeExpectScript(prefix: "NvidiaBarExpect", content: expectScript)
        return SSHInvocation(
            executablePath: "/usr/bin/expect",
            arguments: [scriptURL.path, config.trimmedPassword] + sshArguments,
            cleanupURLs: [scriptURL]
        )
    }

    private func buildSSHArguments(
        for config: ServerConfig,
        remoteCommand: String,
        batchMode: Bool
    ) throws -> [String] {
        var arguments = [
            "-o", "ConnectTimeout=\(Int(timeout))",
            "-o", "ClearAllForwardings=yes",
            "-o", "ServerAliveInterval=10",
            "-o", "ServerAliveCountMax=1",
            "-S", "none"
        ]

        if batchMode {
            arguments += ["-o", "BatchMode=yes"]
        }

        if config.connectionMode == .direct {
            arguments += ["-p", String(config.normalizedPort)]

            let identityFile = config.expandedIdentityFile
            if !identityFile.isEmpty {
                arguments += ["-i", identityFile]
            }
        }

        arguments.append(try config.sshTarget())
        arguments.append(remoteCommand)
        return arguments
    }

    private var expectScript: String {
        """
        set timeout \(Int(timeout))
        set password [lindex $argv 0]
        set sshArgs [lrange $argv 1 end]
        spawn -noecho ssh {*}$sshArgs
        expect {
            -re {(?i)are you sure you want to continue connecting} {
                send -- "yes\\r"
                exp_continue
            }
            -re {(?i)(password|passphrase).*:} {
                send -- "$password\\r"
                exp_continue
            }
            timeout {
                puts stderr "ssh authentication timed out"
                exit 124
            }
            eof
        }
        catch wait result
        set exitCode [lindex $result 3]
        exit $exitCode
        """
    }

    private func writeExpectScript(prefix: String, content: String) throws -> URL {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString).exp")
        try content.write(to: scriptURL, atomically: true, encoding: .utf8)
        return scriptURL
    }

    /// 与 `expectScript` 类似，但用于常驻隧道：处理完认证提示后让隧道保持存活。
    ///
    /// 关键点：当使用密钥认证成功时，`ssh -N` 不会出现密码提示、也不会产生任何输出，
    /// 因此初始 `expect` 的 timeout 不能当作失败（否则会误杀隧道）；这里把 timeout
    /// 视为“认证已完成”，随后取消超时并等待真正的 eof（连接断开）。
    private var tunnelExpectScript: String {
        """
        set timeout \(Int(timeout))
        set password [lindex $argv 0]
        set sshArgs [lrange $argv 1 end]
        spawn -noecho ssh {*}$sshArgs
        expect {
            -re {(?i)are you sure you want to continue connecting} {
                send -- "yes\\r"
                exp_continue
            }
            -re {(?i)(password|passphrase).*:} {
                send -- "$password\\r"
                exp_continue
            }
            eof {
                catch wait result
                exit [lindex $result 3]
            }
            timeout {}
        }
        set timeout -1
        expect eof
        catch wait result
        exit [lindex $result 3]
        """
    }
}
