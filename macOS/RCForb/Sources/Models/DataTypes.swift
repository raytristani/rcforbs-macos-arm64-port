import Foundation

// MARK: - Connection State

enum ConnectionState: String {
    case disconnected
    case authenticating
    case authenticated
    case connecting
    case connected
    case failed
}

// MARK: - Remote Station

struct RemoteStation: Identifiable, Equatable {
    var id: String { serverId }
    let serverId: String
    let serverName: String
    let description: String
    let host: String
    let port: Int
    let voipPort: Int
    let online: Bool
    var radioInUse: Bool
    var radioOpen: Bool
    let serverVersion: String
    let radioModel: String
    let country: String
    let gridSquare: String
    let latitude: Double
    let longitude: Double
    let userCount: Int
    let maxUsers: Int
    let isV7: Bool
}

// MARK: - Radio State

struct RadioStateData {
    var frequencyA: Int = 0
    var frequencyB: Int = 0
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
    var smeterA: Double = 0
    var smeterALabel: String = ""
    var smeterB: Double = 0
    var smeterBLabel: String = ""
    var txEnabled: Bool = false
}

struct SliderRange {
    let min: Double
    let max: Double
    let step: Double
    let displayOffset: String
}

struct MeterData {
    var value: Double
    var max: Double
    var unit: String
}

// MARK: - Server Info

struct ServerInfoData {
    var serverId: String = ""
    var serverVersion: String = ""
    var serverUptime: String = ""
    var serverTime: String = ""
    var radioName: String = ""
    var radioDriver: String = ""
    var radioOpen: Bool = false
    var radioInUse: Bool = false
    var radioInUseBy: String = ""
    var tot: Int = 180
}

// MARK: - Peripheral State

struct RotatorStateData {
    var bearing: Int = 0
    var elevation: Int = 0
    var moving: Bool = false
    var buttons: [String: Int] = [:]
    var buttonOrder: [String] = []
}

struct AmpStateData {
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
}

struct SwitchStateData {
    var buttons: [String: Int] = [:]
    var buttonOrder: [String] = []
}

// MARK: - Chat

struct ChatMessage: Identifiable {
    let id = UUID()
    let user: String
    let text: String
    let timestamp: Date
    let isSystem: Bool
}

// MARK: - Auth

struct AuthResult {
    let success: Bool
    let message: String
    var apiKey: String?
}

struct SavedCredentials {
    let user: String
    let password: String
}
