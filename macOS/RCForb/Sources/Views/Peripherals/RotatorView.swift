import SwiftUI

struct RotatorView: View {
    @EnvironmentObject var cm: ConnectionManager
    @State private var targetBearing = ""

    private var rotator: RotatorStateData? { cm.rotatorStateData }

    var body: some View {
        guard let rotator else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text("Rotator")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.cream)

                HStack(spacing: 24) {
                    // Compass dial
                    compassDial(bearing: rotator.bearing)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Bearing:")
                                .font(.system(size: 13))
                                .foregroundColor(Color.cream)
                            Text("\(rotator.bearing)\u{00B0}")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.cream)
                        }
                        HStack {
                            Text("Elevation:")
                                .font(.system(size: 13))
                                .foregroundColor(Color.cream)
                            Text("\(rotator.elevation)\u{00B0}")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.cream)
                        }
                        Text(rotator.moving ? "Moving..." : "Stopped")
                            .font(.system(size: 11))
                            .foregroundColor(Color.labelSubtle)

                        HStack(spacing: 8) {
                            TextField("Deg", text: $targetBearing)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundColor(Color.cream)
                                .frame(width: 64)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.inputBg)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.btnBorder, lineWidth: 1))
                                .cornerRadius(8)
                                .onSubmit { handleGo() }

                            MetalButton(title: "Go", isOn: false, style: .dark) {
                                handleGo()
                            }
                        }
                    }
                }
            }
            .padding(16)
        )
    }

    private func compassDial(bearing: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.inputBg)
                .frame(width: 120, height: 120)
                .overlay(Circle().stroke(Color.btnBorder, lineWidth: 2))

            ForEach(["N", "E", "S", "W"], id: \.self) { dir in
                let i = ["N", "E", "S", "W"].firstIndex(of: dir)!
                let angle = Double(i) * 90 - 90
                let rad = angle * .pi / 180
                Text(dir)
                    .font(.system(size: 10))
                    .foregroundColor(Color.labelSubtle)
                    .offset(x: 42 * cos(rad), y: 42 * sin(rad))
            }

            // Needle
            Rectangle()
                .fill(Color.ledRed)
                .frame(width: 2, height: 45)
                .offset(y: -22.5)
                .rotationEffect(.degrees(Double(bearing)))

            Circle()
                .fill(Color.cream)
                .frame(width: 8, height: 8)
        }
    }

    private func handleGo() {
        if let deg = Int(targetBearing), deg >= 0, deg < 360 {
            cm.sendCommand(CommandParser.rotatorBearing(String(deg)))
            cm.sendCommand(CommandParser.rotatorStart())
        }
    }
}
