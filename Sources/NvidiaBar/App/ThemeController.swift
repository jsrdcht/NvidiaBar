import SwiftUI

@MainActor
final class ThemeController: ObservableObject {
    @Published private(set) var appTheme: AppTheme

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appTheme = AppTheme(rawValue: defaults.string(forKey: AppTheme.storageKey) ?? "") ?? .defaultValue
    }

    func updateTheme(_ appTheme: AppTheme) {
        guard self.appTheme != appTheme else { return }
        self.appTheme = appTheme
        defaults.set(appTheme.rawValue, forKey: AppTheme.storageKey)
    }

    var binding: Binding<AppTheme> {
        Binding(
            get: { self.appTheme },
            set: { self.updateTheme($0) }
        )
    }
}
