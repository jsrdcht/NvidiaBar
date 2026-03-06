#if canImport(AppKit)
import AppKit
#endif
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark

    static let storageKey = "NvidiaBar.appTheme"
    static let defaultValue: AppTheme = .light

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light:
            return "浅色"
        case .dark:
            return "深色"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

#if canImport(AppKit)
    var appearanceName: NSAppearance.Name {
        switch self {
        case .light:
            return .aqua
        case .dark:
            return .darkAqua
        }
    }
#endif

    var palette: ThemePalette {
        switch self {
        case .light:
            return ThemePalette(
                windowGradient: [
                    Color(red: 0.95, green: 0.97, blue: 0.99),
                    Color(red: 0.89, green: 0.92, blue: 0.96)
                ],
                panelFill: Color.white.opacity(0.86),
                panelStroke: Color.black.opacity(0.08),
                cardFill: Color.white.opacity(0.92),
                cardStroke: Color.black.opacity(0.08),
                primaryText: Color(red: 0.09, green: 0.12, blue: 0.16),
                secondaryText: Color(red: 0.26, green: 0.31, blue: 0.38),
                tertiaryText: Color(red: 0.39, green: 0.45, blue: 0.53),
                secondaryControlFill: Color.black.opacity(0.06),
                secondaryControlStroke: Color.black.opacity(0.08)
            )
        case .dark:
            return ThemePalette(
                windowGradient: [
                    Color(red: 0.09, green: 0.12, blue: 0.16),
                    Color(red: 0.05, green: 0.07, blue: 0.10)
                ],
                panelFill: Color.white.opacity(0.08),
                panelStroke: Color.white.opacity(0.06),
                cardFill: Color.white.opacity(0.06),
                cardStroke: Color.white.opacity(0.05),
                primaryText: .white,
                secondaryText: Color.white.opacity(0.72),
                tertiaryText: Color.white.opacity(0.52),
                secondaryControlFill: Color.white.opacity(0.10),
                secondaryControlStroke: Color.white.opacity(0.08)
            )
        }
    }
}

struct ThemePalette {
    let windowGradient: [Color]
    let panelFill: Color
    let panelStroke: Color
    let cardFill: Color
    let cardStroke: Color
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    let secondaryControlFill: Color
    let secondaryControlStroke: Color
}

extension View {
    func appTheme(_ appTheme: AppTheme) -> some View {
        modifier(AppThemeModifier(appTheme: appTheme))
    }
}

private struct AppThemeModifier: ViewModifier {
    let appTheme: AppTheme

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, appTheme.colorScheme)
            .preferredColorScheme(appTheme.colorScheme)
            .overlay {
                ThemeAppearanceBridge(appTheme: appTheme)
                    .frame(width: 0, height: 0)
            }
    }
}

#if canImport(AppKit)
private struct ThemeAppearanceBridge: NSViewRepresentable {
    let appTheme: AppTheme

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        applyAppearance(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        applyAppearance(to: nsView)
    }

    private func applyAppearance(to nsView: NSView) {
        let appearance = NSAppearance(named: appTheme.appearanceName)
        nsView.appearance = appearance
        nsView.window?.appearance = appearance
        NSApp.appearance = appearance
    }
}
#else
private struct ThemeAppearanceBridge: View {
    let appTheme: AppTheme

    var body: some View {
        EmptyView()
    }
}
#endif
