import SwiftUI

struct NotchNotificationView: View {
    let appearance: NotchAppearance
    let onActivateCursor: () -> Void

    var body: some View {
        Button(action: onActivateCursor) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .background(islandBackground)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.28), value: appearance)
    }

    @ViewBuilder
    private var content: some View {
        switch appearance {
        case .hidden:
            Color.clear
        case .working:
            CursorDotsAnimation()
                .transition(.opacity.combined(with: .scale(scale: 0.88)))
        case .finished:
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Cursor")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Task finished")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private var islandBackground: some View {
        VisualEffectPill()
            .overlay(Color.black.opacity(0.45))
    }
}

private struct VisualEffectPill: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
