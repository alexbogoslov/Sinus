import SwiftUI
import AppKit

@main
struct SinusApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows — Sinus lives entirely in the notch.
        Settings { EmptyView() }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var notchController: NotchWindowController?
    private let viewModel = NotchViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as an accessory so no Dock icon appears.
        NSApp.setActivationPolicy(.accessory)

        // Close any windows Xcode's template may have opened.
        NSApp.windows.forEach { $0.close() }

        notchController = NotchWindowController(viewModel: viewModel)
    }
}
