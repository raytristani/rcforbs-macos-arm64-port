import SwiftUI

struct AmpView: View {
    @EnvironmentObject var cm: ConnectionManager
    private var amp: AmpStateData? { cm.ampStateData }

    var body: some View {
        guard let amp, !amp.buttonOrder.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text("Amplifier")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.cream)

                ButtonGridView(buttons: amp.buttons, order: amp.buttonOrder) { name, value in
                    cm.sendCommand(CommandParser.ampButton(name, String(value)))
                }
            }
            .padding(16)
        )
    }
}
