import Foundation

protocol ServerConfigPersisting {
    func load() -> [ServerConfig]
    func save(_ configs: [ServerConfig])
    func defaultConfigs() -> [ServerConfig]
}

struct ServerConfigStore: ServerConfigPersisting {
    private let defaults: UserDefaults
    private let discovery: SSHConfigDiscovery
    private let key = "NvidiaBar.serverConfigs"

    init(
        defaults: UserDefaults = .standard,
        discovery: SSHConfigDiscovery = SSHConfigDiscovery()
    ) {
        self.defaults = defaults
        self.discovery = discovery
    }

    func load() -> [ServerConfig] {
        guard let data = defaults.data(forKey: key) else {
            return defaultConfigs()
        }

        do {
            return try JSONDecoder().decode([ServerConfig].self, from: data)
        } catch {
            return defaultConfigs()
        }
    }

    func save(_ configs: [ServerConfig]) {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        defaults.set(data, forKey: key)
    }

    func defaultConfigs() -> [ServerConfig] {
        let discovered = discovery.discoverConfigs()
        return discovered.isEmpty ? ServerConfig.defaults : discovered
    }
}
