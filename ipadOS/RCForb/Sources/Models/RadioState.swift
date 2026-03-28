import Foundation

/// Radio state model ported from radio-state.ts
/// Processes incoming `radio::*` commands and maintains ordered state.
class RadioState {
    var frequencyA: Int = 0
    var frequencyB: Int = 0
    var smeterA: Double = 0
    var smeterALabel: String = ""
    var smeterB: Double = 0
    var smeterBLabel: String = ""
    var buttons: [String: Int] = [:]
    var buttonOrder: [String] = []
    var dropdowns: [String: String] = [:]
    var dropdownLists: [String: [String]] = [:]
    var dropdownOrder: [String] = []
    var sliders: [String: Double] = [:]
    var sliderRanges: [String: SliderRange] = [:]
    var sliderOrder: [String] = []
    var meters: [String: MeterData] = [:]
    var meterOrder: [String] = []
    var messages: [String: String] = [:]
    var messageOrder: [String] = []
    var statuses: [String: Bool] = [:]
    var statusOrder: [String] = []
    var txEnabled: Bool = false
    var isStateReady: Bool = false
    var radioName: String = ""
    var radioDriver: String = ""

    func reset() {
        frequencyA = 0; frequencyB = 0
        smeterA = 0; smeterALabel = ""
        smeterB = 0; smeterBLabel = ""
        buttons.removeAll(); buttonOrder.removeAll()
        dropdowns.removeAll(); dropdownLists.removeAll(); dropdownOrder.removeAll()
        sliders.removeAll(); sliderRanges.removeAll(); sliderOrder.removeAll()
        meters.removeAll(); meterOrder.removeAll()
        messages.removeAll(); messageOrder.removeAll()
        statuses.removeAll(); statusOrder.removeAll()
        txEnabled = false; isStateReady = false
        radioName = ""; radioDriver = ""
    }

    @discardableResult
    func processCommand(_ command: String) -> Bool {
        if !isStateReady && (command.hasPrefix("chat::") || command == "radio::state-posted") {
            isStateReady = true
        }

        guard command.hasPrefix("radio::") else { return false }
        let rest = String(command.dropFirst("radio::".count))

        if rest.hasPrefix("radio::") {
            radioName = String(rest.dropFirst("radio::".count))
        } else if rest.hasPrefix("driver::") {
            radioDriver = String(rest.dropFirst("driver::".count))
        } else if rest.hasPrefix("frequency::") {
            frequencyA = Int(rest.dropFirst("frequency::".count)) ?? 0
        } else if rest.hasPrefix("frequencyb::") || rest.hasPrefix("frequencyB::") {
            let prefix = rest.hasPrefix("frequencyB::") ? "frequencyB::" : "frequencyb::"
            frequencyB = Int(rest.dropFirst(prefix.count)) ?? 0
        } else if rest.hasPrefix("smeter::") {
            let val = String(rest.dropFirst("smeter::".count))
            let parsed = parseSMeter(val)
            smeterA = parsed.value
            smeterALabel = parsed.label
        } else if rest.hasPrefix("smeterb::") || rest.hasPrefix("smeterB::") {
            let prefix = rest.hasPrefix("smeterB::") ? "smeterB::" : "smeterb::"
            let val = String(rest.dropFirst(prefix.count))
            let parsed = parseSMeter(val)
            smeterB = parsed.value
            smeterBLabel = parsed.label
        } else if rest.hasPrefix("button::") {
            let data = String(rest.dropFirst("button::".count))
            let key = CommandParser.getKey(data)
            let value = Int(CommandParser.getValue(data)) ?? 0
            if buttons[key] == nil { buttonOrder.append(key) }
            buttons[key] = value
        } else if rest.hasPrefix("buttons::") {
            let names = rest.dropFirst("buttons::".count).components(separatedBy: ",")
            for name in names {
                let n = name.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty && buttons[n] == nil {
                    buttonOrder.append(n)
                    buttons[n] = 0
                }
            }
        } else if rest.hasPrefix("dropdowns::") {
            let names = rest.dropFirst("dropdowns::".count).components(separatedBy: ",")
            for name in names {
                let n = name.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty && dropdowns[n] == nil {
                    dropdownOrder.append(n)
                    dropdowns[n] = ""
                }
            }
        } else if rest.hasPrefix("dropdown::") {
            let data = String(rest.dropFirst("dropdown::".count))
            let key = CommandParser.getKey(data)
            let value = CommandParser.getValue(data)
            if dropdowns[key] == nil { dropdownOrder.append(key) }
            dropdowns[key] = value
        } else if rest.hasPrefix("list::") {
            let data = String(rest.dropFirst("list::".count))
            let key = CommandParser.getKey(data)
            let value = CommandParser.getValue(data)
            dropdownLists[key] = value.components(separatedBy: ",")
        } else if rest.hasPrefix("sliders::") {
            let names = rest.dropFirst("sliders::".count).components(separatedBy: ",")
            for name in names {
                let n = name.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty && sliders[n] == nil {
                    sliderOrder.append(n)
                    sliders[n] = 0
                }
            }
        } else if rest.hasPrefix("slider::") {
            let data = String(rest.dropFirst("slider::".count))
            let key = CommandParser.getKey(data)
            let value = Double(CommandParser.getValue(data)) ?? 0
            if sliders[key] == nil { sliderOrder.append(key) }
            sliders[key] = value
        } else if rest.hasPrefix("range::") {
            let data = String(rest.dropFirst("range::".count))
            let key = CommandParser.getKey(data)
            let value = CommandParser.getValue(data)
            let parts = value.components(separatedBy: ",")
            sliderRanges[key] = SliderRange(
                min: Double(parts[safe: 0] ?? "") ?? 0,
                max: Double(parts[safe: 1] ?? "") ?? 100,
                step: Double(parts[safe: 2] ?? "") ?? 1,
                displayOffset: parts[safe: 3] ?? ""
            )
        } else if rest.hasPrefix("meters::") {
            let names = rest.dropFirst("meters::".count).components(separatedBy: ",")
            for name in names {
                let n = name.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty && meters[n] == nil {
                    meterOrder.append(n)
                    meters[n] = MeterData(value: 0, max: 100, unit: "")
                }
            }
        } else if rest.hasPrefix("meter::") {
            let data = String(rest.dropFirst("meter::".count))
            let key = CommandParser.getKey(data)
            let value = CommandParser.getValue(data)
            if meters[key] == nil { meterOrder.append(key) }
            meters[key] = MeterData(value: Double(value) ?? 0, max: 100, unit: "")
        } else if rest.hasPrefix("messages::") {
            let names = rest.dropFirst("messages::".count).components(separatedBy: ",")
            for name in names {
                let n = name.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty && self.messages[n] == nil {
                    messageOrder.append(n)
                    self.messages[n] = ""
                }
            }
        } else if rest.hasPrefix("message::") {
            let data = String(rest.dropFirst("message::".count))
            let key = CommandParser.getKey(data)
            let value = CommandParser.getValue(data)
            if self.messages[key] == nil { messageOrder.append(key) }
            self.messages[key] = value
        } else if rest.hasPrefix("statuses::") {
            let names = rest.dropFirst("statuses::".count).components(separatedBy: ",")
            for name in names {
                let n = name.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty && statuses[n] == nil {
                    statusOrder.append(n)
                    statuses[n] = false
                }
            }
        } else if rest.hasPrefix("status::") {
            let data = String(rest.dropFirst("status::".count))
            let key = CommandParser.getKey(data)
            let value = CommandParser.getValue(data)
            if statuses[key] == nil { statusOrder.append(key) }
            statuses[key] = value == "1" || value.lowercased() == "true"
        } else if rest == "state-posted" {
            isStateReady = true
        } else if rest.hasPrefix("tx-enabled") {
            txEnabled = true
        } else if rest.hasPrefix("tx-disabled") {
            txEnabled = false
        }

        return true
    }

    private func parseSMeter(_ val: String) -> (value: Double, label: String) {
        if val.contains(",") {
            let parts = val.components(separatedBy: ",")
            let label = parts[safe: 0] ?? ""
            let raw = Double(parts[safe: 1] ?? "") ?? 0
            let maxVal = Double(parts[safe: 2] ?? "") ?? 255
            let value = (raw / maxVal) * 19
            return (value, label)
        }
        let parts = val.components(separatedBy: "::")
        let value = Double(parts[safe: 0] ?? "") ?? 0
        let label = parts.count > 1 ? parts[1] : formatSMeter(value)
        return (value, label)
    }

    private func formatSMeter(_ value: Double) -> String {
        if value <= 0 { return "" }
        if value <= 9 { return "S\(Int(value.rounded()))" }
        let over = Int(((value - 9) * 6).rounded())
        return "S9+\(over)"
    }

    func toData() -> RadioStateData {
        RadioStateData(
            frequencyA: frequencyA,
            frequencyB: frequencyB,
            buttons: buttons,
            buttonOrder: buttonOrder,
            dropdowns: dropdowns,
            dropdownLists: dropdownLists,
            dropdownOrder: dropdownOrder,
            sliders: sliders,
            sliderRanges: sliderRanges,
            sliderOrder: sliderOrder,
            meters: meters,
            meterOrder: meterOrder,
            messages: messages,
            messageOrder: messageOrder,
            statuses: statuses,
            statusOrder: statusOrder,
            smeterA: smeterA,
            smeterALabel: smeterALabel,
            smeterB: smeterB,
            smeterBLabel: smeterBLabel,
            txEnabled: txEnabled
        )
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
