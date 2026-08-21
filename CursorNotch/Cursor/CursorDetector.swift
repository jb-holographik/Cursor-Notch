import AppKit
import Foundation

struct CursorDetector: Sendable {
    static let bundleIdentifiers = [
        "com.todesktop.230313mzl4w4u92",
        "com.anysphere.cursor",
    ]

    var isInstalled: Bool { applicationURL != nil }

    var isRunning: Bool {
        !NSWorkspace.shared.runningApplications.filter(Self.isCursor(_:)).isEmpty
    }

    var applicationURL: URL? {
        for identifier in Self.bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
                return url
            }
        }
        let fallbacks = [
            URL(fileURLWithPath: "/Applications/Cursor.app"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications/Cursor.app"),
        ]
        return fallbacks.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    func refresh() {
        _ = isInstalled
        _ = isRunning
    }

    func activateCursor() {
        if let running = NSWorkspace.shared.runningApplications.first(where: Self.isCursor) {
            running.activate(options: [.activateIgnoringOtherApps])
            return
        }
        guard let url = applicationURL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    static func isCursor(_ app: NSRunningApplication) -> Bool {
        if let identifier = app.bundleIdentifier, bundleIdentifiers.contains(identifier) {
            return true
        }
        return app.localizedName == "Cursor"
    }
}
