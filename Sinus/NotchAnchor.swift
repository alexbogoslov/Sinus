// NotchAnchor.swift
// Reads exact notch geometry from NSScreen.
// NotchGeometry is the single source of truth for all notch sizing in Sinus.

import AppKit

struct NotchGeometry {
    let x: CGFloat              // notch left edge in screen coords
    let width: CGFloat          // notch hardware width
    let height: CGFloat         // notch hardware height (safeAreaInsets.top)
    let bendRadius: CGFloat     // hardware notch corner tightness (~8 pt)
    let shoulderRadius: CGFloat // concave ramp radius (~36 pt)

    /// Total width of the expanded panel frame (body + both shoulders).
    var expandedFrameWidth: CGFloat { expandedBodyWidth + 2 * shoulderRadius }

    /// Body-only expanded width (content area, excluding shoulder ramps).
    let expandedBodyWidth: CGFloat = 380

    /// Expanded panel height (shoulder depth + content + bottom padding).
    let expandedHeight: CGFloat = 120
}

class NotchAnchorWindow: NSWindow {

    /// Returns nil on screens without a hardware notch.
    static func notchGeometry(for screen: NSScreen) -> NotchGeometry? {
        guard screen.safeAreaInsets.top > 0,
              let leftArea  = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else { return nil }

        let notchLeft   = leftArea.maxX
        let notchRight  = rightArea.minX
        let notchWidth  = notchRight - notchLeft
        let notchHeight = screen.safeAreaInsets.top

        return NotchGeometry(
            x:             notchLeft,
            width:         notchWidth,
            height:        notchHeight,
            bendRadius:    8,
            shoulderRadius: 10
        )
    }
}
