import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // Nova Olive dark theme — matching Android AppColors exactly
    // Derived from shadcn/ui radix-nova olive preset

    // Core backgrounds (dark olive)
    static let background = Color(hex: "#252520")
    static let card = Color(hex: "#373730")
    static let secondary = Color(hex: "#45453A")
    static let surfaceDark = background
    static let darkPanel = Color(hex: "#2D2D28")
    static let chatBg = card

    // Core foregrounds
    static let foreground = Color(hex: "#FCFCFA")
    static let mutedForeground = Color(hex: "#B3B1A0")
    static let cream = foreground
    static let creamDark = Color(hex: "#ECEADE")
    static let textDark = Color(hex: "#373730")

    // Borders & inputs
    static let border = Color(hex: "#3D3D36")
    static let inputBg = Color(hex: "#3D3D36")
    static let panelBorder = border
    static let metalDarkBorder = Color(hex: "#4A4A40")
    static let btnBorder = Color(hex: "#4A4A40")

    // Buttons
    static let metalLightBottom = creamDark
    static let metalLightTop = creamDark
    static let metalDarkTop = secondary
    static let metalDarkBottom = secondary

    // Headers / toolbar
    static let chassisGradientFrom = secondary
    static let chassisGradientTo = secondary
    static let chassisBg = secondary

    // Panels
    static let panelBgTop = card
    static let panelBgBottom = card

    // Inputs
    static let inputBgTop = inputBg
    static let inputBgBottom = inputBg

    // Labels (muted foreground variants)
    static let labelDim = mutedForeground.opacity(0.6)
    static let labelMuted = mutedForeground
    static let labelSubtle = mutedForeground.opacity(0.8)

    // Functional colors
    static let lcdText = Color(hex: "#3A0500")
    static let lcdGlow = Color(hex: "#AA6633")
    static let ledGreen = Color(hex: "#44CC44")
    static let ledRed = Color(hex: "#CC4444")

    // Status
    static let statusActive = creamDark

    // Error / destructive
    static let errorBg = Color(hex: "#6B2020").opacity(0.8)
    static let errorText = Color(hex: "#FCA5A5")
    static let errorDismiss = Color(hex: "#F87171")
}
