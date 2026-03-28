import SwiftUI

struct SwitchView: View {
    @EnvironmentObject var cm: ConnectionManager
    private var sw: SwitchStateData? { cm.switchStateData }

    var body: some View {
        guard let sw, !sw.buttonOrder.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text("Antenna Switch")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.cream)

                ButtonGridView(buttons: sw.buttons, order: sw.buttonOrder) { name, value in
                    cm.sendCommand(CommandParser.switchButton(name, String(value)))
                }
            }
            .padding(16)
        )
    }
}
