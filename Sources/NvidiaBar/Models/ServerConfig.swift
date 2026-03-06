import Foundation

enum ServerConnectionMode: String, Codable, CaseIterable, Identifiable {
    case sshAlias
    case direct

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sshAlias:
            return "SSH 别名"
        case .direct:
            return "直接连接"
        }
    }
}

struct ServerConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var connectionMode: ServerConnectionMode
    var hostAlias: String
    var hostName: String
    var userName: String
    var port: Int
    var identityFile: String
    var password: String
    var isEnabled: Bool
    var pollIntervalMinutes: Int

    init(
        id: UUID = UUID(),
        name: String,
        connectionMode: ServerConnectionMode? = nil,
        hostAlias: String,
        hostName: String = "",
        userName: String = "",
        port: Int = 22,
        identityFile: String = "",
        password: String = "",
        isEnabled: Bool,
        pollIntervalMinutes: Int
    ) {
        self.id = id
        self.name = name
        self.connectionMode = connectionMode ?? (hostAlias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .direct : .sshAlias)
        self.hostAlias = hostAlias
        self.hostName = hostName
        self.userName = userName
        self.port = port
        self.identityFile = identityFile
        self.password = password
        self.isEnabled = isEnabled
        self.pollIntervalMinutes = pollIntervalMinutes
    }
}

extension ServerConfig {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case connectionMode
        case hostAlias
        case hostName
        case userName
        case port
        case identityFile
        case password
        case isEnabled
        case pollIntervalMinutes
    }

    static let defaults: [ServerConfig] = []

    static let exampleTemplate: [ServerConfig] = [
        .init(
            name: "GPU Server 1",
            connectionMode: .sshAlias,
            hostAlias: "gpu-server-1",
            hostName: "",
            userName: "",
            port: 22,
            identityFile: "",
            password: "",
            isEnabled: true,
            pollIntervalMinutes: 30
        ),
        .init(
            name: "GPU Server 2",
            connectionMode: .direct,
            hostAlias: "",
            hostName: "192.168.1.20",
            userName: "gpu-user",
            port: 22,
            identityFile: "~/.ssh/id_ed25519",
            password: "",
            isEnabled: true,
            pollIntervalMinutes: 30
        )
    ]

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedHostAlias: String {
        hostAlias.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedHostName: String {
        hostName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedUserName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedIdentityFile: String {
        identityFile.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedPassword: String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedPort: Int {
        min(max(port, 1), 65_535)
    }

    var displayName: String {
        if !trimmedName.isEmpty {
            return trimmedName
        }

        switch connectionMode {
        case .sshAlias:
            return trimmedHostAlias.isEmpty ? "未命名服务器" : trimmedHostAlias
        case .direct:
            return trimmedHostName.isEmpty ? "未命名服务器" : trimmedHostName
        }
    }

    var connectionSummary: String {
        switch connectionMode {
        case .sshAlias:
            return trimmedHostAlias.isEmpty ? "未填写 SSH 别名" : trimmedHostAlias
        case .direct:
            let base = trimmedHostName.isEmpty ? "未填写主机" : trimmedHostName
            if trimmedUserName.isEmpty {
                return "\(base):\(normalizedPort)"
            }
            return "\(trimmedUserName)@\(base):\(normalizedPort)"
        }
    }

    var usesPasswordAuthentication: Bool {
        !trimmedPassword.isEmpty
    }

    var expandedIdentityFile: String {
        NSString(string: trimmedIdentityFile).expandingTildeInPath
    }

    func connectionIdentityKey() -> String {
        switch connectionMode {
        case .sshAlias:
            return "alias:\(trimmedHostAlias.lowercased())"
        case .direct:
            return "direct:\(trimmedUserName.lowercased())@\(trimmedHostName.lowercased()):\(normalizedPort)"
        }
    }

    func sshTarget() throws -> String {
        switch connectionMode {
        case .sshAlias:
            guard !trimmedHostAlias.isEmpty else {
                throw ServerConfigError.missingHostAlias
            }
            return trimmedHostAlias
        case .direct:
            guard !trimmedHostName.isEmpty else {
                throw ServerConfigError.missingHostName
            }

            if trimmedUserName.isEmpty {
                return trimmedHostName
            }

            return "\(trimmedUserName)@\(trimmedHostName)"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        let hostAlias = try container.decodeIfPresent(String.self, forKey: .hostAlias) ?? ""
        let hostName = try container.decodeIfPresent(String.self, forKey: .hostName) ?? ""
        let userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? ""
        let port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 22
        let identityFile = try container.decodeIfPresent(String.self, forKey: .identityFile) ?? ""
        let password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        let isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        let pollIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .pollIntervalMinutes) ?? 30
        let inferredMode: ServerConnectionMode = hostAlias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .direct : .sshAlias
        let connectionMode = try container.decodeIfPresent(ServerConnectionMode.self, forKey: .connectionMode) ?? inferredMode

        self.init(
            id: id,
            name: name,
            connectionMode: connectionMode,
            hostAlias: hostAlias,
            hostName: hostName,
            userName: userName,
            port: port,
            identityFile: identityFile,
            password: password,
            isEnabled: isEnabled,
            pollIntervalMinutes: pollIntervalMinutes
        )
    }
}

enum ServerConfigError: LocalizedError {
    case missingHostAlias
    case missingHostName

    var errorDescription: String? {
        switch self {
        case .missingHostAlias:
            return "Missing SSH host alias"
        case .missingHostName:
            return "Missing SSH hostname or IP"
        }
    }
}
