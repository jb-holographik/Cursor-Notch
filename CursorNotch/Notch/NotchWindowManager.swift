import AppKit
import SwiftUI

enum NotchAppearance: Equatable {
    case hidden
    case working
    case finished
}

@MainActor
final class NotchWindowManager {
    private var panel: NotchPanel?
    private var hosting: NSHostingView<NotchNotificationView>?
    private var hideWork: DispatchWorkItem?
    private var appearance: NotchAppearance = .hidden
    private var hideCompletion: (() -> Void)?

    func prepare() {
        if panel == nil {
            makePanel()
        }
        relayout()
    }

    func showWorking() {
        hideWork?.cancel()
        hideCompletion = nil
        appearance = .working
        present(animatedFromHidden: panel?.isVisible != true)
    }

    func showFinished(duration: Double, onHidden: (() -> Void)? = nil) {
        hideWork?.cancel()
        hideCompletion = onHidden
        appearance = .finished
        present(animatedFromHidden: panel?.isVisible != true)
        let work = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        hideWork = nil
        appearance = .hidden
        let completion = hideCompletion
        hideCompletion = nil
        guard let panel, panel.isVisible else {
            completion?()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
            completion?()
        }
    }

    func relayout() {
        guard let panel else { return }
        panel.setFrame(NotchGeometry.panelFrame(for: appearance), display: true)
        if appearance != .hidden, panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func present(animatedFromHidden: Bool) {
        prepare()
        guard let panel, let hosting else { return }
        hosting.rootView = NotchNotificationView(
            appearance: appearance,
            onActivateCursor: {
                AppModel.shared.activateCursor()
            }
        )
        let frame = NotchGeometry.panelFrame(for: appearance)
        if animatedFromHidden {
            panel.alphaValue = 0
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
            panel.orderFrontRegardless()
        }
    }

    private func makePanel() {
        let view = NotchNotificationView(appearance: .hidden, onActivateCursor: {})
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: NotchGeometry.finishedSize)
        let panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: NotchGeometry.finishedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        self.panel = panel
        self.hosting = hostingView
    }
}

enum NotchGeometry {
    static let workingSize = NSSize(width: 86, height: 34)
    static let finishedSize = NSSize(width: 176, height: 54)

    static func panelFrame(for appearance: NotchAppearance) -> NSRect {
        let size: NSSize = appearance == .finished ? finishedSize : workingSize
        let screen = preferredScreen()
        let frame = screen.frame
        let notchHeight = screen.safeAreaInsets.top
        let y: CGFloat
        if notchHeight > 20 {
            y = frame.maxY - notchHeight - 1
        } else {
            y = frame.maxY - size.height + 2
        }
        let extraDrop: CGFloat = appearance == .finished ? 4 : 0
        return NSRect(
            x: frame.midX - size.width / 2,
            y: y - extraDrop,
            width: size.width,
            height: size.height
        )
    }

    /// Prefer the built-in notched display. If none exists (clamshell, Studio
    /// Display, VM), use the main screen and pin the overlay to the top center.
    static func preferredScreen() -> NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 20 }
            ?? NSScreen.main
            ?? NSScreen.screens.first
            ?? NSScreen.screens[0]
    }
}
