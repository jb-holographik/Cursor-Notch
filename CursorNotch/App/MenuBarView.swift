import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Text("Cursor Notch")

        Divider()

        Button {
            model.refreshCursor()
        } label: {
            Text(model.cursorDetected ? "✓ Cursor detected" : "⚠ Cursor not detected")
        }

        if model.cursorDetected {
            Text(model.hooksInstalled ? "Hooks installed" : "Hooks missing")
        }

        Divider()

        Button(model.isTestingWorking ? "Stop working animation" : "Test working animation") {
            model.testWorkingAnimation()
        }

        Button("Test completion notification") {
            model.testCompletionNotification()
        }

        Divider()

        SettingsLink {
            Text("Settings")
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
