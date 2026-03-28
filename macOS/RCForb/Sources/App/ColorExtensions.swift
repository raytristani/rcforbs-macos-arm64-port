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

    // Theme colors matching CSS variables
    static let chassisBg = Color(hex: "#666666")
    static let chassisGradientFrom = Color(hex: "#888666")
    static let chassisGradientTo = Color(hex: "#666555")
    static let cream = Color(hex: "#eeeccc")
    static let creamDark = Color(hex: "#cccaaa")
    static let textDark = Color(hex: "#555333")
    static let lcdText = Color(hex: "#3a0500")
    static let lcdGlow = Color(hex: "#aa6633")
    static let ledGreen = Color(hex: "#00cc00")
    static let ledRed = Color(hex: "#cc0000")
    static let btnBorder = Color(hex: "#aaa999")
    static let statusActive = Color(hex: "#faed80")
    static let panelBgTop = Color(hex: "#4a4a3c")
    static let panelBgBottom = Color(hex: "#3a3a2e")
    static let panelBorder = Color(hex: "#5a5a48")
    static let metalLightTop = Color(hex: "#eeeccc")
    static let metalLightBottom = Color(hex: "#cccaaa")
    static let metalDarkTop = Color(hex: "#7a7a60")
    static let metalDarkBottom = Color(hex: "#5a5a48")
    static let metalDarkBorder = Color(hex: "#8a8a70")
    static let inputBgTop = Color(hex: "#555444")
    static let inputBgBottom = Color(hex: "#444333")
    static let labelDim = Color(hex: "#888870")
    static let labelMuted = Color(hex: "#999980")
    static let labelSubtle = Color(hex: "#aaa999")
}
