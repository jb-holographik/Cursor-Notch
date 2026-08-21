import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    private enum Keys {
        static let duration = "notificationDuration"
        static let sound = "soundEnabled"
        static let login = "launchAtLogin"
        static let working = "workingIndicatorEnabled"
        static let firstLaunch = "hasCompletedFirstLaunch"
    }

    var notificationDuration: Double {
        didSet { UserDefaults.standard.set(notificationDuration, forKey: Keys.duration) }
    }

    var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: Keys.sound) }
    }

    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.login)
            LaunchAtLogin.setEnabled(launchAtLogin)
        }
    }

    var workingIndicatorEnabled: Bool {
        didSet { UserDefaults.standard.set(workingIndicatorEnabled, forKey: Keys.working) }
    }

    var hasCompletedFirstLaunch: Bool {
        didSet { UserDefaults.standard.set(hasCompletedFirstLaunch, forKey: Keys.firstLaunch) }
    }

    init() {
        let defaults = UserDefaults.standard
        notificationDuration = defaults.object(forKey: Keys.duration) as? Double ?? 3
        soundEnabled = defaults.object(forKey: Keys.sound) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Keys.login) as? Bool ?? true
        workingIndicatorEnabled = defaults.object(forKey: Keys.working) as? Bool ?? true
        hasCompletedFirstLaunch = defaults.bool(forKey: Keys.firstLaunch)
    }
}

enum LaunchAtLogin {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Cursor Notch: launch at login failed: \(error.localizedDescription)")
        }
    }
}
