import AppKit
import Core
import Runtime
import SwiftUI

/// macOS NSWindow host for the live SwiftUI preview during `melody dev`.
final class DevPreviewWindow {
    private var window: NSWindow?
    private let appDelegate = DevAppDelegate()

    func launch(app: AppDefinition) {
        let nsApp = NSApplication.shared
        nsApp.setActivationPolicy(.regular)
        nsApp.delegate = appDelegate

        let contentView = MelodyAppView(appDefinition: app)
        let hostingView = NSHostingView(rootView: contentView)

        let rootWindow = app.app.window
        let w = rootWindow?.idealWidth ?? rootWindow?.minWidth ?? 390
        let h = rootWindow?.idealHeight ?? rootWindow?.minHeight ?? 844
        let frame = NSRect(x: 0, y: 0, width: w, height: h)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        if let minW = rootWindow?.minWidth, let minH = rootWindow?.minHeight {
            window.minSize = NSSize(width: minW, height: minH)
        }
        window.title = "\(app.app.name) — Melody Dev"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.setFrameAutosaveName("MelodyDevPreview")

        self.window = window

        nsApp.activate(ignoringOtherApps: true)
        nsApp.run()
    }
}

private final class DevAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
