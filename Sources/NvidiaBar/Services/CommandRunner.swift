import Foundation

struct CommandResult: Equatable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum CommandRunnerError: LocalizedError {
    case launchFailed(String)
    case timedOut(TimeInterval)

    var errorDescription: String? {
        switch self {
        case let .launchFailed(message):
            return message
        case let .timedOut(timeout):
            return "Command timed out after \(Int(timeout))s"
        }
    }
}

protocol CommandRunning: Sendable {
    func run(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> CommandResult
}

private final class ProcessBox: @unchecked Sendable {
    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
}

private final class ContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<CommandResult, Error>

    init(_ continuation: CheckedContinuation<CommandResult, Error>) {
        self.continuation = continuation
    }

    func finish(_ result: Result<CommandResult, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(with: result)
    }
}

struct ProcessCommandRunner: CommandRunning {
    func run(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let processBox = ProcessBox()
            let continuationBox = ContinuationBox(continuation)

            processBox.process.executableURL = URL(fileURLWithPath: executablePath)
            processBox.process.arguments = arguments
            processBox.process.standardOutput = processBox.stdoutPipe
            processBox.process.standardError = processBox.stderrPipe

            do {
                try processBox.process.run()
            } catch {
                continuationBox.finish(.failure(CommandRunnerError.launchFailed(error.localizedDescription)))
                return
            }

            Thread.detachNewThread {
                processBox.process.waitUntilExit()

                let stdoutData = processBox.stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = processBox.stderrPipe.fileHandleForReading.readDataToEndOfFile()

                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                continuationBox.finish(.success(CommandResult(
                    stdout: stdout,
                    stderr: stderr,
                    exitCode: processBox.process.terminationStatus
                )))
            }

            Thread.detachNewThread {
                Thread.sleep(forTimeInterval: timeout)
                if processBox.process.isRunning {
                    processBox.process.terminate()
                    continuationBox.finish(.failure(CommandRunnerError.timedOut(timeout)))
                }
            }
        }
    }
}
