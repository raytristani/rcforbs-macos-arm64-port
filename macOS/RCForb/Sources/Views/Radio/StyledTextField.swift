import SwiftUI
import AppKit

/// NSTextField wrapper that works properly for text input on macOS.
struct StyledTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var fontSize: CGFloat = 13
    var onSubmit: (() -> Void)?

    func makeNSView(context: Context) -> NSTextField {
        let field: NSTextField
        if isSecure {
            field = NSSecureTextField()
        } else {
            field = NSTextField()
        }

        field.placeholderString = placeholder
        field.stringValue = text
        field.font = NSFont.systemFont(ofSize: fontSize)
        field.textColor = NSColor(red: 0.933, green: 0.925, blue: 0.8, alpha: 1.0)
        field.backgroundColor = .clear
        field.isBezeled = false
        field.isBordered = false
        field.focusRingType = .none
        field.drawsBackground = false
        field.isEditable = true
        field.isSelectable = true
        field.delegate = context.coordinator
        field.lineBreakMode = .byTruncatingTail
        field.cell?.sendsActionOnEndEditing = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)

        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onSubmit: (() -> Void)?

        init(text: Binding<String>, onSubmit: (() -> Void)?) {
            self.text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                text.wrappedValue = field.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onSubmit?()
                return true
            }
            return false
        }
    }
}
