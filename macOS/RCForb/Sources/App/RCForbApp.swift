import SwiftUI
import AppKit

@main
struct RCForbApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var connectionManager = ConnectionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionManager)
                .frame(minWidth: 720, minHeight: 400)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1224, height: 893)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Critical: without this, a CLI-launched SwiftUI app has no activation
        // policy and macOS will never give it keyboard focus.
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bring to front over VS Code / terminal
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
