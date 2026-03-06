import SwiftUI

struct MenuBarStatusView: View {
    let summary: OverallSummary
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: 6) {
            VStack(spacing: 2) {
                MiniBar(percent: summary.averageGPUUtilization ?? 0, color: loadColor(summary.primaryLevel))
                MiniBar(percent: summary.averageMemoryUtilization ?? 0, color: loadColor(summary.secondaryLevel))
            }
            .frame(width: 20)

            Text(summary.menuBarText)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .monospacedDigit()

            if isRefreshing {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.65)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct MiniBar: View {
    let percent: Int
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.18))

                Capsule()
                    .fill(color)
                    .frame(width: max(4, geometry.size.width * CGFloat(percent) / 100))
            }
        }
        .frame(height: 4)
    }
}
