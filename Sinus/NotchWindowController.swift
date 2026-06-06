import AppKit
import SwiftUI
import Combine

final class NotchWindowController: NSObject {

    private var panel: NSPanel?
    private let viewModel: NotchViewModel
    private var screenObserver: NSObjectProtocol?
    private var stateCancellable: AnyCancellable?
    private var mouseMonitor: Any?

    private var collapsedPanelFrame: CGRect = .zero
    private var expandedPanelFrame: CGRect = .zero

    private let expandedWidth: CGFloat = 380
    private let expandedHeight: CGFloat = 120
    private let collapsedPadding: CGFloat = 20

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init()
        buildPanel()
        observeScreenChanges()
    }

    // MARK: - Panel setup

    private func buildPanel() {
        guard let screen = primaryNotchScreen() else { return }

        let notchF = notchFrame(on: screen)
        Task { @MainActor in viewModel.updateNotchFrame(notchF) }

        collapsedPanelFrame = makeCollapsedFrame(notchFrame: notchF)
        expandedPanelFrame  = makeExpandedFrame(notchFrame: notchF)

        let panel = NSPanel(
            contentRect: collapsedPanelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Panel receives clicks for future interactive content but hover is
        // handled via a global event monitor — independent of window bounds.
        panel.ignoresMouseEvents = false

        let rootView = NotchView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        // Panel owns the frame — prevent SwiftUI from trying to resize the hosting view.
        hostingView.sizingOptions = []
        hostingView.frame = panel.contentView?.bounds ?? collapsedPanelFrame
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        self.panel = panel
        subscribeToState()
        startMouseMonitoring()

        panel.orderFrontRegardless()
    }

    // MARK: - State-driven panel animation

    private func subscribeToState() {
        stateCancellable = viewModel.$state
            .receive(on: RunLoop.main)
            .dropFirst()
            .sink { [weak self] state in
                self?.animatePanel(to: state)
            }
    }

    private func animatePanel(to state: NotchViewModel.State) {
        guard let panel = panel else { return }
        let targetFrame = state == .expanded ? expandedPanelFrame : collapsedPanelFrame
        let duration: TimeInterval = state == .expanded ? 0.42 : 0.35
        let timing = state == .expanded
            ? CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.35, 1.0)
            : CAMediaTimingFunction(controlPoints: 0.25, 0.8, 0.35, 1.0)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = timing
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    // MARK: - Mouse monitoring (global, geometry-based)
    //
    // Tracking areas on a resizing panel fire spurious enter/exit events
    // mid-animation. A global monitor checking fixed rects is immune to this.

    private func startMouseMonitoring() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.evaluateMousePosition()
        }
    }

    private func stopMouseMonitoring() {
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        mouseMonitor = nil
    }

    private func evaluateMousePosition() {
        let loc = NSEvent.mouseLocation
        // Expand when cursor enters the collapsed notch zone.
        // Stay expanded while cursor remains anywhere in the expanded panel area.
        let shouldExpand = collapsedPanelFrame.contains(loc)
        let shouldStayExpanded = expandedPanelFrame.contains(loc)

        Task { @MainActor [weak self] in
            guard let self else { return }
            if shouldExpand || shouldStayExpanded {
                if viewModel.state == .collapsed { viewModel.expand() }
            } else {
                if viewModel.state == .expanded { viewModel.collapse() }
            }
        }
    }

    // MARK: - Geometry

    private func primaryNotchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private func notchFrame(on screen: NSScreen) -> CGRect {
        let insets = screen.safeAreaInsets
        let notchHeight: CGFloat = insets.top > 0 ? insets.top : 32
        let notchWidth: CGFloat = 126
        let x = screen.frame.midX - notchWidth / 2
        let y = screen.frame.maxY - notchHeight
        return CGRect(x: x, y: y, width: notchWidth, height: notchHeight)
    }

    private func makeCollapsedFrame(notchFrame: CGRect) -> CGRect {
        CGRect(
            x: notchFrame.midX - (notchFrame.width / 2 + collapsedPadding),
            y: notchFrame.minY,
            width: notchFrame.width + collapsedPadding * 2,
            height: notchFrame.height
        )
    }

    private func makeExpandedFrame(notchFrame: CGRect) -> CGRect {
        CGRect(
            x: notchFrame.midX - expandedWidth / 2,
            y: notchFrame.maxY - expandedHeight,
            width: expandedWidth,
            height: expandedHeight
        )
    }

    // MARK: - Screen change observation

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuild()
        }
    }

    private func rebuild() {
        stopMouseMonitoring()
        stateCancellable = nil
        panel?.close()
        panel = nil
        buildPanel()
    }
}
