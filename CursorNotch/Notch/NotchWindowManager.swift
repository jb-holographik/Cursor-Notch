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
        guard let panel, panel.isVisible else {
            finishHide()
            return
        }
        let collapsedFrame = NotchGeometry.layout().collapsedFrame
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(collapsedFrame, display: true)
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard self?.appearance == .hidden else { return }
            self?.finishHide()
        }
    }

    private func finishHide() {
        panel?.orderOut(nil)
        panel?.alphaValue = 1
        let completion = hideCompletion
        hideCompletion = nil
        completion?()
    }

    func relayout() {
        guard let panel, let hosting else { return }
        let layout = NotchGeometry.layout()
        hosting.rootView = makeView(appearance: appearance, layout: layout)
        panel.setFrame(layout.panelFrame, display: true)
        if appearance != .hidden, panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func present(animatedFromHidden: Bool) {
        prepare()
        guard let panel, let hosting else { return }
        let layout = NotchGeometry.layout()
        hosting.rootView = makeView(appearance: appearance, layout: layout)
        if animatedFromHidden {
            panel.alphaValue = 0
            panel.setFrame(layout.collapsedFrame, display: true)
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
                panel.animator().setFrame(layout.panelFrame, display: true)
            }
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(layout.panelFrame, display: true)
            }
            panel.orderFrontRegardless()
        }
    }

    private func makePanel() {
        let layout = NotchGeometry.layout()
        let view = makeView(appearance: .hidden, layout: layout)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: layout.panelFrame.size)
        let panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: layout.panelFrame.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        self.panel = panel
        self.hosting = hostingView
    }

    private func makeView(
        appearance: NotchAppearance,
        layout: NotchGeometry.Layout
    ) -> NotchNotificationView {
        NotchNotificationView(
            appearance: appearance,
            layout: layout,
            onActivateCursor: {
                AppModel.shared.activateCursor()
            }
        )
    }
}

enum NotchGeometry {
    struct Layout: Equatable {
        let panelFrame: NSRect
        let notchWidth: CGFloat
        let wingWidth: CGFloat
        let topCornerRadius: CGFloat
        let bottomCornerRadius: CGFloat
        let isNotched: Bool

        var collapsedFrame: NSRect {
            let width = notchWidth + topCornerRadius * 2
            return NSRect(
                x: panelFrame.midX - width / 2,
                y: panelFrame.minY,
                width: width,
                height: panelFrame.height
            )
        }
    }

    private static let wingWidth: CGFloat = 52
    private static let fallbackNotchWidth: CGFloat = 44
    private static let fallbackHeight: CGFloat = 34
    private static let attachedTopCornerRadius: CGFloat = 6
    private static let bottomCornerRadius: CGFloat = 13

    static func layout() -> Layout {
        let screen = preferredScreen()
        let frame = screen.frame
        let notchHeight = screen.safeAreaInsets.top
        if notchHeight > 20,
           let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea,
           leftArea.maxX < rightArea.minX
        {
            let notchWidth = rightArea.minX - leftArea.maxX
            let panelFrame = NSRect(
                x: leftArea.maxX - wingWidth - attachedTopCornerRadius,
                y: frame.maxY - notchHeight,
                width: notchWidth + wingWidth * 2 + attachedTopCornerRadius * 2,
                height: notchHeight
            )
            return Layout(
                panelFrame: panelFrame,
                notchWidth: notchWidth,
                wingWidth: wingWidth,
                topCornerRadius: attachedTopCornerRadius,
                bottomCornerRadius: bottomCornerRadius,
                isNotched: true
            )
        }

        let width = fallbackNotchWidth + wingWidth * 2
        return Layout(
            panelFrame: NSRect(
                x: frame.midX - width / 2,
                y: frame.maxY - fallbackHeight,
                width: width,
                height: fallbackHeight
            ),
            notchWidth: fallbackNotchWidth,
            wingWidth: wingWidth,
            topCornerRadius: 0,
            bottomCornerRadius: bottomCornerRadius,
            isNotched: false
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
