import SwiftUI

/// Flat metallic dropdown matching the Electron app's `<select>` elements.
/// Uses SwiftUI Menu for iPadOS instead of NSMenu.
struct MetalDropdown: View {
    let value: String
    let options: [String]
    let onChange: (String) -> Void

    var body: some View {
        Menu {
            let items = options.isEmpty ? [value.isEmpty ? "---" : value] : options
            ForEach(items, id: \.self) { opt in
                Button(action: { onChange(opt) }) {
                    HStack {
                        Text(opt)
                        if opt == value {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
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
        }
    }
}
