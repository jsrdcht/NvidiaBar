import Foundation

protocol GPUCollecting {
    func fetchSnapshot(for config: ServerConfig) async -> ServerSnapshot
}

struct SSHGPUCollector: GPUCollecting {
    private let runner: CommandRunning
    private let parser: NvidiaSMIParser
    private let invocationBuilder: SSHInvocationBuilder

    init(
        runner: CommandRunning = ProcessCommandRunner(),
        parser: NvidiaSMIParser = NvidiaSMIParser(),
        invocationBuilder: SSHInvocationBuilder = SSHInvocationBuilder()
    ) {
        self.runner = runner
        self.parser = parser
        self.invocationBuilder = invocationBuilder
    }

    func fetchSnapshot(for config: ServerConfig) async -> ServerSnapshot {
        let command = "nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits"

        do {
            let invocation = try invocationBuilder.build(for: config, remoteCommand: command)
            let result = try await runner.run(
                executablePath: invocation.executablePath,
                arguments: invocation.arguments,
                timeout: invocationBuilder.timeout
            )

            guard result.exitCode == 0 else {
                return ServerSnapshot(
                    serverID: config.id,
                    fetchedAt: Date(),
                    state: .failure,
                    gpus: [],
                    errorMessage: sanitizeError(result.stderr, fallback: "ssh exited with code \(result.exitCode)")
                )
            }

            let gpus = try parser.parse(result.stdout)
            return ServerSnapshot(
                serverID: config.id,
                fetchedAt: Date(),
                state: .success,
                gpus: gpus,
                errorMessage: nil
            )
        } catch {
            return ServerSnapshot(
                serverID: config.id,
                fetchedAt: Date(),
                state: .failure,
                gpus: [],
                errorMessage: sanitizeError(error.localizedDescription, fallback: "Unknown collection error")
            )
        }
    }

    private func sanitizeError(_ raw: String, fallback: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
