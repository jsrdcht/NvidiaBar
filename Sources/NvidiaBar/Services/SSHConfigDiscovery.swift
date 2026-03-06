import Foundation

struct SSHConfigDiscovery {
    private let fileManager: FileManager
    private let homeDirectoryURL: URL

    init(
        fileManager: FileManager = .default,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.homeDirectoryURL = homeDirectoryURL
    }

    func discoverConfigs() -> [ServerConfig] {
        let configURL = homeDirectoryURL.appendingPathComponent(".ssh/config")
        guard fileManager.fileExists(atPath: configURL.path) else {
            return []
        }

        guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
            return []
        }

        return parse(contents)
    }

    func parse(_ contents: String) -> [ServerConfig] {
        var aliases: [String] = []
        var directives: [String: String] = [:]
        var configs: [ServerConfig] = []

        func flushCurrentBlock() {
            guard !aliases.isEmpty else { return }

            let hostName = directives["hostname"] ?? ""
            let userName = directives["user"] ?? ""
            let port = Int(directives["port"] ?? "") ?? 22
            let identityFile = directives["identityfile"] ?? ""

            for alias in aliases where shouldImport(alias: alias) {
                configs.append(
                    ServerConfig(
                        name: alias,
                        connectionMode: .sshAlias,
                        hostAlias: alias,
                        hostName: hostName,
                        userName: userName,
                        port: port,
                        identityFile: identityFile,
                        password: "",
                        isEnabled: true,
                        pollIntervalMinutes: 30
                    )
                )
            }
        }

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            let pieces = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard pieces.count == 2 else { continue }

            let key = pieces[0].lowercased()
            let value = String(pieces[1]).trimmingCharacters(in: .whitespaces)

            if key == "host" {
                flushCurrentBlock()
                aliases = value.split(whereSeparator: \.isWhitespace).map(String.init)
                directives = [:]
                continue
            }

            guard !aliases.isEmpty else { continue }
            directives[key] = value
        }

        flushCurrentBlock()

        var seen = Set<String>()
        return configs.filter { config in
            seen.insert(config.connectionIdentityKey()).inserted
        }
    }

    private func shouldImport(alias: String) -> Bool {
        !alias.isEmpty &&
        !alias.contains("*") &&
        !alias.contains("?") &&
        !alias.hasPrefix("!")
    }
}
