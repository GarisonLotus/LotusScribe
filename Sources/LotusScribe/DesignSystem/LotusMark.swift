import SwiftUI

// MARK: - The lotus mark (design spec §1, variation "1c two-tone")

/// One petal: a tall rounded shape with a wide round top and a narrow base
/// (70/30 vertical corner asymmetry; CSS `border-radius: 50%/70% 70% 30% 30%`).
private struct Petal: Shape {
    func path(in rect: CGRect) -> Path {
        let topRadius = rect.width * 0.5
        let baseRadius = rect.width * 0.18
        return Path(
            UnevenRoundedRectangle(
                topLeadingRadius: topRadius,
                bottomLeadingRadius: baseRadius,
                bottomTrailingRadius: baseRadius,
                topTrailingRadius: topRadius)
            .path(in: rect).cgPath)
    }
}

/// Three-petal lotus mark, two-tone (spec §1 "1c"): a vertical center petal
/// flanked by two petals rotated ±40° about the shared bottom-center base.
/// Left petal solid pink, right petal solid purple, center a vertical
/// pink→purple gradient — all at FULL opacity (the two-tone read is the whole
/// point of variation 1c, replacing the earlier single-gradient/opacity look).
/// The canonical brand mark: shared by the menu-bar + app icons AND the
/// Settings/Onboarding surfaces, so its geometry stays as-shipped.
struct LotusMark: View {
    let size: CGFloat

    init(size: CGFloat) { self.size = size }

    private var petalWidth: CGFloat { size * 0.34 }

    /// Center petal fill: a VERTICAL pink→purple gradient (spec §1 — the token
    /// `LinearGradient.lotusAccent` is horizontal, so build the vertical one
    /// from the same color tokens rather than hardcoding hexes).
    private var centerGradient: LinearGradient {
        LinearGradient(
            colors: [.lotusAccentPink, .lotusAccentPurple],
            startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        ZStack {
            petal(fill: Color.lotusAccentPink)       // left, solid #FF5CA8
                .rotationEffect(.degrees(-40), anchor: .bottom)
            petal(fill: Color.lotusAccentPurple)     // right, solid #C438F0
                .rotationEffect(.degrees(40), anchor: .bottom)
            petal(fill: centerGradient)              // center, vertical gradient
        }
        .frame(width: size, height: size)
    }

    /// A petal pinned to the bottom-center of the size×size frame, so the ±40°
    /// `anchor: .bottom` rotations all fan out from the shared base point.
    private func petal<S: ShapeStyle>(fill: S) -> some View {
        Petal()
            .fill(fill)
            .frame(width: petalWidth, height: size * 0.92)
            .frame(width: size, height: size, alignment: .bottom)
    }
}
