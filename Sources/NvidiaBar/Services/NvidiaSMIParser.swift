import Foundation

enum NvidiaSMIParserError: LocalizedError, Equatable {
    case emptyOutput
    case malformedLine(String)

    var errorDescription: String? {
        switch self {
        case .emptyOutput:
            return "nvidia-smi returned no GPU rows"
        case let .malformedLine(line):
            return "Malformed nvidia-smi row: \(line)"
        }
    }
}

struct NvidiaSMIParser {
    func parse(_ rawOutput: String) throws -> [GPUSnapshot] {
        let lines = rawOutput
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw NvidiaSMIParserError.emptyOutput
        }

        return try lines.map(parseLine)
    }

    private func parseLine(_ line: String) throws -> GPUSnapshot {
        let columns = line
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        guard columns.count == 7,
              let index = Int(columns[0]),
              let gpuUtilization = Int(columns[2]),
              let reportedMemoryUtilization = Int(columns[3]),
              let memoryUsedMB = Int(columns[4]),
              let memoryTotalMB = Int(columns[5]),
              let temperatureC = Int(columns[6]) else {
            throw NvidiaSMIParserError.malformedLine(line)
        }

        let memoryUtilization: Int
        if memoryTotalMB > 0 {
            memoryUtilization = Int((Double(memoryUsedMB) / Double(memoryTotalMB)) * 100.0)
        } else {
            memoryUtilization = reportedMemoryUtilization
        }

        return GPUSnapshot(
            index: index,
            name: columns[1],
            gpuUtilization: gpuUtilization,
            memoryUtilization: memoryUtilization,
            memoryUsedMB: memoryUsedMB,
            memoryTotalMB: memoryTotalMB,
            temperatureC: temperatureC
        )
    }
}
