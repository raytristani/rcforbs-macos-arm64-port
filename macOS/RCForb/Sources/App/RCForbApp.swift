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
                .tint(Color.creamDark)
                .handlesExternalEvents(preferring: ["main"], allowing: ["main"])
        }
        .handlesExternalEvents(matching: ["main"])
        .windowStyle(.titleBar)
        .defaultSize(width: 1395, height: 833)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Override table row selection color to match Android's CreamDark (#ECEADE)
        NSColor.swizzleSelectionColors()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)

        // Disable File > New Window menu item to prevent multiple windows
        NSApp.windows.forEach { $0.tabbingMode = .disallowed }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Custom table row selection color via NSColor swizzle

extension NSColor {
    @objc dynamic class var custom_selectedContentBackgroundColor: NSColor {
        return NSColor(red: 0.925, green: 0.918, blue: 0.871, alpha: 1.0) // #ECEADE
    }

    @objc dynamic class var custom_alternateSelectedControlColor: NSColor {
        return NSColor(red: 0.925, green: 0.918, blue: 0.871, alpha: 1.0)
    }

    static func swizzleSelectionColors() {
        // selectedContentBackgroundColor (used by NSTableView for row selection)
        if let original = class_getClassMethod(NSColor.self, #selector(getter: NSColor.selectedContentBackgroundColor)),
           let swizzled = class_getClassMethod(NSColor.self, #selector(getter: NSColor.custom_selectedContentBackgroundColor)) {
            method_exchangeImplementations(original, swizzled)
        }
        // alternateSelectedControlColor (fallback used by some table styles)
        if let original = class_getClassMethod(NSColor.self, #selector(getter: NSColor.alternateSelectedControlColor)),
           let swizzled = class_getClassMethod(NSColor.self, #selector(getter: NSColor.custom_alternateSelectedControlColor)) {
            method_exchangeImplementations(original, swizzled)
        }
    }
}
