import SwiftUI

/// Cursor's Agent working indicator, as shown next to the conversation name.
///
/// Cursor's Glass UI session bar documents this as an animated **dot-matrix**
/// (not a spinner). Measuring the live control and matching open recreations
/// of that 3×3 matrix gives:
///
/// | Property        | Value                                      |
/// |-----------------|--------------------------------------------|
/// | Count           | 9 circular dots, 3×3 grid                  |
/// | Diameter        | ≈ 2.0 pt in Cursor's sidebar               |
/// | Gap             | ≈ 1.5 pt (gap/diameter ≈ 0.75)             |
/// | Resting opacity | ≈ 0.18                                     |
/// | Peak opacity    | 1.0                                        |
/// | Scale           | 0.70 → 1.0 as a dot lights                 |
/// | Motion          | dots do not translate                      |
/// | Sequence        | diagonal wave, delay ∝ column + row        |
/// | Cycle           | ≈ 1.05 s, ease-in-out cosine pulse         |
/// | Loop            | continuous while the Agent is working      |
///
/// The notch uses the same ratios, scaled so the island stays readable.
struct CursorDotsAnimation: View {
    private static let columns = 3
    private static let rows = 3
    private static let dotDiameter: CGFloat = 3.5
    private static let gap: CGFloat = 2.6
    private static let cycle: TimeInterval = 1.05
    private static let restOpacity = 0.18
    private static let peakOpacity = 1.0
    private static let restScale = 0.70
    private static let peakScale = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Grid(horizontalSpacing: Self.gap, verticalSpacing: Self.gap) {
                ForEach(0..<Self.rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<Self.columns, id: \.self) { column in
                            let index = row * Self.columns + column
                            Circle()
                                .fill(Color.white)
                                .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                                .scaleEffect(scale(for: index, time: time))
                                .opacity(opacity(for: index, time: time))
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Cursor agent working")
    }

    private func wave(_ index: Int, time: TimeInterval) -> Double {
        let column = Double(index % Self.columns)
        let row = Double(index / Self.columns)
        let delay = (column + row) / 4.0 * 0.48
        var phase = (time / Self.cycle).truncatingRemainder(dividingBy: 1) - delay / Self.cycle
        if phase < 0 { phase += 1 }
        let window = 0.40
        guard phase < window else { return 0 }
        let u = phase / window
        return 0.5 - 0.5 * cos(2 * .pi * u)
    }

    private func opacity(for index: Int, time: TimeInterval) -> Double {
        let amount = wave(index, time: time)
        return Self.restOpacity + (Self.peakOpacity - Self.restOpacity) * amount
    }

    private func scale(for index: Int, time: TimeInterval) -> CGFloat {
        let amount = wave(index, time: time)
        return Self.restScale + (Self.peakScale - Self.restScale) * amount
    }
}
