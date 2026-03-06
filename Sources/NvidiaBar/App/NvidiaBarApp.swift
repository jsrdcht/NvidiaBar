import AppKit
import SwiftUI

@main
struct NvidiaBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
            DashboardView(store: store)
                .frame(width: 440, height: 620)
        } label: {
            MenuBarStatusView(summary: store.summary, isRefreshing: store.isRefreshing)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
                .frame(minWidth: 640, minHeight: 420)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
