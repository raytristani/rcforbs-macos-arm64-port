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
    @State private var micTestResult: String?
    @State private var freqDialogVFO: String = "A"
    @State private var isFavorite = false

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
        .background(Color.background)
        .onAppear {
            if let station = cm.connectedStation {
                isFavorite = FavoritesStore.isFavorite(station.serverId)
            }
        }
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

            MetalButton(title: isFavorite ? "Saved Station" : "Save Station", isOn: isFavorite, fontSize: 12) {
                if let station = cm.connectedStation {
                    let fav = FavoriteStation(
                        serverId: station.serverId,
                        serverName: station.serverName,
                        radioModel: station.radioModel,
                        description: station.description,
                        host: station.host,
                        port: station.port,
                        voipPort: station.voipPort,
                        isV7: station.isV7
                    )
                    if isFavorite {
                        FavoritesStore.removeFavorite(station.serverId)
                    } else {
                        FavoritesStore.addFavorite(fav)
                    }
                    isFavorite.toggle()
                }
            }

            Text("Vol").font(.system(size: 11)).foregroundColor(.mutedForeground)
            Slider(value: $volume, in: 0...1, step: 0.05)
                .frame(width: 60)
                .tint(Color.cream)
                .onChange(of: volume) {
                    cm.audioBridge.setVolume(Float(volume))
                }

            Spacer()

            // Status LED
            Circle()
                .fill(si?.radioOpen == true ? Color(hex: "#44cc44") : si?.radioInUse == true ? Color(hex: "#cc4444") : .mutedForeground.opacity(0.6))
                .frame(width: 6, height: 6)
                .shadow(color: si?.radioOpen == true ? Color(hex: "#44cc44") : .clear, radius: 2)

            Text(si?.radioOpen == true ? "Open" : si?.radioInUse == true ? "In Use" : "Closed")
                .font(.system(size: 11)).foregroundColor(.mutedForeground)

            Text(si?.serverTime ?? "")
                .font(.system(size: 11)).foregroundColor(.mutedForeground.opacity(0.6))

            MetalButton(title: "Chat", isOn: showChat, fontSize: 12) {
                showChat.toggle()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.panelBgBottom)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.border), alignment: .bottom)
    }

    private var requestTuneButton: some View {
        Button {
            cm.sendCommand(CommandParser.chatMessage("May I tune the remote?"))
            showChat = true
        } label: {
            VStack(spacing: 2) {
                Text("Request Tune")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.cream)
                if si?.radioOpen == true {
                    Text("(Again)")
                        .font(.system(size: 9))
                        .foregroundColor(.mutedForeground)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 120, height: 60)
        .background(Color.metalDarkTop)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.metalDarkBorder, lineWidth: 2)
        )
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
    }

    private var micTestButton: some View {
        Button {
            micTestResult = "..."
            cm.audioBridge.micTest { success in
                micTestResult = success ? "OK" : "FAIL"
            }
        } label: {
            Text(micTestResult == "..." ? "Testing..." : micTestResult != nil ? "Mic: \(micTestResult!)" : "Mic Test")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.cream)
        }
        .buttonStyle(.plain)
        .frame(width: 90, height: 60)
        .background(micTestResult == nil ? Color.metalDarkTop : micTestResult == "OK" ? Color.ledGreen.opacity(0.3) : Color.ledRed.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.metalDarkBorder, lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private var pttArea: some View {
        HStack(spacing: 8) {
            requestTuneButton
            micTestButton

            VStack {
                Text("PUSH TO TALK")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isPTT ? .white : Color.cream)
                    .tracking(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(isPTT ? Color(hex: "#CC3322") : Color(hex: "#7A2222"))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPTT ? Color(hex: "#ff8866") : Color(hex: "#aa4433"), lineWidth: 2)
            )
            .cornerRadius(10)
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
        .background(Color(hex: "#E8D888"))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#999870"), lineWidth: 2))
        .cornerRadius(10)
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
            ScrollView {
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
                                    MetalButton(title: name, isOn: on, width: 54, height: 22, fontSize: name.count > 5 ? 9 : 11) {
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

                    // Center: VFO Knobs — fill space between button columns, centered
                    HStack(alignment: .bottom, spacing: 24) {
                        VStack(spacing: 0) {
                            VFOKnobView(size: 202, vfo: "A", step: vfoStep, frequency: rs.frequencyA) { hz in
                                cm.sendCommand(CommandParser.setFrequencyA(String(hz)))
                            }
                            Text("VFO A")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.mutedForeground)
                                .padding(.top, 4)
                        }

                        if rs.frequencyB > 0 {
                            VStack(spacing: 0) {
                                VFOKnobView(size: 144, vfo: "B", step: vfoStep, frequency: rs.frequencyB) { hz in
                                    cm.sendCommand(CommandParser.setFrequencyB(String(hz)))
                                }
                                Text("VFO B")
                                    .font(.system(size: 12))
                                    .foregroundColor(.mutedForeground)
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
                                    MetalButton(title: name, isOn: on, width: 54, height: 22, fontSize: name.count > 5 ? 9 : 11) {
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
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(rs.sliderOrder, id: \.self) { name in
                    if !name.isEmpty {
                        let v = rs.sliders[name] ?? 0
                        let raw = rs.sliderRanges[name] ?? SliderRange(min: 0, max: 100, step: 1, displayOffset: "")
                        let rMin = raw.min
                        let rMax = raw.max > raw.min ? raw.max : raw.min + 100
                        let rStep = raw.step > 0 ? raw.step : 1
                        HStack(spacing: 2) {
                            Text(verbatim: "\(Int(v.rounded()))")
                                .font(.system(size: 9))
                                .foregroundColor(Color.cream)
                                .frame(width: 28)
                                .frame(maxHeight: .infinity)
                                .background(Color.metalDarkTop)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.metalDarkBorder, lineWidth: 1))
                                .cornerRadius(6)

                            VStack(alignment: .leading, spacing: 0) {
                                Text(name)
                                    .font(.system(size: 9))
                                    .foregroundColor(.mutedForeground)
                                    .lineLimit(1)
                                RadioSlider(name: name, serverValue: v, min: rMin, max: rMax, step: rStep) { val in
                                    cm.sendCommand(CommandParser.setSlider(name, String(Int(val))))
                                }
                                .frame(height: 16)
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
            HStack(spacing: 12) {
                ForEach(rs.messageOrder, id: \.self) { name in
                    if !name.isEmpty {
                        VStack(spacing: 0) {
                            Text(rs.messages[name] ?? "")
                                .font(.system(size: 11))
                                .foregroundColor(Color.cream)
                                .frame(minWidth: 60)
                                .frame(height: 20)
                                .padding(.horizontal, 6)
                                .background(Color.metalDarkTop)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.metalDarkBorder, lineWidth: 1))
                                .cornerRadius(8)
                            Text(name)
                                .font(.system(size: 9))
                                .foregroundColor(.mutedForeground)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Chat Sidebar

    private var chatSidebar: some View {
        ChatView()
            .frame(width: 288)
            .background(Color.background)
            .overlay(Rectangle().frame(width: 1).foregroundColor(Color.panelBorder), alignment: .leading)
    }
}
