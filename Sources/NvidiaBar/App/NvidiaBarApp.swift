import AppKit
import SwiftUI

@main
struct NvidiaBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: GPUStatusStore
    @StateObject private var themeController: ThemeController

    init() {
        let configStore = ServerConfigStore()
        let store = GPUStatusStore(
            collector: SSHGPUCollector(),
            configStore: configStore
        )
        let themeController = ThemeController()
        _store = StateObject(wrappedValue: store)
        _themeController = StateObject(wrappedValue: themeController)
        store.start()
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView(store: store, appTheme: themeController.appTheme)
                .frame(width: 440, height: 620)
                .appTheme(themeController.appTheme)
                .id("dashboard-\(themeController.appTheme.rawValue)")
        } label: {
            MenuBarStatusView(summary: store.summary, isRefreshing: store.isRefreshing)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: AppWindowID.settings) {
            SettingsView(store: store, appTheme: themeController.binding)
                .frame(minWidth: 640, minHeight: 420)
                .appTheme(themeController.appTheme)
                .id("settings-\(themeController.appTheme.rawValue)")
        }
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
