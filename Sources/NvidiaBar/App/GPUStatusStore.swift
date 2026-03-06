import Combine
import Foundation

@MainActor
final class GPUStatusStore: ObservableObject {
    @Published var configs: [ServerConfig] {
        didSet {
            guard hasBootstrapped else { return }
            persistConfigs()
            pruneSnapshots()
            rescheduleTimer()
        }
    }
    @Published private(set) var snapshotsByServerID: [UUID: ServerSnapshot]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshAttemptAt: Date?

    private let collector: GPUCollecting
    private let configStore: ServerConfigPersisting
    private var timer: Timer?
    private var hasStarted = false
    private var hasBootstrapped = false

    init(
        collector: GPUCollecting,
        configStore: ServerConfigPersisting
    ) {
        self.collector = collector
        self.configStore = configStore
        self.configs = configStore.load()
        self.snapshotsByServerID = [:]
        self.hasBootstrapped = true
        self.seedPlaceholders()
    }

    var orderedSnapshots: [ServerSnapshot] {
        configs.map { config in
            snapshotsByServerID[config.id] ?? ServerSnapshot.placeholder(for: config)
        }
    }

    var summary: OverallSummary {
        OverallSummary.build(configs: configs, snapshots: orderedSnapshots)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        rescheduleTimer()

        Task {
            await refreshIfNeeded(maximumAge: 1)
        }
    }

    func refreshNow() {
        Task {
            await refresh(force: true)
        }
    }

    func refreshIfNeeded(maximumAge: TimeInterval) async {
        let enabledIDs = Set(configs.filter(\.isEnabled).map(\.id))
        let newestSnapshot = orderedSnapshots
            .filter { enabledIDs.contains($0.serverID) }
            .compactMap(\.fetchedAt)
            .max()

        guard let newestSnapshot else {
            await refresh(force: true)
            return
        }

        if Date().timeIntervalSince(newestSnapshot) >= maximumAge {
            await refresh(force: false)
        }
    }

    func restoreDefaults() {
        configs = ServerConfig.defaults
        snapshotsByServerID = [:]
        seedPlaceholders()
        refreshNow()
    }

    func addServer() {
        configs.append(
            ServerConfig(
                name: "GPU Server",
                hostAlias: "server-alias",
                isEnabled: true,
                pollIntervalMinutes: 30
            )
        )
    }

    func deleteServers(at offsets: IndexSet) {
        let ids = offsets.map { configs[$0].id }
        configs.remove(atOffsets: offsets)
        ids.forEach { snapshotsByServerID.removeValue(forKey: $0) }
    }

    private func refresh(force: Bool) async {
        let enabledConfigs = configs.filter(\.isEnabled)
        guard !enabledConfigs.isEmpty else { return }
        guard !isRefreshing else { return }

        if !force, let lastRefreshAttemptAt, Date().timeIntervalSince(lastRefreshAttemptAt) < 10 {
            return
        }

        isRefreshing = true
        lastRefreshAttemptAt = Date()
        markEnabledServersLoading()

        let collector = self.collector
        let snapshots = await withTaskGroup(of: ServerSnapshot.self, returning: [ServerSnapshot].self) { group in
            for config in enabledConfigs {
                group.addTask {
                    await collector.fetchSnapshot(for: config)
                }
            }

            var results: [ServerSnapshot] = []
            for await snapshot in group {
                results.append(snapshot)
            }
            return results
        }

        snapshots.forEach { snapshot in
            snapshotsByServerID[snapshot.serverID] = snapshot
        }

        isRefreshing = false
    }

    private func persistConfigs() {
        configStore.save(configs)
    }

    private func rescheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(max(60, minimumPollIntervalSeconds))

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refresh(force: true)
            }
        }
    }

    private var minimumPollIntervalSeconds: Int {
        configs
            .filter(\.isEnabled)
            .map { max(1, $0.pollIntervalMinutes) * 60 }
            .min() ?? 1800
    }

    private func pruneSnapshots() {
        let validIDs = Set(configs.map(\.id))
        snapshotsByServerID = snapshotsByServerID.filter { validIDs.contains($0.key) }
        seedPlaceholders()
    }

    private func seedPlaceholders() {
        for config in configs where snapshotsByServerID[config.id] == nil {
            snapshotsByServerID[config.id] = ServerSnapshot.placeholder(for: config)
        }
    }

    private func markEnabledServersLoading() {
        for config in configs where config.isEnabled {
            let existing = snapshotsByServerID[config.id] ?? ServerSnapshot.placeholder(for: config)
            snapshotsByServerID[config.id] = existing.markedLoading()
        }
    }
}
