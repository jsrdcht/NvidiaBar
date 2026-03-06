#if canImport(AppKit)
import AppKit
#endif
import SwiftUI

@MainActor
final class ThemeController: ObservableObject {
    @Published private(set) var appTheme: AppTheme

    private let defaults: UserDefaults
    #if canImport(AppKit)
    private var observers: [NSObjectProtocol] = []
    #endif

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appTheme = AppTheme(rawValue: defaults.string(forKey: AppTheme.storageKey) ?? "") ?? .defaultValue
        registerAppearanceObservers()
        DispatchQueue.main.async { [weak self] in
            self?.applyAppearance()
        }
    }

    func updateTheme(_ appTheme: AppTheme) {
        guard self.appTheme != appTheme else { return }
        self.appTheme = appTheme
        defaults.set(appTheme.rawValue, forKey: AppTheme.storageKey)
        applyAppearance()
    }

    var binding: Binding<AppTheme> {
        Binding(
            get: { self.appTheme },
            set: { self.updateTheme($0) }
        )
    }

    deinit {
        #if canImport(AppKit)
        let center = NotificationCenter.default
        observers.forEach(center.removeObserver)
        #endif
    }

    #if canImport(AppKit)
    private func registerAppearanceObservers() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSApplication.didUpdateNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didDeminiaturizeNotification
        ]

        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let self else { return }
                let window = notification.object as? NSWindow
                DispatchQueue.main.async {
                    if let window {
                        self.applyAppearance(to: window)
                    } else {
                        self.applyAppearance()
                    }
                }
            }
        }
    }

    private func applyAppearance() {
        guard let app = NSApp else { return }
        let appearance = NSAppearance(named: appTheme.appearanceName)
        app.appearance = appearance
        app.windows.forEach(applyAppearance(to:))
    }

    private func applyAppearance(to window: NSWindow) {
        let appearance = NSAppearance(named: appTheme.appearanceName)
        window.appearance = appearance
        window.contentView?.appearance = appearance
        window.invalidateShadow()
        window.displayIfNeeded()
    }
    #else
    private func registerAppearanceObservers() {}
    private func applyAppearance() {}
    #endif
}
