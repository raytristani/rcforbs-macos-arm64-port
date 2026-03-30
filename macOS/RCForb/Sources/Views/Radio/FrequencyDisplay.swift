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
                .help("Click to set VFO \(vfo) frequency")
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
                .textFieldStyle(.plain)
                .font(.custom(FontRegistration.digital7Mono, size: 16))
                .foregroundColor(Color.cream)
                .padding(8)
                .background(Color(hex: "#2a2a22"))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#666654"), lineWidth: 1))
                .cornerRadius(8)
                .onSubmit { submitFreq() }

            HStack {
                Spacer()
                Button("Cancel") { showDialog = false }
                    .buttonStyle(.plain)
                    .foregroundColor(Color.cream)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(Color.metalDarkTop)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.metalDarkBorder, lineWidth: 1))
                    .cornerRadius(8)

                Button("Set") { submitFreq() }
                    .buttonStyle(.plain)
                    .foregroundColor(Color.textDark)
                    .fontWeight(.bold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(Color.creamDark)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cream, lineWidth: 1))
                    .cornerRadius(8)
            }
        }
        .padding(20)
        .frame(minWidth: 280)
        .background(Color.panelBgBottom)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#666654"), lineWidth: 1))
        .cornerRadius(10)
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
