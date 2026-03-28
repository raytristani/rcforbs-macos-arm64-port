import SwiftUI

struct StatusPillsView: View {
    let statuses: [String: Bool]
    let order: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(order, id: \.self) { name in
                let isOn = statuses[name] ?? false
                Text(name)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(isOn ? Color(hex: "#333000") : Color.black)
                    .opacity(isOn ? 0.8 : 0.3)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .frame(height: 12)
                    .background(
                        LinearGradient(
                            colors: isOn ? [Color.cream, Color.statusActive] : [Color.cream, Color.black],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.statusActive, lineWidth: 0.5)
                    )
                    .cornerRadius(3)
            }
        }
    }
}
