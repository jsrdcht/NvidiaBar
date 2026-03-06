import Foundation

struct ServerConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var hostAlias: String
    var isEnabled: Bool
    var pollIntervalMinutes: Int

    init(
        id: UUID = UUID(),
        name: String,
        hostAlias: String,
        isEnabled: Bool,
        pollIntervalMinutes: Int
    ) {
        self.id = id
        self.name = name
        self.hostAlias = hostAlias
        self.isEnabled = isEnabled
        self.pollIntervalMinutes = pollIntervalMinutes
    }
}

extension ServerConfig {
    static let defaults: [ServerConfig] = []

    static let exampleTemplate: [ServerConfig] = [
        .init(name: "GPU Server 1", hostAlias: "gpu-server-1", isEnabled: true, pollIntervalMinutes: 30),
        .init(name: "GPU Server 2", hostAlias: "gpu-server-2", isEnabled: true, pollIntervalMinutes: 30)
    ]
}
