import SwiftUI

/// Reusable panel container matching the Electron panelStyle
struct PanelView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.labelDim)
                .textCase(.uppercase)
                .tracking(1)

            content()
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.panelBgTop, Color.panelBgBottom], startPoint: .top, endPoint: .bottom)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.panelBorder, lineWidth: 1)
        )
        .cornerRadius(4)
    }
}
