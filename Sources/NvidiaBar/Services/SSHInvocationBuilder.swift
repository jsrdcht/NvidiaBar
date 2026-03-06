import Foundation

struct SSHInvocation: Equatable {
    let executablePath: String
    let arguments: [String]
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

    private func buildPasswordInvocation(for config: ServerConfig, remoteCommand: String) throws -> SSHInvocation {
        let sshArguments = try buildSSHArguments(for: config, remoteCommand: remoteCommand, batchMode: false)
        return SSHInvocation(
            executablePath: "/usr/bin/expect",
            arguments: ["-c", expectScript, "--", config.trimmedPassword] + sshArguments
        )
    }

    private func buildSSHArguments(
        for config: ServerConfig,
        remoteCommand: String,
        batchMode: Bool
    ) throws -> [String] {
        var arguments = [
            "-o", "ConnectTimeout=\(Int(timeout))"
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
}
