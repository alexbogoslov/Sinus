// NotchWindowController.swift
// Owns the NSPanel that lives above the menu bar and drives all notch state.
// Geometry is read once at launch (and on display changes) via NotchAnchorWindow,
// which reads safeAreaInsets and auxiliaryTopLeftArea/auxiliaryTopRightArea directly
// from NSScreen — no guesswork, no hard-coded measurements.

import AppKit
import SwiftUI
import Combine

final class NotchWindowController: NSObject {

    private var panel: NSPanel?
    private let viewModel: NotchViewModel
    private var screenObserver: NSObjectProtocol?
    private var stateCancellable: AnyCancellable?
    private var mouseMonitor: Any?

    // Hot-zone geometry (screen coords, updated whenever display config changes).
    private var notchHotZone:    CGRect = .zero   // triggers expand on hover
    private var expandedFrame:   CGRect = .zero   // keeps panel expanded while inside
    private var geometry: NotchGeometry?           // hardware measurements

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init()
        buildPanel()
        observeScreenChanges()
    }

    // MARK: - Panel setup

    private func buildPanel() {
        guard let screen = primaryNotchScreen(),
              let geo    = NotchAnchorWindow.notchGeometry(for: screen) else { return }

        geometry = geo
        Task { @MainActor in
            // Tell the view the collapsed (hardware) dimensions.
            viewModel.updateNotchFrame(
                CGRect(x: geo.x,
                       y: screen.frame.maxY - geo.height,
                       width:  geo.width,
                       height: geo.height)
            )
        }

        // Hot-zone = the physical notch rectangle (triggers expand on hover).
        notchHotZone = CGRect(
            x:      geo.x,
            y:      screen.frame.maxY - geo.height,
            width:  geo.width,
            height: geo.height
        )

        // Panel frame = full expanded size (body + shoulders), centred on notch.
        let panelW = geo.expandedFrameWidth
        let panelH = geo.expandedHeight
        let panelX = (geo.x + geo.width / 2 - panelW / 2).rounded()
        let panelY = (screen.frame.maxY - panelH).rounded()
        expandedFrame = CGRect(x: panelX, y: panelY, width: panelW, height: panelH)

        let panel = NSPanel(
            contentRect: expandedFrame,
            styleMask:   [.borderless, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.level            = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque         = false
        panel.backgroundColor  = .clear
        panel.hasShadow        = false
        panel.ignoresMouseEvents = true   // starts collapsed; toggled in subscribeToState()

        let hostingView = NSHostingView(rootView: NotchView(viewModel: viewModel))
        hostingView.sizingOptions    = []
        hostingView.frame            = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        self.panel = panel
        subscribeToState()
        startMouseMonitoring()
        panel.orderFrontRegardless()
    }

    // MARK: - State subscription

    private func subscribeToState() {
        stateCancellable = viewModel.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                // Pass-through clicks to the menu bar when the panel is collapsed.
                self?.panel?.ignoresMouseEvents = (state == .collapsed)
            }
    }

    // MARK: - Mouse monitoring
    // Global monitor instead of NSTrackingArea — tracking areas fire spuriously
    // while the panel itself is resizing/animating.

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
        Task { @MainActor [weak self] in
            guard let self else { return }
            let overNotch   = notchHotZone.contains(loc)
            let overExpanded = viewModel.state == .expanded && expandedFrame.contains(loc)
            if overNotch || overExpanded {
                if viewModel.state == .collapsed { viewModel.expand() }
            } else {
                if viewModel.state == .expanded  { viewModel.collapse() }
            }
        }
    }

    // MARK: - Screen change observation

    private func primaryNotchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object:  nil,
            queue:   .main
        ) { [weak self] _ in self?.rebuild() }
    }

    private func rebuild() {
        stopMouseMonitoring()
        stateCancellable = nil
        panel?.close()
        panel = nil
        buildPanel()
    }
}
