import Foundation

/// 一条 SSH 本地端口转发配置：将远程服务器上的某个端口转发到本机端口。
struct PortForward: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    /// 远端要转发的目标地址（相对服务器而言），默认 127.0.0.1。
    var remoteHost: String
    /// 远端端口。
    var remotePort: Int
    /// 本地端口，<= 0 表示启动时随机分配空闲端口。
    var localPort: Int

    init(
        id: UUID = UUID(),
        name: String = "",
        remoteHost: String = "127.0.0.1",
        remotePort: Int = 8384,
        localPort: Int = 0
    ) {
        self.id = id
        self.name = name
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.localPort = localPort
    }
}

extension PortForward {
    var trimmedRemoteHost: String {
        let trimmed = remoteHost.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "127.0.0.1" : trimmed
    }

    var normalizedRemotePort: Int {
        min(max(remotePort, 1), 65_535)
    }

    /// 是否使用随机本地端口。
    var usesRandomLocalPort: Bool {
        localPort <= 0
    }

    /// 用户固定指定的本地端口；随机模式下为 nil。
    var fixedLocalPort: Int? {
        usesRandomLocalPort ? nil : min(max(localPort, 1), 65_535)
    }
}
