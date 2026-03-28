import SwiftUI
import UIKit

/// UITextField wrapper that works properly for text input on iPadOS.
struct StyledTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var fontSize: CGFloat = 13
    var onSubmit: (() -> Void)?

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()

        field.placeholder = placeholder
        field.text = text
        field.font = UIFont.systemFont(ofSize: fontSize)
        field.textColor = UIColor(red: 0.933, green: 0.925, blue: 0.8, alpha: 1.0)
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.isSecureTextEntry = isSecure
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)

        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)

        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text {
            field.text = text
        }
        field.isSecureTextEntry = isSecure
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var onSubmit: (() -> Void)?

        init(text: Binding<String>, onSubmit: (() -> Void)?) {
            self.text = text
            self.onSubmit = onSubmit
        }

        @objc func textChanged(_ field: UITextField) {
            text.wrappedValue = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit?()
            return true
        }
    }
}
