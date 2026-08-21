import AppKit
import SwiftUI

struct NotchNotificationView: View {
    let appearance: NotchAppearance
    let layout: NotchGeometry.Layout
    let onActivateCursor: () -> Void

    var body: some View {
        Button(action: onActivateCursor) {
            HStack(spacing: 0) {
                cursorIcon
                    .frame(width: layout.wingWidth)

                Color.clear
                    .frame(width: layout.notchWidth)

                status
                    .frame(width: layout.wingWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(notchBlack)
            .clipShape(attachedShape)
            .contentShape(attachedShape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .animation(.easeInOut(duration: 0.28), value: appearance)
    }

    @ViewBuilder
    private var cursorIcon: some View {
        if appearance == .hidden {
            Color.clear
        } else if let applicationURL = CursorDetector().applicationURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: applicationURL.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6.5, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
        } else {
            Image(systemName: "cursorarrow")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch appearance {
        case .hidden:
            Color.clear
        case .working:
            CursorDotsAnimation(color: .white)
                .transition(.opacity.combined(with: .scale(scale: 0.88)))
        case .finished:
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(red: 0.19, green: 0.82, blue: 0.35))
                .transition(.opacity.combined(with: .scale(scale: 0.72)))
        }
    }

    private var attachedShape: UnevenRoundedRectangle {
        let topRadius: CGFloat = layout.isNotched ? 0 : 13
        return UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: topRadius,
                bottomLeading: 13,
                bottomTrailing: 13,
                topTrailing: topRadius
            ),
            style: .continuous
        )
    }

    private var notchBlack: Color {
        Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
    }

    private var accessibilityLabel: String {
        switch appearance {
        case .hidden:
            "Cursor"
        case .working:
            "Cursor agent working"
        case .finished:
            "Cursor task completed"
        }
    }
}
