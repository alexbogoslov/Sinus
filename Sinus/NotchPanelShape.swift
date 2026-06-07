// NotchPanelShape.swift
// Custom Path that morphs continuously between the collapsed notch shape and
// the expanded panel, driven by animProgress (0 = collapsed, 1 = expanded).
//
// Both states share one formula — the expanded path degenerates to the
// collapsed path when animProgress = 0 (shoulderRadius scales to 0,
// bottomCornerRadius interpolates down to bendRadius, and the shoulder arcs
// collapse to a flat top).
//
// Shoulder geometry (local coords, expanded state):
//
//   (0,0) ──────────────────────────────── (W,0)   ← menu bar line, top edge
//    │╲                                   ╱│
//    │ ╲  left shoulder               right╱│
//    │  ╲ arc bows outward      outward ╱  │
//    │  (sr,sr)──────────────(W-sr,sr)     │
//    │   │                          │      │
//    │   │      panel body          │      │
//    │   ╰──────────────────────────╯      │
//
// shoulderRadius is held constant throughout the animation — the shoulders
// stay fully formed from the first frame of collapse all the way back to
// notch size. Only bottomCornerRadius interpolates down to bendRadius as
// progress goes to 0.
//
// Spring overshoot is clamped at [0, 1] so br never goes negative or over
// its target, while the frame's own spring overshoot remains intact.

import SwiftUI

struct NotchPanelShape: Shape, Animatable {

    // 0 = fully collapsed, 1 = fully expanded; tweened by SwiftUI's animation engine.
    var animProgress:       CGFloat
    var shoulderRadius:     CGFloat   // concave ramp radius (expanded state)
    var bendRadius:         CGFloat   // hardware notch corner (collapsed state)
    var bottomCornerRadius: CGFloat   // panel bottom corners (expanded state)

    var animatableData: CGFloat {
        get { animProgress }
        set { animProgress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        // Shoulders are constant — never scaled by progress.
        let sr = shoulderRadius

        // Only the bottom corner radius interpolates; clamp against spring overshoot.
        let t     = max(0, min(1, animProgress))
        let rawBR = bendRadius + (bottomCornerRadius - bendRadius) * t
        let br    = min(rawBR, (h - sr) / 2, (w - 2 * sr) / 2)

        var p = Path()

        // ── Top-left (menu-bar line) ──────────────────────────────────────────
        p.move(to: CGPoint(x: 0, y: 0))

        // ── Left shoulder (concave ramp; degenerates to a point when sr = 0) ──
        // Centre on the left edge at (0, sr). Sweeps screen-CW from 270° to 0°.
        p.addArc(center:     CGPoint(x: 0,  y: sr),
                 radius:     sr,
                 startAngle: .degrees(270),
                 endAngle:   .degrees(0),
                 clockwise:  false)

        // ── Left side ─────────────────────────────────────────────────────────
        p.addLine(to: CGPoint(x: sr, y: h - br))

        // ── Bottom-left convex corner ──────────────────────────────────────────
        p.addArc(center:     CGPoint(x: sr + br, y: h - br),
                 radius:     br,
                 startAngle: .degrees(180),
                 endAngle:   .degrees(90),
                 clockwise:  true)

        // ── Bottom edge ────────────────────────────────────────────────────────
        p.addLine(to: CGPoint(x: w - sr - br, y: h))

        // ── Bottom-right convex corner ─────────────────────────────────────────
        p.addArc(center:     CGPoint(x: w - sr - br, y: h - br),
                 radius:     br,
                 startAngle: .degrees(90),
                 endAngle:   .degrees(0),
                 clockwise:  true)

        // ── Right side ─────────────────────────────────────────────────────────
        p.addLine(to: CGPoint(x: w - sr, y: sr))

        // ── Right shoulder (mirrored; degenerates to a point when sr = 0) ──────
        // Centre on the right edge at (w, sr). Sweeps screen-CW from 180° to 270°.
        p.addArc(center:     CGPoint(x: w,  y: sr),
                 radius:     sr,
                 startAngle: .degrees(180),
                 endAngle:   .degrees(270),
                 clockwise:  false)

        // ── closeSubpath draws the top edge: (w, 0) → (0, 0) ─────────────────
        p.closeSubpath()
        return p
    }
}
