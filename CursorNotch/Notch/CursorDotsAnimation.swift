import SwiftUI

/// Native rendering of Cursor's `DotGridLoader`, using its `sine_3x3`
/// frames and timing from the bundled workbench.
struct CursorDotsAnimation: View {
    var color: Color = .white

    private static let displaySize: CGFloat = 10
    private static let viewBoxSize: CGFloat = 10.5
    private static let dotRadius: CGFloat = 1.125
    private static let spacing: CGFloat = 4
    private static let margin: CGFloat = 1.25
    private static let frameDuration: TimeInterval = 0.175
    private static let frames = [189, 220, 90, 78, 45, 291, 306, 433]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let frameIndex = Int(time / Self.frameDuration) % Self.frames.count
            let mask = Self.frames[frameIndex]
            Canvas { context, _ in
                let scale = Self.displaySize / Self.viewBoxSize
                let radius = Self.dotRadius * scale
                for row in 0..<3 {
                    for column in 0..<3 where isActive(
                        row: row,
                        column: column,
                        mask: mask
                    ) {
                        let center = CGPoint(
                            x: (Self.margin + CGFloat(column) * Self.spacing) * scale,
                            y: (Self.margin + CGFloat(row) * Self.spacing) * scale
                        )
                        let rect = CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: Self.displaySize, height: Self.displaySize)
        .accessibilityLabel("Cursor agent working")
    }

    private func isActive(row: Int, column: Int, mask: Int) -> Bool {
        let bit = (2 - row) * 3 + (2 - column)
        return mask & (1 << bit) != 0
    }
}
