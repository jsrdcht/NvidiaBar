import Foundation

protocol ServerConfigPersisting {
    func load() -> [ServerConfig]
    func save(_ configs: [ServerConfig])
}

struct ServerConfigStore: ServerConfigPersisting {
    private let defaults: UserDefaults
    private let key = "NvidiaBar.serverConfigs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [ServerConfig] {
        guard let data = defaults.data(forKey: key) else {
            return ServerConfig.defaults
        }

        do {
            return try JSONDecoder().decode([ServerConfig].self, from: data)
        } catch {
            return ServerConfig.defaults
        }
    }

    func save(_ configs: [ServerConfig]) {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        defaults.set(data, forKey: key)
    }
}
