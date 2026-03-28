import SwiftUI

struct FrequencyDisplay: View {
    let frequency: Int
    let vfo: String
    let large: Bool
    let onSet: (Int) -> Void

    @State private var showDialog = false
    @State private var freqInput = ""

    private var formatted: String {
        let s = String(format: "%09d", max(0, frequency))
        return "\(s.prefix(3)).\(s.dropFirst(3).prefix(3)).\(s.dropFirst(6).prefix(3))"
    }

    var body: some View {
        VStack {
            Text(formatted)
                .font(.custom(FontRegistration.digital7Mono, size: large ? 38 : 24))
                .foregroundColor(Color(hex: "#553300"))
                .shadow(color: Color(hex: "#aa6633"), radius: 2)
                .tracking(1)
                .lineLimit(1)
                .onTapGesture { showDialog = true }
        }
        .onAppear { FontRegistration.registerCustomFonts() }
        .sheet(isPresented: $showDialog) {
            freqDialog
        }
    }

    private var freqDialog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter frequency (MHz) for VFO \(vfo):")
                .font(.system(size: 13))
                .foregroundColor(Color.creamDark)

            TextField("Frequency", text: $freqInput)
                .textFieldStyle(.roundedBorder)
                .font(.custom(FontRegistration.digital7Mono, size: 16))
                .foregroundColor(Color.cream)
                .padding(8)
                .background(Color(hex: "#2a2a22"))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: "#666654"), lineWidth: 1))
                .cornerRadius(3)
                .onSubmit { submitFreq() }

            HStack {
                Spacer()
                Button("Cancel") { showDialog = false }
                    .buttonStyle(.plain)
                    .foregroundColor(Color(hex: "#dddcbb"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(LinearGradient(colors: [Color.metalDarkTop, Color.metalDarkBottom], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.metalDarkBorder, lineWidth: 1))
                    .cornerRadius(3)

                Button("Set") { submitFreq() }
                    .buttonStyle(.plain)
                    .foregroundColor(Color(hex: "#333111"))
                    .fontWeight(.bold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(LinearGradient(colors: [Color.cream, Color.creamDark], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.cream, lineWidth: 1))
                    .cornerRadius(3)
            }
        }
        .padding(20)
        .frame(minWidth: 280)
        .background(
            LinearGradient(colors: [Color.panelBgTop, Color.panelBgBottom], startPoint: .top, endPoint: .bottom)
        )
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#666654"), lineWidth: 1))
        .cornerRadius(6)
        .onAppear {
            freqInput = String(format: "%.6f", Double(frequency) / 1_000_000)
        }
    }

    private func submitFreq() {
        showDialog = false
        if let mhz = Double(freqInput), mhz > 0 {
            let hz = Int((mhz * 1_000_000).rounded())
            onSet(hz)
        }
    }
}
