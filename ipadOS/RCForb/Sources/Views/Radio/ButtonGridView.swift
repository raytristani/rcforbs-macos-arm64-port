import SwiftUI

/// Reusable button grid matching Electron's ButtonGrid component
struct ButtonGridView: View {
    let buttons: [String: Int]
    let order: [String]
    let onToggle: (String, Int) -> Void

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 56), spacing: 2)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 2) {
            ForEach(order, id: \.self) { name in
                if !name.isEmpty {
                    let isOn = (buttons[name] ?? 0) != 0
                    MetalButton(
                        title: name,
                        isOn: isOn,
                        width: 54,
                        height: 20,
                        fontSize: name.count > 6 ? 8 : 10
                    ) {
                        onToggle(name, isOn ? 0 : 1)
                    }
                }
            }
        }
    }
}
