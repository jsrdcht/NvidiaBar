import Foundation
import XCTest
@testable import NvidiaBar

private final class SequencedCommandRunner: CommandRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [CommandResult]
    private(set) var callCount = 0

    init(results: [CommandResult]) {
        self.results = results
    }

    func run(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> CommandResult {
        lock.lock()
        defer { lock.unlock() }

        callCount += 1
        guard !results.isEmpty else {
            return CommandResult(stdout: "", stderr: "unexpected extra call", exitCode: 1)
        }

        return results.removeFirst()
    }
}

final class SSHGPUCollectorTests: XCTestCase {
    func testRetriesOnceAfterSSHExit255() async {
        let runner = SequencedCommandRunner(results: [
            CommandResult(stdout: "", stderr: "", exitCode: 255),
            CommandResult(
                stdout: "0, NVIDIA A100, 12, 34, 1024, 40960, 55\n",
                stderr: "",
                exitCode: 0
            )
        ])
        let collector = SSHGPUCollector(
            runner: runner,
            invocationBuilder: SSHInvocationBuilder(timeout: 1),
            sshExit255RetryDelayNanoseconds: 0
        )
        let config = ServerConfig(
            name: "Alias",
            connectionMode: .sshAlias,
            hostAlias: "gpu-server-1",
            isEnabled: true,
            pollIntervalMinutes: 30
        )

        let snapshot = await collector.fetchSnapshot(for: config)

        XCTAssertEqual(runner.callCount, 2)
        XCTAssertEqual(snapshot.state, .success)
        XCTAssertEqual(snapshot.gpus.count, 1)
        XCTAssertEqual(snapshot.gpus.first?.name, "NVIDIA A100")
    }
}
