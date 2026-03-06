import AppKit
import SwiftUI

struct DashboardView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var store: GPUStatusStore
    let appTheme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                if store.configs.isEmpty {
                    EmptyStateView(appTheme: appTheme)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(zip(store.configs, store.orderedSnapshots)), id: \.0.id) { config, snapshot in
                            ServerCardView(config: config, snapshot: snapshot, appTheme: appTheme)
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
                colors: appTheme.palette.windowGradient,
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
                        .foregroundStyle(appTheme.palette.primaryText)

                    Text("远程 GPU 菜单栏监控")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(appTheme.palette.secondaryText)
                }

                Spacer()

                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(appTheme.palette.primaryText)
                }
            }

            HStack(spacing: 12) {
                SummaryMetricView(
                    title: "在线",
                    value: store.summary.availabilityText,
                    tone: appTheme.palette.primaryText,
                    appTheme: appTheme
                )

                SummaryMetricView(
                    title: "GPU 总数",
                    value: "\(store.summary.totalGPUs)",
                    tone: appTheme.palette.primaryText,
                    appTheme: appTheme
                )

                SummaryMetricView(
                    title: "平均利用率",
                    value: percentageText(store.summary.averageGPUUtilization),
                    tone: loadColor(store.summary.primaryLevel),
                    appTheme: appTheme
                )

                SummaryMetricView(
                    title: "显存利用率",
                    value: percentageText(store.summary.averageMemoryUtilization),
                    tone: loadColor(store.summary.secondaryLevel),
                    appTheme: appTheme
                )
            }

            if let lastUpdatedAt = store.summary.lastUpdatedAt {
                Text("Last update \(relativeDateFormatter.localizedString(for: lastUpdatedAt, relativeTo: Date()))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(appTheme.palette.tertiaryText)
            } else {
                Text("No successful snapshot yet")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(appTheme.palette.tertiaryText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(appTheme.palette.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(appTheme.palette.panelStroke, lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack {
            Button("Refresh") {
                store.refreshNow()
            }
            .buttonStyle(DashboardActionButtonStyle(appTheme: appTheme, role: .primary))

            Button {
                openWindow(id: AppWindowID.settings)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(DashboardActionButtonStyle(appTheme: appTheme, role: .secondary))

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(DashboardActionButtonStyle(appTheme: appTheme, role: .secondary))
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
    let appTheme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(appTheme.palette.tertiaryText)

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
                .fill(appTheme.palette.cardFill)
        )
    }
}

private struct EmptyStateView: View {
    let appTheme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No servers configured")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(appTheme.palette.primaryText)

            Text("Open Settings and add an SSH alias or a direct host connection. The open-source build does not ship with any personal server addresses, keys, or passwords.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(appTheme.palette.secondaryText)

            Text("Template examples are available in `config/server-config.template.json`.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(appTheme.palette.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(appTheme.palette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(appTheme.palette.cardStroke, lineWidth: 1)
        )
    }
}

private struct ServerCardView: View {
    let config: ServerConfig
    let snapshot: ServerSnapshot
    let appTheme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.displayName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(appTheme.palette.primaryText)

                    Text(config.connectionSummary)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(appTheme.palette.tertiaryText)
                }

                Spacer()

                StatusPill(state: snapshot.state, appTheme: appTheme)
            }

            switch snapshot.state {
            case .success where !snapshot.gpus.isEmpty:
                VStack(spacing: 10) {
                    ForEach(snapshot.gpus) { gpu in
                        GPUStatusRow(gpu: gpu, appTheme: appTheme)
                    }
                }

            case .loading where !snapshot.gpus.isEmpty:
                VStack(spacing: 10) {
                    ForEach(snapshot.gpus) { gpu in
                        GPUStatusRow(gpu: gpu, appTheme: appTheme)
                    }
                }

            case .success:
                Text("Connected, but no GPUs were reported.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(appTheme.palette.secondaryText)

            case .failure:
                Text(snapshot.errorMessage ?? "Unknown error")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.74, blue: 0.74))

            case .loading:
                Text("Refreshing...")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(appTheme.palette.secondaryText)

            case .idle:
                Text(config.isEnabled ? "Waiting for first refresh" : "Disabled")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(appTheme.palette.tertiaryText)
            }

            if let fetchedAt = snapshot.fetchedAt {
                Text("Updated \(timestampFormatter.string(from: fetchedAt))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(appTheme.palette.tertiaryText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(appTheme.palette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(appTheme.palette.cardStroke, lineWidth: 1)
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
    let appTheme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GPU \(gpu.index)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(appTheme.palette.primaryText)

                Text(gpu.name)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(appTheme.palette.secondaryText)
                    .lineLimit(1)

                Spacer()

                Text("\(gpu.temperatureC)°C")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(appTheme.palette.secondaryText)
            }

            MetricBarView(
                title: "GPU",
                percent: gpu.gpuUtilization,
                detail: "\(gpu.gpuUtilization)%",
                color: loadColor(gpu.gpuLoadLevel),
                appTheme: appTheme
            )

            MetricBarView(
                title: "MEM",
                percent: gpu.memoryUtilization,
                detail: "\(gpu.memoryUsedMB) / \(gpu.memoryTotalMB) MB",
                color: loadColor(gpu.memoryLoadLevel),
                appTheme: appTheme
            )
        }
    }
}

private struct MetricBarView: View {
    let title: String
    let percent: Int
    let detail: String
    let color: Color
    let appTheme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(appTheme.palette.tertiaryText)

                Spacer()

                Text(detail)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(appTheme.palette.secondaryText)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(appTheme.palette.secondaryControlFill)

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
    let appTheme: AppTheme

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

private struct DashboardActionButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
    }

    let appTheme: AppTheme
    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor.opacity(configuration.isPressed ? 0.88 : 1))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor.opacity(configuration.isPressed ? 0.9 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch role {
        case .primary:
            return Color(red: 0.04, green: 0.10, blue: 0.06)
        case .secondary:
            return appTheme.palette.primaryText
        }
    }

    private var backgroundColor: Color {
        switch role {
        case .primary:
            return Color(red: 0.24, green: 0.78, blue: 0.42)
        case .secondary:
            return appTheme.palette.secondaryControlFill
        }
    }

    private var borderColor: Color {
        switch role {
        case .primary:
            return Color.clear
        case .secondary:
            return appTheme.palette.secondaryControlStroke
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
        return .secondary
    }
}
