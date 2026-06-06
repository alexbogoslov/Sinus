import SwiftUI

/// The shape of the expanded notch panel.
/// Traces the outer boundary including the notch cutout at the top, so the
/// visible area merges seamlessly with the physical notch hardware.
///
///  ┌──────⌒[notch]⌒──────┐  ← earRadius curves at notch-to-menu-bar transition
///  │                      │
///  │                      │
///  └──────────────────────┘  ← bottomRadius corners
struct NotchPanelShape: Shape {

    /// Width of the physical notch in the panel's coordinate space.
    var notchWidth: CGFloat
    /// Height of the notch cutout from the top of the panel.
    var notchHeight: CGFloat
    /// Radius of the concave ear curves where the notch sides meet the menu bar.
    var earRadius: CGFloat = 9
    /// Radius of the inner corners at the notch bottom.
    var innerRadius: CGFloat = 8
    /// Radius of the panel's bottom corners.
    var bottomRadius: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let nl = rect.midX - notchWidth / 2   // notch left x
        let nr = rect.midX + notchWidth / 2   // notch right x
        let nh = notchHeight
        let er = earRadius
        let ir = innerRadius
        let br = bottomRadius

        var p = Path()

        // ── Top-left origin ──────────────────────────────────────────────────
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: nl - er, y: 0))

        // Left ear: concave curve from menu-bar level into notch left wall.
        // Arc center sits AT the notch-left/menu-bar corner point.
        // Counterclockwise (180° → 90°) bows the arc toward the notch interior.
        p.addArc(
            center: CGPoint(x: nl, y: 0),
            radius: er,
            startAngle: .degrees(180),
            endAngle:   .degrees(90),
            clockwise:  false
        )

        // Notch left wall
        p.addLine(to: CGPoint(x: nl, y: nh - ir))

        // Notch bottom-left inner corner (convex from inside the notch)
        p.addArc(
            center: CGPoint(x: nl + ir, y: nh - ir),
            radius: ir,
            startAngle: .degrees(180),
            endAngle:   .degrees(90),
            clockwise:  false
        )

        // Notch bottom edge
        p.addLine(to: CGPoint(x: nr - ir, y: nh))

        // Notch bottom-right inner corner
        p.addArc(
            center: CGPoint(x: nr - ir, y: nh - ir),
            radius: ir,
            startAngle: .degrees(90),
            endAngle:   .degrees(0),
            clockwise:  false
        )

        // Notch right wall
        p.addLine(to: CGPoint(x: nr, y: er))

        // Right ear: concave curve from notch right wall back to menu-bar level
        p.addArc(
            center: CGPoint(x: nr, y: 0),
            radius: er,
            startAngle: .degrees(90),
            endAngle:   .degrees(0),
            clockwise:  false
        )

        // ── Top-right → down right side ───────────────────────────────────
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height - br))

        // Bottom-right corner
        p.addArc(
            center: CGPoint(x: rect.width - br, y: rect.height - br),
            radius: br,
            startAngle: .degrees(0),
            endAngle:   .degrees(90),
            clockwise:  false
        )

        // Bottom edge
        p.addLine(to: CGPoint(x: br, y: rect.height))

        // Bottom-left corner
        p.addArc(
            center: CGPoint(x: br, y: rect.height - br),
            radius: br,
            startAngle: .degrees(90),
            endAngle:   .degrees(180),
            clockwise:  false
        )

        // Left side back to origin
        p.closeSubpath()
        return p
    }
}
