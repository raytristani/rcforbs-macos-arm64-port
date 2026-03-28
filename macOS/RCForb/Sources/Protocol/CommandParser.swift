import Foundation

enum CommandParser {
    static func splitCommand(_ command: String) -> [String] {
        command.components(separatedBy: "::")
    }

    static func getKey(_ data: String) -> String {
        if let idx = data.range(of: "::") {
            return String(data[data.startIndex..<idx.lowerBound])
        }
        return data
    }

    static func getValue(_ data: String) -> String {
        let parts = splitCommand(data)
        return parts.count > 1 ? parts[1] : ""
    }

    static func getValueAt(_ index: Int, _ data: String) -> String {
        let parts = splitCommand(data)
        return index < parts.count ? parts[index] : ""
    }

    // Command builders
    static func loginCmd(_ user: String, _ passwordMD5: String) -> String {
        "login \(user) \(passwordMD5)"
    }

    static func setProtocolRCS() -> String { "set protocol rcs" }
    static func requestRadioState() -> String { "radio::request-state" }

    static func setFrequencyA(_ hz: String) -> String { "radio::frequency::\(hz)" }
    static func setFrequencyB(_ hz: String) -> String { "radio::frequencyb::\(hz)" }
    static func setButton(_ name: String, _ value: String) -> String { "radio::button::\(name)::\(value)" }
    static func setDropdown(_ name: String, _ value: String) -> String { "radio::dropdown::\(name)::\(value)" }
    static func setSlider(_ name: String, _ value: String) -> String { "radio::slider::\(name)::\(value)" }
    static func setMessage(_ name: String, _ value: String) -> String { "radio::message::\(name)::\(value)" }
    static func chatMessage(_ text: String) -> String { "post::chat::\(text)" }
    static func heartbeatCmd() -> String { "post::heartbeat::\(Int(Date().timeIntervalSince1970 * 1000))" }
    static func checkCanTune() -> String { "post::check::cantune" }

    static func rotatorBearing(_ value: String) -> String { "rotator::bearing::\(value)" }
    static func rotatorElevation(_ value: String) -> String { "rotator::elevation::\(value)" }
    static func rotatorStart() -> String { "rotator::start" }
    static func rotatorStop() -> String { "rotator::stop" }
    static func ampButton(_ name: String, _ value: String) -> String { "amp::button::\(name)::\(value)" }
    static func switchButton(_ name: String, _ value: String) -> String { "switch::button::\(name)::\(value)" }
}
