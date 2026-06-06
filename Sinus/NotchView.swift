import SwiftUI

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel

    @State private var breathePhase: CGFloat = 0

    var isExpanded: Bool { viewModel.state == .expanded }

    // These match the constants in NotchWindowController.
    private let notchWidth: CGFloat  = 126
    private let notchHeight: CGFloat = 32

    var body: some View {
        ZStack(alignment: .top) {
            if isExpanded {
                // Integrated shape: traces the notch cutout and matching ear curves.
                NotchPanelShape(notchWidth: notchWidth, notchHeight: notchHeight)
                    .fill(Color.black)
                    .overlay(alignment: .bottom) {
                        expandedContent
                            .padding(.bottom, 16)
                            .transition(
                                .opacity.animation(.easeOut(duration: 0.2).delay(0.08))
                            )
                    }
            } else {
                // Collapsed: simple pill the width of the physical notch.
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black)
                    .overlay(alignment: .center) {
                        collapsedContent
                            .transition(
                                .opacity.animation(.easeIn(duration: 0.12))
                            )
                    }
            }
        }
        .onAppear { startBreathing() }
    }

    // MARK: - Content

    private var collapsedContent: some View {
        BreathingDot(phase: breathePhase)
    }

    private var expandedContent: some View {
        Text("Sinus")
            .font(.system(.body, design: .rounded).weight(.medium))
            .foregroundColor(.white.opacity(0.7))
    }

    // MARK: - Breathing

    private func startBreathing() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            breathePhase = 1
        }
    }
}

// MARK: - Breathing indicator

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
    VStack(spacing: 20) {
        NotchPanelShape(notchWidth: 126, notchHeight: 32)
            .fill(Color.black)
            .frame(width: 380, height: 120)

        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.black)
            .frame(width: 166, height: 32)
    }
    .padding()
    .background(Color(white: 0.85))
}
