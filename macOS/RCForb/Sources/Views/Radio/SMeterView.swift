import SwiftUI

struct SMeterView: View {
    let value: Double
    let label: String

    private var pct: Double {
        min(100, max(0, (value / 19.0) * 100))
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: "#c8b868"))
                .frame(height: 14)

            // Bar
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: pct > 60
                                ? [Color(hex: "#669933"), Color(hex: "#cc4422")]
                                : [Color(hex: "#669933"), Color(hex: "#88aa44")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * pct / 100, height: 14)
                    .animation(.easeOut(duration: 0.3), value: pct)
            }
            .frame(height: 14)

            // Label
            Text(label)
                .font(.custom(FontRegistration.digital7Mono, size: 12))
                .foregroundColor(Color(hex: "#553300"))
                .lineLimit(1)
        }
        .frame(height: 14)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color(hex: "#aa9944"), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .onAppear { FontRegistration.registerCustomFonts() }
    }
}
