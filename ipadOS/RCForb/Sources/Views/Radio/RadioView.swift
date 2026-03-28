import SwiftUI

private let VFO_STEPS: [(label: String, value: Int)] = [
    (".01", 10), (".10", 100), ("1.0", 1000), ("5.0", 5000), ("10", 10000),
]

private let btnDesc: [String: String] = [
    "TXd": "Transmit", "Tune": "Antenna Tune", "ATU": "Auto Tuner",
    "NB": "Noise Blanker", "NR": "Noise Reduction", "ANF": "Auto Notch",
    "MNF": "Manual Notch", "PB Clr": "Passband Clear", "Comp": "Compression",
    "Tone": "Sub Tone", "TSQL": "Tone Squelch", "Test": "Test Mode",
    "M-Tune": "Memory Tune", "QSK": "Full Break-in", "XFC": "Transceive",
    "Data": "Data Mode", "VFO B": "Select VFO B", "VFO A": "Select VFO A",
    "A/B": "Swap VFO", "A=B": "Equalize VFO", "Split": "Split Mode",
    "TX": "Transmit", "RIT": "RX Increment", "XIT": "TX Increment",
    "MOX": "Manual TX", "AGC": "Auto Gain", "VOX": "Voice Operate",
    "BK": "Break-in", "Lock": "Dial Lock", "IPO": "Intercept",
]

struct RadioView: View {
    @EnvironmentObject var cm: ConnectionManager
    @State private var vfoStep = 100
    @State private var showChat = false
    @State private var isPTT = false
    @State private var volume: Double = 0.5
    @State private var showFreqDialog = false
    @State private var freqDialogVFO: String = "A"

    private var rs: RadioStateData? { cm.radioStateData }
    private var si: ServerInfoData? { cm.serverInfoData }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            HStack(spacing: 0) {
                mainContent
                if showChat {
                    chatSidebar
                }
            }
        }
        .background(Color(hex: "#33332a"))
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 8) {
            MetalButton(title: "Disconnect", isOn: false, fontSize: 12) {
                cm.disconnect()
            }
            MetalButton(title: "Reset", isOn: false, fontSize: 12) {
                cm.sliderOverrides.removeAll()
            }

            Text("Vol").font(.system(size: 11)).foregroundColor(Color(hex: "#777777"))
            Slider(value: $volume, in: 0...1, step: 0.05)
                .frame(width: 80)
                .tint(Color.cream)
                .onChange(of: volume) {
                    cm.audioBridge.setVolume(Float(volume))
                }

            Spacer()

            // Status LED
            Circle()
                .fill(si?.radioOpen == true ? Color(hex: "#44cc44") : si?.radioInUse == true ? Color(hex: "#cc4444") : Color(hex: "#666666"))
                .frame(width: 8, height: 8)
                .shadow(color: si?.radioOpen == true ? Color(hex: "#44cc44") : .clear, radius: 2)

            Text(si?.radioOpen == true ? "Open" : si?.radioInUse == true ? "In Use" : "Closed")
                .font(.system(size: 11)).foregroundColor(Color(hex: "#888888"))

            Text(si?.serverTime ?? "")
                .font(.system(size: 11)).foregroundColor(Color(hex: "#666666"))

            MetalButton(title: "Chat", isOn: showChat, fontSize: 12) {
                showChat.toggle()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            LinearGradient(colors: [Color.panelBgTop, Color.panelBgBottom], startPoint: .top, endPoint: .bottom)
        )
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#555544")), alignment: .bottom)
    }

    private var pttArea: some View {
        VStack {
            Text("PUSH TO TALK")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isPTT ? .white : Color.cream)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            LinearGradient(
                colors: isPTT ? [Color(hex: "#ff6644"), Color(hex: "#cc3322")] : [Color(hex: "#cc4433"), Color(hex: "#882222")],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isPTT ? Color(hex: "#ff8866") : Color(hex: "#aa4433"), lineWidth: 2)
        )
        .cornerRadius(8)
        .shadow(color: isPTT ? Color(hex: "#ff4422").opacity(0.5) : .black.opacity(0.3), radius: isPTT ? 12 : 6, y: 2)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPTT { isPTT = true; cm.sendPTT(true) }
                }
                .onEnded { _ in
                    isPTT = false; cm.sendPTT(false)
                }
        )
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let rs {
                    lcdHero(rs)
                    mainControlsGrid(rs)
                    if !rs.sliderOrder.isEmpty { slidersPanel(rs) }
                    if !rs.messageOrder.isEmpty { messagesPanel(rs) }
                    pttArea
                } else {
                    Spacer()
                    Text("Loading...")
                        .foregroundColor(Color.cream)
                    Spacer()
                }
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - LCD Hero

    private func lcdHero(_ rs: RadioStateData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TOT: \(si?.tot ?? 180)s")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#887744"))
                Spacer()
                Text(rs.smeterALabel)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#887744"))
            }
            .padding(.bottom, 2)

            SMeterView(value: rs.smeterA, label: rs.smeterALabel)

            HStack(alignment: .bottom, spacing: 16) {
                FrequencyDisplay(frequency: rs.frequencyA, vfo: "A", large: true, onSet: { hz in
                    cm.sendCommand(CommandParser.setFrequencyA(String(hz)))
                })
                if rs.frequencyB > 0 {
                    FrequencyDisplay(frequency: rs.frequencyB, vfo: "B", large: false, onSet: { hz in
                        cm.sendCommand(CommandParser.setFrequencyB(String(hz)))
                    })
                    .opacity(0.6)
                    .padding(.bottom, 2)
                }
                if !cm.connectedStationName.isEmpty {
                    MarqueeText(
                        text: cm.connectedStationName,
                        font: .custom(FontRegistration.digital7Mono, size: 24),
                        color: Color(hex: "#553300")
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .padding(.leading, 24)
                    .padding(.bottom, 2)
                }
            }
            .padding(.top, 4)

            if !rs.statusOrder.isEmpty {
                StatusPillsView(statuses: rs.statuses, order: rs.statusOrder)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            LinearGradient(colors: [Color(hex: "#e8d888"), Color(hex: "#f0e4a0")], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#999870"), lineWidth: 2))
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
    }

    // MARK: - Main Controls Grid

    private func mainControlsGrid(_ rs: RadioStateData) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Left: Mode & Filters
            modeFiltersPanel(rs)
                .frame(width: 160)

            // Center: Controls
            controlsPanel(rs)
        }
    }

    private func modeFiltersPanel(_ rs: RadioStateData) -> some View {
        PanelView(title: "Mode & Filters") {
            VStack(spacing: 2) {
                ForEach(rs.dropdownOrder, id: \.self) { name in
                    if !name.isEmpty {
                        let value = rs.dropdowns[name] ?? ""
                        let opts = rs.dropdownLists[name] ?? []
                        VStack(alignment: .leading, spacing: 0) {
                            Text(name)
                                .font(.system(size: 9))
                                .foregroundColor(Color.labelDim)
                                .lineSpacing(0)
                            MetalDropdown(value: value, options: opts) { selected in
                                cm.sendCommand(CommandParser.setDropdown(name, selected))
                            }
                        }
                    }
                }
            }
        }
    }

    private func controlsPanel(_ rs: RadioStateData) -> some View {
        PanelView(title: "Controls") {
            VStack(spacing: 6) {
                // Step selector
                HStack(spacing: 4) {
                    Text("STEP (kHz)")
                        .font(.system(size: 10))
                        .foregroundColor(Color.labelDim)
                    ForEach(VFO_STEPS, id: \.value) { step in
                        MetalButton(title: step.label, isOn: vfoStep == step.value, fontSize: 10, action: {
                            vfoStep = step.value
                        })
                    }
                }

                // Buttons + Knobs
                HStack(alignment: .center, spacing: 8) {
                    // Left buttons
                    VStack(alignment: .leading, spacing: 4) {
                        let half = (rs.buttonOrder.count + 1) / 2
                        ForEach(Array(rs.buttonOrder.prefix(half).enumerated()), id: \.offset) { _, name in
                            if !name.isEmpty {
                                let on = (rs.buttons[name] ?? 0) != 0
                                let desc = btnDesc[name] ?? ""
                                HStack(spacing: 4) {
                                    MetalButton(title: name, isOn: on, width: 54, height: 28, fontSize: name.count > 5 ? 9 : 11) {
                                        cm.sendCommand(CommandParser.setButton(name, on ? "0" : "1"))
                                    }
                                    Text(desc)
                                        .font(.system(size: 9))
                                        .foregroundColor(Color.labelMuted)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .frame(minWidth: 140)

                    // Center: VFO Knobs
                    HStack(alignment: .bottom, spacing: 24) {
                        VStack(spacing: 0) {
                            VFOKnobView(size: 180, vfo: "A", step: vfoStep, frequency: rs.frequencyA) { hz in
                                cm.sendCommand(CommandParser.setFrequencyA(String(hz)))
                            }
                            Text("VFO A")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#aaaaaa"))
                                .padding(.top, 4)
                        }

                        if rs.frequencyB > 0 {
                            VStack(spacing: 0) {
                                VFOKnobView(size: 130, vfo: "B", step: vfoStep, frequency: rs.frequencyB) { hz in
                                    cm.sendCommand(CommandParser.setFrequencyB(String(hz)))
                                }
                                Text("VFO B")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#888888"))
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    // Right buttons
                    VStack(alignment: .trailing, spacing: 4) {
                        let half = (rs.buttonOrder.count + 1) / 2
                        ForEach(Array(rs.buttonOrder.dropFirst(half).enumerated()), id: \.offset) { _, name in
                            if !name.isEmpty {
                                let on = (rs.buttons[name] ?? 0) != 0
                                let desc = btnDesc[name] ?? ""
                                HStack(spacing: 4) {
                                    Text(desc)
                                        .font(.system(size: 9))
                                        .foregroundColor(Color.labelMuted)
                                        .lineLimit(1)
                                    MetalButton(title: name, isOn: on, width: 54, height: 28, fontSize: name.count > 5 ? 9 : 11) {
                                        cm.sendCommand(CommandParser.setButton(name, on ? "0" : "1"))
                                    }
                                }
                            }
                        }
                    }
                    .frame(minWidth: 140)
                }
            }
        }
    }

    // MARK: - Sliders

    private func slidersPanel(_ rs: RadioStateData) -> some View {
        PanelView(title: "Adjustments") {
            let columns = [GridItem(.adaptive(minimum: 180), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(rs.sliderOrder, id: \.self) { name in
                    if !name.isEmpty {
                        let v = rs.sliders[name] ?? 0
                        let raw = rs.sliderRanges[name] ?? SliderRange(min: 0, max: 100, step: 1, displayOffset: "")
                        let rMin = raw.min
                        let rMax = raw.max > raw.min ? raw.max : raw.min + 100
                        let rStep = raw.step > 0 ? raw.step : 1
                        HStack(spacing: 4) {
                            Text(verbatim: "\(Int(v.rounded()))")
                                .font(.system(size: 10))
                                .foregroundColor(Color.cream)
                                .frame(width: 34, height: 20)
                                .background(
                                    LinearGradient(colors: [Color.metalDarkTop, Color.metalDarkBottom], startPoint: .top, endPoint: .bottom)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.metalDarkBorder, lineWidth: 1))
                                .cornerRadius(3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(hex: "#999999"))
                                    .lineLimit(1)
                                RadioSlider(name: name, serverValue: v, min: rMin, max: rMax, step: rStep) { val in
                                    cm.sendCommand(CommandParser.setSlider(name, String(Int(val))))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Messages

    private func messagesPanel(_ rs: RadioStateData) -> some View {
        PanelView(title: "Status") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(rs.messageOrder, id: \.self) { name in
                        if !name.isEmpty {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(rs.messages[name] ?? "")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.cream)
                                    .frame(minWidth: 60, alignment: .trailing)
                                    .frame(height: 20)
                                    .padding(.horizontal, 6)
                                    .background(
                                        LinearGradient(colors: [Color.metalDarkTop, Color.metalDarkBottom], startPoint: .top, endPoint: .bottom)
                                    )
                                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.metalDarkBorder, lineWidth: 1))
                                    .cornerRadius(3)
                                Text(name)
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(hex: "#888888"))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Chat Sidebar

    private var chatSidebar: some View {
        ChatView()
            .frame(width: 320)
            .background(Color(hex: "#2a2a2a"))
            .overlay(Rectangle().frame(width: 1).foregroundColor(Color(hex: "#555555")), alignment: .leading)
    }
}
