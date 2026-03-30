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
                    .foregroundColor(isOn ? Color.textDark : Color.labelDim)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .frame(height: 12)
                    .background(isOn ? Color.statusActive : Color.metalDarkTop)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.statusActive, lineWidth: 0.5)
                    )
                    .cornerRadius(6)
            }
        }
    }
}
