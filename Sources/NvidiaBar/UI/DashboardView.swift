import AppKit
import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: GPUStatusStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                if store.configs.isEmpty {
                    EmptyStateView()
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(zip(store.configs, store.orderedSnapshots)), id: \.0.id) { config, snapshot in
                            ServerCardView(config: config, snapshot: snapshot)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            footer
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.12, blue: 0.16),
                    Color(red: 0.05, green: 0.07, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            Task {
                await store.refreshIfNeeded(maximumAge: 300)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NvidiaBar")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("远程 GPU 菜单栏监控")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                Spacer()

                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }

            HStack(spacing: 12) {
                SummaryMetricView(
                    title: "在线",
                    value: store.summary.availabilityText,
                    tone: .white
                )

                SummaryMetricView(
                    title: "GPU 总数",
                    value: "\(store.summary.totalGPUs)",
                    tone: .white
                )

                SummaryMetricView(
                    title: "平均利用率",
                    value: percentageText(store.summary.averageGPUUtilization),
                    tone: loadColor(store.summary.primaryLevel)
                )

                SummaryMetricView(
                    title: "显存利用率",
                    value: percentageText(store.summary.averageMemoryUtilization),
                    tone: loadColor(store.summary.secondaryLevel)
                )
            }

            if let lastUpdatedAt = store.summary.lastUpdatedAt {
                Text("Last update \(relativeDateFormatter.localizedString(for: lastUpdatedAt, relativeTo: Date()))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
            } else {
                Text("No successful snapshot yet")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack {
            Button("Refresh") {
                store.refreshNow()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.20, green: 0.68, blue: 0.34))

            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
    }

    private func percentageText(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? "--"
    }

    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }
}

private struct SummaryMetricView: View {
    let title: String
    let value: String
    let tone: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.45))

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(tone)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No servers configured")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Open Settings and add your SSH host alias. The open-source build does not ship with any personal server addresses, keys, or passwords.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.7))

            Text("Template examples are available in `config/server-config.template.json`.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct ServerCardView: View {
    let config: ServerConfig
    let snapshot: ServerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(config.hostAlias)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.5))
                }

                Spacer()

                StatusPill(state: snapshot.state)
            }

            switch snapshot.state {
            case .success where !snapshot.gpus.isEmpty:
                VStack(spacing: 10) {
                    ForEach(snapshot.gpus) { gpu in
                        GPUStatusRow(gpu: gpu)
                    }
                }

            case .loading where !snapshot.gpus.isEmpty:
                VStack(spacing: 10) {
                    ForEach(snapshot.gpus) { gpu in
                        GPUStatusRow(gpu: gpu)
                    }
                }

            case .success:
                Text("Connected, but no GPUs were reported.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.7))

            case .failure:
                Text(snapshot.errorMessage ?? "Unknown error")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.74, blue: 0.74))

            case .loading:
                Text("Refreshing...")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.7))

            case .idle:
                Text(config.isEnabled ? "Waiting for first refresh" : "Disabled")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            if let fetchedAt = snapshot.fetchedAt {
                Text("Updated \(timestampFormatter.string(from: fetchedAt))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
}

private struct GPUStatusRow: View {
    let gpu: GPUSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GPU \(gpu.index)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Text(gpu.name)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineLimit(1)

                Spacer()

                Text("\(gpu.temperatureC)°C")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            MetricBarView(
                title: "GPU",
                percent: gpu.gpuUtilization,
                detail: "\(gpu.gpuUtilization)%",
                color: loadColor(gpu.gpuLoadLevel)
            )

            MetricBarView(
                title: "MEM",
                percent: gpu.memoryUtilization,
                detail: "\(gpu.memoryUsedMB) / \(gpu.memoryTotalMB) MB",
                color: loadColor(gpu.memoryLoadLevel)
            )
        }
    }
}

private struct MetricBarView: View {
    let title: String
    let percent: Int
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))

                Spacer()

                Text(detail)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(color)
                        .frame(width: max(8, geometry.size.width * CGFloat(percent) / 100))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct StatusPill: View {
    let state: SnapshotState

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(loadColor(colorLevel).opacity(0.18))
            )
            .foregroundStyle(loadColor(colorLevel))
    }

    private var label: String {
        switch state {
        case .idle:
            return "IDLE"
        case .loading:
            return "SYNC"
        case .success:
            return "ONLINE"
        case .failure:
            return "ERROR"
        }
    }

    private var colorLevel: LoadLevel {
        switch state {
        case .success:
            return .low
        case .loading:
            return .medium
        case .idle, .failure:
            return .unknown
        }
    }
}

func loadColor(_ level: LoadLevel) -> Color {
    switch level {
    case .low:
        return Color(red: 0.25, green: 0.84, blue: 0.43)
    case .medium:
        return Color(red: 0.96, green: 0.76, blue: 0.29)
    case .high:
        return Color(red: 0.98, green: 0.36, blue: 0.33)
    case .unknown:
        return Color.white.opacity(0.45)
    }
}
