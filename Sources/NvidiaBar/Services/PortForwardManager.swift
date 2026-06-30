import AppKit
import Foundation

/// 管理常驻的 SSH 端口转发隧道：启动 / 停止 / 在浏览器打开。
@MainActor
final class PortForwardManager: ObservableObject {
    struct Runtime: Equatable {
        enum Phase: Equatable {
            case starting
            case active
            case failed(String)
        }

        var localPort: Int
        var phase: Phase
    }

    /// 以 PortForward.id 为键的运行时状态，供界面观察。
    @Published private(set) var runtimes: [UUID: Runtime] = [:]

    private let invocationBuilder: SSHInvocationBuilder
    private let confirmDelayNanoseconds: UInt64
    private var sessions: [UUID: (process: Process, invocation: SSHInvocation)] = [:]
    /// 进程登记表，可在非隔离上下文（如退出通知）中安全地终止全部隧道。
    private let registry = TunnelProcessRegistry()

    init(
        invocationBuilder: SSHInvocationBuilder = SSHInvocationBuilder(timeout: 15),
        confirmDelayNanoseconds: UInt64 = 1_400_000_000
    ) {
        self.invocationBuilder = invocationBuilder
        self.confirmDelayNanoseconds = confirmDelayNanoseconds

        let registry = self.registry
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            registry.terminateAll()
        }
    }

    func runtime(for id: UUID) -> Runtime? {
        runtimes[id]
    }

    func start(_ forward: PortForward, config: ServerConfig, openInBrowser: Bool) {
        // 已在运行：若已就绪且需要打开浏览器，则直接打开。
        if sessions[forward.id] != nil {
            if openInBrowser, let runtime = runtimes[forward.id], runtime.phase == .active {
                openBrowser(port: runtime.localPort)
            }
            return
        }

        let localPort: Int
        if let fixed = forward.fixedLocalPort {
            localPort = fixed
        } else if let free = Self.findFreeTCPPort() {
            localPort = free
        } else {
            runtimes[forward.id] = Runtime(localPort: 0, phase: .failed("无法分配空闲的本地端口"))
            return
        }

        let invocation: SSHInvocation
        do {
            invocation = try invocationBuilder.buildForwarding(
                for: config,
                localPort: localPort,
                remoteHost: forward.trimmedRemoteHost,
                remotePort: forward.normalizedRemotePort
            )
        } catch {
            runtimes[forward.id] = Runtime(localPort: localPort, phase: .failed(error.localizedDescription))
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: invocation.executablePath)
        process.arguments = invocation.arguments
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        let forwardID = forward.id
        process.terminationHandler = { [weak self] proc in
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(data: data, encoding: .utf8) ?? ""
            let exitCode = proc.terminationStatus
            Task { @MainActor [weak self] in
                self?.handleUnexpectedTermination(forwardID, exitCode: exitCode, stderr: stderr)
            }
        }

        do {
            try process.run()
        } catch {
            invocation.cleanup()
            runtimes[forward.id] = Runtime(localPort: localPort, phase: .failed(error.localizedDescription))
            return
        }

        sessions[forward.id] = (process, invocation)
        registry.set(forward.id, process)
        runtimes[forward.id] = Runtime(localPort: localPort, phase: .starting)

        // 连接需要一点时间；短暂等待后若进程仍存活则视为就绪。
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.confirmDelayNanoseconds ?? 1_400_000_000)
            self?.confirmActive(forwardID, localPort: localPort, openInBrowser: openInBrowser)
        }
    }

    func stop(_ id: UUID) {
        if let session = sessions[id] {
            // 主动停止，避免触发“意外退出”的失败状态。
            session.process.terminationHandler = nil
            if session.process.isRunning {
                session.process.terminate()
            }
            session.invocation.cleanup()
            sessions[id] = nil
            registry.set(id, nil)
        }
        runtimes[id] = nil
    }

    func stopAll() {
        for id in Array(sessions.keys) {
            stop(id)
        }
    }

    func openBrowser(port: Int) {
        guard let url = URL(string: "http://127.0.0.1:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func confirmActive(_ id: UUID, localPort: Int, openInBrowser: Bool) {
        guard let session = sessions[id], session.process.isRunning else { return }
        guard var runtime = runtimes[id], runtime.phase == .starting else { return }

        runtime.phase = .active
        runtimes[id] = runtime

        if openInBrowser {
            openBrowser(port: localPort)
        }
    }

    private func handleUnexpectedTermination(_ id: UUID, exitCode: Int32, stderr: String) {
        // 若已被 stop() 清理则忽略。
        guard let session = sessions[id] else { return }
        session.invocation.cleanup()
        sessions[id] = nil
        registry.set(id, nil)

        let localPort = runtimes[id]?.localPort ?? 0
        let message = Self.sanitize(stderr) ?? "SSH 隧道已退出（代码 \(exitCode)）"
        runtimes[id] = Runtime(localPort: localPort, phase: .failed(message))
    }

    private static func sanitize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // 只保留最后一行非空内容，避免把多行噪声塞进界面。
        let lastLine = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last(where: { !$0.isEmpty })
        return lastLine ?? trimmed
    }

    /// 让操作系统分配一个空闲的本地 TCP 端口。
    static func findFreeTCPPort() -> Int? {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { return nil }

        var boundAddr = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getsockname(fd, sockaddrPointer, &length)
            }
        }
        guard nameResult == 0 else { return nil }

        let port = Int(UInt16(bigEndian: boundAddr.sin_port))
        return port > 0 ? port : nil
    }
}

/// 线程安全的进程登记表，便于在应用退出时同步终止所有隧道。
private final class TunnelProcessRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var processes: [UUID: Process] = [:]

    func set(_ id: UUID, _ process: Process?) {
        lock.lock()
        defer { lock.unlock() }
        processes[id] = process
    }

    func terminateAll() {
        lock.lock()
        let all = Array(processes.values)
        processes.removeAll()
        lock.unlock()

        for process in all where process.isRunning {
            process.terminationHandler = nil
            process.terminate()
        }
    }
}
