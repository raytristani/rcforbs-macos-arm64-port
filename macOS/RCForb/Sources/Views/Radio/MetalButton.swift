import SwiftUI

enum MetalButtonStyle {
    case light
    case dark
}

/// Reusable metallic button matching the Electron app's metal() style
struct MetalButton: View {
    let title: String
    let isOn: Bool
    var style: MetalButtonStyle = .dark
    var width: CGFloat? = nil
    var height: CGFloat = 22
    var fontSize: CGFloat = 12
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: isOn ? .bold : .regular))
                .foregroundColor(foreground)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: width, height: height)
                .padding(.horizontal, width != nil ? 0 : 8)
        }
        .buttonStyle(.plain)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private var background: some View {
        Group {
            if isOn || style == .light {
                Color.metalLightBottom
            } else {
                Color.metalDarkTop
            }
        }
    }

    private var foreground: Color {
        (isOn || style == .light) ? Color.textDark : Color.cream
    }

    private var borderColor: Color {
        (isOn || style == .light) ? Color.cream : Color.metalDarkBorder
    }
}
