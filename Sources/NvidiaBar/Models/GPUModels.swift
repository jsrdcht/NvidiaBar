import Foundation

enum LoadLevel: String, Codable {
    case low
    case medium
    case high
    case unknown

    static func from(percent: Int?) -> LoadLevel {
        guard let percent else { return .unknown }
        switch percent {
        case 0..<40:
            return .low
        case 40..<75:
            return .medium
        default:
            return .high
        }
    }
}

struct GPUSnapshot: Codable, Equatable, Identifiable {
    var id: Int { index }
    let index: Int
    let name: String
    let gpuUtilization: Int
    let memoryUtilization: Int
    let memoryUsedMB: Int
    let memoryTotalMB: Int
    let temperatureC: Int

    var gpuLoadLevel: LoadLevel {
        LoadLevel.from(percent: gpuUtilization)
    }

    var memoryLoadLevel: LoadLevel {
        LoadLevel.from(percent: memoryUtilization)
    }
}

enum SnapshotState: String, Codable {
    case idle
    case loading
    case success
    case failure
}

struct ServerSnapshot: Codable, Equatable, Identifiable {
    var id: UUID { serverID }
    let serverID: UUID
    let fetchedAt: Date?
    let state: SnapshotState
    let gpus: [GPUSnapshot]
    let errorMessage: String?

    static func placeholder(for config: ServerConfig) -> ServerSnapshot {
        ServerSnapshot(
            serverID: config.id,
            fetchedAt: nil,
            state: .idle,
            gpus: [],
            errorMessage: nil
        )
    }

    func markedLoading() -> ServerSnapshot {
        ServerSnapshot(
            serverID: serverID,
            fetchedAt: fetchedAt,
            state: .loading,
            gpus: gpus,
            errorMessage: errorMessage
        )
    }
}

struct OverallSummary: Equatable {
    let onlineServers: Int
    let totalServers: Int
    let totalGPUs: Int
    let averageGPUUtilization: Int?
    let averageMemoryUtilization: Int?
    let lastUpdatedAt: Date?
    let failingServers: Int

    var availabilityText: String {
        "\(onlineServers)/\(totalServers)"
    }

    var menuBarText: String {
        let gpu = averageGPUUtilization.map(String.init) ?? "--"
        let mem = averageMemoryUtilization.map(String.init) ?? "--"
        return "\(gpu)|\(mem)"
    }

    var primaryLevel: LoadLevel {
        if failingServers > 0 {
            return .unknown
        }
        return LoadLevel.from(percent: averageGPUUtilization)
    }

    var secondaryLevel: LoadLevel {
        if failingServers > 0 {
            return .unknown
        }
        return LoadLevel.from(percent: averageMemoryUtilization)
    }

    static func build(configs: [ServerConfig], snapshots: [ServerSnapshot]) -> OverallSummary {
        let enabledServerIDs = Set(configs.filter(\.isEnabled).map(\.id))
        let relevantSnapshots = snapshots.filter { enabledServerIDs.contains($0.serverID) }
        let successfulSnapshots = relevantSnapshots.filter { $0.state == .success }
        let allGPUs = successfulSnapshots.flatMap(\.gpus)

        let averageGPU = allGPUs.isEmpty ? nil : Int(Double(allGPUs.map(\.gpuUtilization).reduce(0, +)) / Double(allGPUs.count))
        let averageMemory = allGPUs.isEmpty ? nil : Int(Double(allGPUs.map(\.memoryUtilization).reduce(0, +)) / Double(allGPUs.count))
        let newestDate = successfulSnapshots.compactMap(\.fetchedAt).max()
        let failures = relevantSnapshots.filter { $0.state == .failure }.count

        return OverallSummary(
            onlineServers: successfulSnapshots.count,
            totalServers: enabledServerIDs.count,
            totalGPUs: allGPUs.count,
            averageGPUUtilization: averageGPU,
            averageMemoryUtilization: averageMemory,
            lastUpdatedAt: newestDate,
            failingServers: failures
        )
    }
}
