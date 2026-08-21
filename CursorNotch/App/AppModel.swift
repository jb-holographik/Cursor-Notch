import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let settings = AppSettings()
    let detector = CursorDetector()
    let hookManager = CursorHookManager()
    let notch = NotchWindowManager()
    let stateManager = CursorStateManager()

    private let events = HookEventServer()
    var isTestingWorking = false

    var cursorDetected: Bool { detector.isInstalled }
    var hooksInstalled: Bool { hookManager.isInstalled }
    var setupError: String?

    func start() {
        detector.refresh()
        do {
            try hookManager.installIfNeeded()
            setupError = nil
        } catch {
            setupError = error.localizedDescription
        }

        stateManager.onChange = { [weak self] state in
            self?.present(state)
        }

        events.onEvent = { [weak self] event in
            self?.handle(event)
        }
        events.start()

        notch.prepare()
        observeWorkspace()

        if settings.launchAtLogin {
            LaunchAtLogin.setEnabled(true)
        }

        if !settings.hasCompletedFirstLaunch {
            settings.hasCompletedFirstLaunch = true
            showFirstRunAlert()
        }
    }

    func testWorkingAnimation() {
        if isTestingWorking {
            stopWorkingTest()
            return
        }
        isTestingWorking = true
        stateManager.forceWorking()
    }

    func stopWorkingTest() {
        isTestingWorking = false
        stateManager.resetToIdle()
    }

    func testCompletionNotification() {
        isTestingWorking = false
        stateManager.forceCompleted()
    }

    func refreshCursor() {
        detector.refresh()
        hookManager.refresh()
    }

    func activateCursor() {
        detector.activateCursor()
        if stateManager.state == .completed {
            stateManager.resetToIdle()
        }
    }

    func applyWorkingIndicatorSetting(_ enabled: Bool) {
        guard stateManager.state == .working else { return }
        if enabled {
            notch.showWorking()
        } else {
            notch.hide()
        }
    }

    private func handle(_ event: CursorEvent) {
        isTestingWorking = false
        stateManager.apply(event)
    }

    private func present(_ state: NotchState) {
        switch state {
        case .idle:
            notch.hide()
        case .working:
            if settings.workingIndicatorEnabled || isTestingWorking {
                notch.showWorking()
            } else {
                notch.hide()
            }
        case .completed:
            notch.showFinished(duration: settings.notificationDuration) { [weak self] in
                self?.stateManager.resetToIdle()
            }
            playCompletionSoundIfNeeded()
        }
    }

    private func playCompletionSoundIfNeeded() {
        guard settings.soundEnabled else { return }
        NSSound(named: "Glass")?.play()
    }

    private func observeWorkspace() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.notch.relayout()
            }
        }
        workspace.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  CursorDetector.isCursor(app)
            else { return }
            Task { @MainActor in
                self?.isTestingWorking = false
                self?.stateManager.resetToIdle()
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.notch.relayout()
            }
        }
    }

    private func showFirstRunAlert() {
        let alert = NSAlert()
        alert.messageText = "Cursor Notch is ready"
        alert.informativeText = firstRunText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Test working animation")
        alert.addButton(withTitle: "Test completion")
        alert.addButton(withTitle: "OK")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            testWorkingAnimation()
        case .alertSecondButtonReturn:
            testCompletionNotification()
        default:
            break
        }
    }

    private var firstRunText: String {
        var lines: [String] = []
        if cursorDetected {
            lines.append("Cursor is installed.")
        } else {
            lines.append("Cursor was not detected. Install Cursor, then use the menu to re-check.")
        }
        if hookManager.isInstalled {
            lines.append("A user hook was added to ~/.cursor/hooks.json. Existing hooks were left in place.")
        } else if let setupError {
            lines.append(setupError)
        }
        lines.append("No extra macOS permission is required. Cursor reloads hooks automatically; restart Cursor once if a running Agent does not notify.")
        return lines.joined(separator: "\n\n")
    }
}
