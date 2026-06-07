import SwiftUI
import Combine

@MainActor
final class NotchViewModel: ObservableObject {

    enum State { case collapsed, expanded }

    @Published private(set) var state: State = .collapsed
    @Published private(set) var notchFrame: CGRect = .zero

    // State is set directly — the view owns all animation via .animation() modifiers.
    func expand() {
        guard state == .collapsed else { return }
        state = .expanded
    }

    func collapse() {
        guard state == .expanded else { return }
        state = .collapsed
    }

    func updateNotchFrame(_ frame: CGRect) {
        notchFrame = frame
    }
}
