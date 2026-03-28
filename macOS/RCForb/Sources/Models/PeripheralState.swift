import Foundation

// MARK: - Rotator State

class RotatorStateModel {
    var enabled = false
    var name = "Rotator"
    var bearing = 0
    var elevation = 0
    var moving = false
    var buttons: [String: Int] = [:]
    var buttonOrder: [String] = []

    func reset() {
        enabled = false; name = "Rotator"
        bearing = 0; elevation = 0; moving = false
        buttons.removeAll(); buttonOrder.removeAll()
    }

    @discardableResult
    func processCommand(_ command: String) -> Bool {
        guard command.hasPrefix("rotator::") else { return false }
        let rest = String(command.dropFirst("rotator::".count))

        if rest == "enabled" || rest.hasPrefix("enabled") {
            enabled = true
        } else if rest.hasPrefix("name::") {
            name = String(rest.dropFirst("name::".count))
        } else if rest.hasPrefix("bearing::") {
            bearing = Int(rest.dropFirst("bearing::".count)) ?? 0
        } else if rest.hasPrefix("elevation::") {
            elevation = Int(rest.dropFirst("elevation::".count)) ?? 0
        } else if rest == "started" {
            moving = true
        } else if rest == "stopped" {
            moving = false
        } else if rest.hasPrefix("button::") {
            let data = String(rest.dropFirst("button::".count))
            let key = CommandParser.getKey(data)
            let value = Int(CommandParser.getValue(data)) ?? 0
            if buttons[key] == nil { buttonOrder.append(key) }
            buttons[key] = value
        }
        return true
    }

    func toData() -> RotatorStateData {
        RotatorStateData(bearing: bearing, elevation: elevation, moving: moving,
                         buttons: buttons, buttonOrder: buttonOrder)
    }
}

// MARK: - Amp State

class AmpStateModel {
    var enabled = false
    var name = "Amp"
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

    func reset() {
        enabled = false; name = "Amp"
        buttons.removeAll(); buttonOrder.removeAll()
        dropdowns.removeAll(); dropdownLists.removeAll(); dropdownOrder.removeAll()
        sliders.removeAll(); sliderRanges.removeAll(); sliderOrder.removeAll()
        meters.removeAll(); meterOrder.removeAll()
    }

    @discardableResult
    func processCommand(_ command: String) -> Bool {
        guard command.hasPrefix("amp::") else { return false }
        let rest = String(command.dropFirst("amp::".count))

        if rest.hasPrefix("enabled") {
            enabled = true
        } else if rest.hasPrefix("name::") {
            name = String(rest.dropFirst("name::".count))
        } else if rest.hasPrefix("buttons::") {
            for n in rest.dropFirst("buttons::".count).components(separatedBy: ",") {
                let name = n.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty && buttons[name] == nil {
                    buttonOrder.append(name)
                    buttons[name] = 0
                }
            }
        } else if rest.hasPrefix("button::") {
            let data = String(rest.dropFirst("button::".count))
            let key = CommandParser.getKey(data)
            let value = Int(CommandParser.getValue(data)) ?? 0
            if buttons[key] == nil { buttonOrder.append(key) }
            buttons[key] = value
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
        } else if rest.hasPrefix("meter::") {
            let data = String(rest.dropFirst("meter::".count))
            let key = CommandParser.getKey(data)
            let value = CommandParser.getValue(data)
            if meters[key] == nil { meterOrder.append(key) }
            meters[key] = MeterData(value: Double(value) ?? 0, max: 100, unit: "")
        }
        return true
    }

    func toData() -> AmpStateData {
        AmpStateData(buttons: buttons, buttonOrder: buttonOrder,
                     dropdowns: dropdowns, dropdownLists: dropdownLists, dropdownOrder: dropdownOrder,
                     sliders: sliders, sliderRanges: sliderRanges, sliderOrder: sliderOrder,
                     meters: meters, meterOrder: meterOrder)
    }
}

// MARK: - Switch State

class SwitchStateModel {
    var enabled = false
    var name = "Switch"
    var buttons: [String: Int] = [:]
    var buttonOrder: [String] = []

    func reset() {
        enabled = false; name = "Switch"
        buttons.removeAll(); buttonOrder.removeAll()
    }

    @discardableResult
    func processCommand(_ command: String) -> Bool {
        guard command.hasPrefix("switch::") else { return false }
        let rest = String(command.dropFirst("switch::".count))

        if rest.hasPrefix("enabled") {
            enabled = true
        } else if rest.hasPrefix("name::") {
            name = String(rest.dropFirst("name::".count))
        } else if rest.hasPrefix("buttons::") {
            for n in rest.dropFirst("buttons::".count).components(separatedBy: ",") {
                let name = n.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty && buttons[name] == nil {
                    buttonOrder.append(name)
                    buttons[name] = 0
                }
            }
        } else if rest.hasPrefix("button::") {
            let data = String(rest.dropFirst("button::".count))
            let key = CommandParser.getKey(data)
            let value = Int(CommandParser.getValue(data)) ?? 0
            if buttons[key] == nil { buttonOrder.append(key) }
            buttons[key] = value
        }
        return true
    }

    func toData() -> SwitchStateData {
        SwitchStateData(buttons: buttons, buttonOrder: buttonOrder)
    }
}
