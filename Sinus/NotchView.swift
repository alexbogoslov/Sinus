// NotchView.swift
// SwiftUI view rendered inside the NSPanel.
// Receives notch geometry from NotchWindowController via NotchViewModel;
// keeps the global-mouse-monitor expand/collapse from the controller.

import SwiftUI

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel

    @State private var breathePhase: CGFloat = 0

    // Live panel size, fed by AnimatedSizeReporter on every spring frame —
    // this is what lets the CALayer shadow track the animation exactly.
    @State private var panelSize: CGSize = .zero

    var isExpanded: Bool { viewModel.state == .expanded }

    // Collapsed dimensions — driven by hardware geometry read at launch.
    private var collapsedWidth:  CGFloat { viewModel.notchFrame.width  > 0 ? viewModel.notchFrame.width  : 126 }
    private var collapsedHeight: CGFloat { viewModel.notchFrame.height > 0 ? viewModel.notchFrame.height : 37  }

    // Expanded dimensions — body + both shoulders.
    private let expandedBodyWidth:  CGFloat = 380
    private let expandedHeight:     CGFloat = 120
    private let shoulderRadius:     CGFloat = 10
    private let bendRadius:         CGFloat = 8
    private let bottomCornerRadius: CGFloat = 16

    private var expandedTotalWidth: CGFloat { expandedBodyWidth + 2 * shoulderRadius }

    // How far the panel is between collapsed (0) and expanded (1), derived
    // from the live animated width — keeps the shadow's shape morph (bottom
    // corner radius) in step with the panel's own animProgress tween.
    private var shadowProgress: CGFloat {
        let range = expandedTotalWidth - collapsedWidth
        guard range > 0 else { return isExpanded ? 1 : 0 }
        return min(1, max(0, (panelSize.width - collapsedWidth) / range))
    }

    var body: some View {
        ZStack(alignment: .top) {

            // ── Shadow layer ──────────────────────────────────────────────
            // CALayer shadowPath backdrop, NOT a SwiftUI blur. SwiftUI
            // re-renders (breathing loop, mouse-move event processing)
            // kept destroying the blurred-copy approach by re-rasterizing
            // it with the out-of-bounds blur clipped. A CALayer shadow is
            // composited persistently by the window server and is immune
            // to anything happening in the SwiftUI tree above it.
            //
            // The shadowPath is rebuilt from panelSize every layout frame,
            // so the halo grows, overshoots, and settles in lock-step with
            // the spring instead of appearing after the panel lands.
            NotchShadowBackdrop(
                visible:            isExpanded,
                size:               panelSize,
                progress:           shadowProgress,
                shoulderRadius:     shoulderRadius,
                bendRadius:         bendRadius,
                bottomCornerRadius: bottomCornerRadius
            )
            .frame(width: max(panelSize.width, 1), height: max(panelSize.height, 1))
            .allowsHitTesting(false)

            // ── Panel shape ───────────────────────────────────────────────
            // animProgress (0 = collapsed, 1 = expanded) is Animatable, so
            // SwiftUI tweens it with the same spring as the .frame() changes,
            // keeping the shape geometry in sync throughout both expand and
            // collapse without ever snapping to a bare rectangle.
            NotchPanelShape(
                animProgress:       isExpanded ? 1 : 0,
                shoulderRadius:     shoulderRadius,
                bendRadius:         bendRadius,
                bottomCornerRadius: bottomCornerRadius
            )
            .fill(Color.black)
            .frame(
                width:  isExpanded ? expandedTotalWidth : collapsedWidth,
                height: isExpanded ? expandedHeight     : collapsedHeight
            )
            // Animatable modifier — SwiftUI's animation system calls its
            // animatableData setter with spring-interpolated values on every
            // frame (the same machinery that tweens the shape's animProgress).
            // Unlike a GeometryReader observation, this is guaranteed
            // per-frame and reports the exact spring value, overshoot included.
            .modifier(AnimatedSizeReporter(
                size: CGSize(
                    width:  isExpanded ? expandedTotalWidth : collapsedWidth,
                    height: isExpanded ? expandedHeight     : collapsedHeight
                ),
                onUpdate: { panelSize = $0 }
            ))

            // ── Expanded content ──────────────────────────────────────────
            // Constrained to the body width; padded down by shoulderRadius
            // so content sits below the shoulder zone.
            expandedContent
                .frame(width: expandedBodyWidth, height: expandedHeight - shoulderRadius)
                .padding(.top, shoulderRadius)
                .opacity(isExpanded ? 1 : 0)
                .animation(
                    isExpanded
                        ? .easeOut(duration: 0.2).delay(0.14)
                        : .easeIn(duration: 0.08),
                    value: isExpanded
                )

            // ── Collapsed indicator ───────────────────────────────────────
            collapsedContent
                .opacity(isExpanded ? 0 : 1)
                .animation(.easeIn(duration: 0.1), value: isExpanded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(
            isExpanded
                ? .spring(response: 0.55, dampingFraction: 0.75)
                : .spring(response: 0.3,  dampingFraction: 0.75),
            value: isExpanded
        )
        .onAppear {
            panelSize = CGSize(width: collapsedWidth, height: collapsedHeight)
            startBreathing()
        }
    }

    // MARK: - Content placeholders (replaced in Phase 2+)

    private var collapsedContent: some View {
        BreathingDot(phase: breathePhase)
    }

    private var expandedContent: some View {
        VStack {
            Spacer()
            Text("Sinus")
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
        }
    }

    // MARK: - Breathing animation

    private func startBreathing() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            breathePhase = 1
        }
    }
}

// MARK: - Animated size reporter

/// Reports the spring-interpolated size on every animation frame. SwiftUI
/// tweens `animatableData` itself, so this sees every intermediate value —
/// including overshoot — unlike GeometryReader, which only observes layout
/// passes and is not guaranteed to fire per animation frame.
/// The state write is deferred to the next runloop turn because the setter
/// runs during view-update, where writing state directly is illegal.
private struct AnimatedSizeReporter: ViewModifier, Animatable {
    var size: CGSize
    var onUpdate: (CGSize) -> Void

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(size.width, size.height) }
        set {
            size = CGSize(width: newValue.first, height: newValue.second)
            let reported = size
            let callback = onUpdate
            DispatchQueue.main.async { callback(reported) }
        }
    }

    func body(content: Content) -> some View { content }
}

// MARK: - Shadow backdrop

/// CALayer-based shadow behind the panel. The shadowPath is rebuilt from the
/// panel's live animated size on every update (with implicit layer actions
/// disabled — SwiftUI's per-frame geometry IS the animation), so the halo
/// moves in lock-step with the spring. On expand, opacity is also driven by
/// the live progress — transparent at notch size, full strength when settled —
/// so the shadow grows out of the panel rather than fading in on a timer.
/// Collapse keeps a quick 0.12s fade-out.
private struct NotchShadowBackdrop: NSViewRepresentable {
    var visible:            Bool
    var size:               CGSize
    var progress:           CGFloat
    var shoulderRadius:     CGFloat
    var bendRadius:         CGFloat
    var bottomCornerRadius: CGFloat

    private static let targetOpacity: Float = 0.45

    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        guard let layer = v.layer else { return v }
        layer.masksToBounds = false
        layer.shadowColor   = NSColor.black.cgColor
        layer.shadowRadius  = 12
        layer.shadowOffset  = .zero
        layer.shadowOpacity = 0
        return v
    }

    func updateNSView(_ v: NSView, context: Context) {
        guard let layer = v.layer else { return }

        // Track the spring: new path each frame, no implicit CA animation.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.shadowPath = shadowPath()
        CATransaction.commit()

        if visible {
            // Opacity is slaved to the same live geometry as the path:
            // transparent at notch size, full strength when settled. The
            // spring drives both, so the shadow literally grows out of the
            // panel instead of fading in on a timer next to it.
            let target = Self.targetOpacity * Float(progress)
            if layer.shadowOpacity != target {
                layer.removeAnimation(forKey: "shadowFade")
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                layer.shadowOpacity = target
                CATransaction.commit()
            }
        } else if layer.shadowOpacity != 0 {
            // Collapse keeps the quick fade-out — unchanged.
            let fade = CABasicAnimation(keyPath: "shadowOpacity")
            fade.fromValue      = layer.presentation()?.shadowOpacity ?? layer.shadowOpacity
            fade.toValue        = 0
            fade.duration       = 0.12
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.shadowOpacity = 0
            CATransaction.commit()
            layer.add(fade, forKey: "shadowFade")
        }
    }

    /// The SwiftUI path is in top-left-origin coordinates; the layer is
    /// bottom-left-origin, so flip vertically to keep shoulders at the top.
    private func shadowPath() -> CGPath {
        guard size.width > 0, size.height > 0 else {
            return CGPath(rect: .zero, transform: nil)
        }
        let path = NotchPanelShape(
            animProgress:       progress,
            shoulderRadius:     shoulderRadius,
            bendRadius:         bendRadius,
            bottomCornerRadius: bottomCornerRadius
        )
        .path(in: CGRect(origin: .zero, size: size))
        .cgPath

        var flip = CGAffineTransform(translationX: 0, y: size.height).scaledBy(x: 1, y: -1)
        return path.copy(using: &flip) ?? path
    }
}

// MARK: - Breathing dot

private struct BreathingDot: View {
    let phase: CGFloat
    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.12 + phase * 0.08))
            .frame(width: 4 + phase * 2, height: 4 + phase * 2)
            .blur(radius: 1 + phase * 0.5)
    }
}

#Preview {
    ZStack(alignment: .top) {
        Color(white: 0.15).ignoresSafeArea()
        NotchPanelShape(
            animProgress:       1,
            shoulderRadius:     10,
            bendRadius:         8,
            bottomCornerRadius: 16
        )
        .fill(Color.black)
        .frame(width: 380 + 20, height: 120)
        .padding(.top, 8)
    }
}
