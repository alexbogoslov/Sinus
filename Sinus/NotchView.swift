// NotchView.swift
// SwiftUI view rendered inside the NSPanel.
// Receives notch geometry from NotchWindowController via NotchViewModel;
// keeps the global-mouse-monitor expand/collapse from the controller.

import SwiftUI

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel

    @State private var breathePhase:  CGFloat = 0
    @State private var shadowOpacity: CGFloat = 0

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

    var body: some View {
        ZStack(alignment: .top) {

            // ── Shadow layer ──────────────────────────────────────────────
            // A blurred copy of the panel shape, behind the panel — same
            // path, same parameters, no scaling. The blur alone feathers
            // the silhouette outward to transparent. The opaque panel above
            // hides the overlap, so only the soft halo is visible.
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
            .blur(radius: 12)
            .opacity(shadowOpacity)

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
        .onAppear { startBreathing() }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                withAnimation(.easeIn(duration: 0.1).delay(0.05)) { shadowOpacity = 0.45 }
            } else {
                shadowOpacity = 0   // instant — no animation on collapse
            }
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
