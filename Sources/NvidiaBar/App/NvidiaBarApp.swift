import AppKit
import SwiftUI

@main
struct NvidiaBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppTheme.storageKey) private var appThemeRawValue = AppTheme.defaultValue.rawValue
    @StateObject private var store: GPUStatusStore

    init() {
        let configStore = ServerConfigStore()
        let store = GPUStatusStore(
            collector: SSHGPUCollector(),
            configStore: configStore
        )
        _store = StateObject(wrappedValue: store)
        store.start()
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView(store: store, appTheme: appTheme)
                .frame(width: 440, height: 620)
                .preferredColorScheme(appTheme.colorScheme)
        } label: {
            MenuBarStatusView(summary: store.summary, isRefreshing: store.isRefreshing)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: AppWindowID.settings) {
            SettingsView(store: store, appTheme: appThemeBinding)
                .frame(minWidth: 640, minHeight: 420)
                .preferredColorScheme(appTheme.colorScheme)
        }
    }

    private var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .defaultValue
    }

    private var appThemeBinding: Binding<AppTheme> {
        Binding(
            get: { appTheme },
            set: { appThemeRawValue = $0.rawValue }
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

enum AppWindowID {
    static let settings = "settings"
}
