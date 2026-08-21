import AppKit
import SwiftUI

@main
struct CursorNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Cursor Notch", systemImage: "capsule.portrait.fill") {
            MenuBarView()
                .environment(AppModel.shared)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(AppModel.shared)
                .frame(width: 360, height: 280)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppModel.shared.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }
}
