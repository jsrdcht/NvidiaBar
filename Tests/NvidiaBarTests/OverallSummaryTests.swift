import Foundation
import XCTest
@testable import NvidiaBar

final class OverallSummaryTests: XCTestCase {
    func testBuildSummaryUsesSuccessfulSnapshotsOnly() {
        let serverA = ServerConfig(name: "A", hostAlias: "a", isEnabled: true, pollIntervalMinutes: 30)
        let serverB = ServerConfig(name: "B", hostAlias: "b", isEnabled: true, pollIntervalMinutes: 30)
        let successSnapshot = ServerSnapshot(
            serverID: serverA.id,
            fetchedAt: Date(timeIntervalSince1970: 100),
            state: .success,
            gpus: [
                GPUSnapshot(index: 0, name: "GPU", gpuUtilization: 30, memoryUtilization: 50, memoryUsedMB: 5000, memoryTotalMB: 10000, temperatureC: 40),
                GPUSnapshot(index: 1, name: "GPU", gpuUtilization: 70, memoryUtilization: 80, memoryUsedMB: 8000, memoryTotalMB: 10000, temperatureC: 60)
            ],
            errorMessage: nil
        )
        let failedSnapshot = ServerSnapshot(
            serverID: serverB.id,
            fetchedAt: Date(timeIntervalSince1970: 200),
            state: .failure,
            gpus: [],
            errorMessage: "ssh failed"
        )

        let summary = OverallSummary.build(
            configs: [serverA, serverB],
            snapshots: [successSnapshot, failedSnapshot]
        )

        XCTAssertEqual(summary.onlineServers, 1)
        XCTAssertEqual(summary.totalServers, 2)
        XCTAssertEqual(summary.totalGPUs, 2)
        XCTAssertEqual(summary.averageGPUUtilization, 50)
        XCTAssertEqual(summary.averageMemoryUtilization, 65)
        XCTAssertEqual(summary.lastUpdatedAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(summary.failingServers, 1)
    }
}
