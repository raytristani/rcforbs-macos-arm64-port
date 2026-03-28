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
            RoundedRectangle(cornerRadius: 3)
                .stroke(borderColor, lineWidth: 1)
        )
        .cornerRadius(3)
    }

    private var background: some View {
        Group {
            if isOn || style == .light {
                LinearGradient(colors: [Color.metalLightTop, Color.metalLightBottom], startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(colors: [Color.metalDarkTop, Color.metalDarkBottom], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    private var foreground: Color {
        (isOn || style == .light) ? Color(hex: "#333111") : Color(hex: "#dddcbb")
    }

    private var borderColor: Color {
        (isOn || style == .light) ? Color.cream : Color.metalDarkBorder
    }
}
