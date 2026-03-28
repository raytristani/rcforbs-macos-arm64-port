import SwiftUI
import AppKit

/// Flat metallic dropdown matching the Electron app's `<select>` elements.
/// Renders as a flat gradient bar; opens an NSMenu on click.
struct MetalDropdown: View {
    let value: String
    let options: [String]
    let onChange: (String) -> Void

    var body: some View {
        Text(value.isEmpty ? "---" : value)
            .font(.system(size: 12))
            .foregroundColor(Color.cream)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .frame(height: 22)
            .background(
                LinearGradient(
                    colors: [Color.chassisGradientFrom, Color.chassisGradientTo],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.btnBorder, lineWidth: 1)
            )
            .cornerRadius(3)
            .contentShape(Rectangle())
            .onTapGesture {
                showMenu()
            }
    }

    private func showMenu() {
        let menu = NSMenu()
        let items = options.isEmpty ? [value.isEmpty ? "---" : value] : options
        for opt in items {
            let item = NSMenuItem(title: opt, action: #selector(MenuTarget.selected(_:)), keyEquivalent: "")
            item.target = MenuTarget.shared
            item.representedObject = opt
            if opt == value {
                item.state = .on
            }
            menu.addItem(item)
        }

        MenuTarget.shared.onChange = onChange

        // Position menu at the mouse
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }
}

/// Shared target for NSMenu item actions
private class MenuTarget: NSObject {
    static let shared = MenuTarget()
    var onChange: ((String) -> Void)?

    @objc func selected(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? String {
            onChange?(value)
        }
    }
}
