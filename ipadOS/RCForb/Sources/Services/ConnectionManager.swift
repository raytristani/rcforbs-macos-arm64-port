import Foundation
import SwiftUI
import Combine

/// Central connection orchestrator ported from connection-manager.ts
@MainActor
class ConnectionManager: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var errorMessage: String?
    @Published var stations: [RemoteStation] = []
    @Published var radioStateData: RadioStateData?
    @Published var serverInfoData: ServerInfoData?
    @Published var chatMessages: [ChatMessage] = []
    @Published var rotatorStateData: RotatorStateData?
    @Published var ampStateData: AmpStateData?
    @Published var switchStateData: SwitchStateData?

    /// User-overridden slider values. Once a user drags a slider, the value is
    /// stored here and server updates for that slider are ignored until Reset.
    @Published var sliderOverrides: [String: Double] = [:]

    private var udpClient: UDPClient?
    private var tcpClient: TCPClientV7?
    private var ipexClient: IpExClient?
    private var username = ""
    private var passwordMD5 = ""

    let radioState = RadioState()
    let serverInfo = ServerInfoState()
    let rotatorState = RotatorStateModel()
    let ampState = AmpStateModel()
    let switchState = SwitchStateModel()
    let audioBridge = AudioBridge()

    private var stateUpdateTimer: DispatchSourceTimer?
    private var pendingStateUpdate = false
    private var commandCount = 0

    // MARK: - Authentication

    func authenticate(user: String, password: String) async -> AuthResult {
        connectionState = .authenticating
        username = user
        passwordMD5 = md5(password)

        let result = await AuthService.authenticate(user, password)
        if !result.success {
            connectionState = .failed
            return result
        }

        connectionState = .authenticated
        return result
    }

    // MARK: - Lobby

    func refreshLobby() async -> [RemoteStation] {
        let fetched = await LobbyService.fetchStations()
        let sorted = fetched
            .filter { $0.online }
            .sorted { $0.serverName.localizedCaseInsensitiveCompare($1.serverName) == .orderedAscending }
        stations = sorted
        return sorted
    }

    // MARK: - Connect to Station

    func connectToStation(_ station: RemoteStation) async {
        connectionState = .connecting
        commandCount = 0

        let host = station.host
        let port = station.port

        // Try V10 UDP first
        print("[Connection] Trying V10 UDP to \(host):\(port)...")
        let udpOk = await tryV10(host: host, port: port)

        if udpOk {
            print("[Connection] V10 UDP connected!")
            audioBridge.start(.opus)
            audioBridge.onEncodedAudio = { [weak self] data in self?.udpClient?.sendAudio(data) }
        } else {
            print("[Connection] V10 failed, trying V7 TCP...")
            let tcpOk = await tryV7(host: host, port: port, voipPort: station.voipPort)
            if !tcpOk {
                connectionState = .failed
                errorMessage = "Could not connect to \(station.serverName)"
                return
            }
            print("[Connection] V7 TCP connected!")
            audioBridge.start(.speex)
            audioBridge.onEncodedAudio = { [weak self] data in self?.tcpClient?.sendAudio(data) }
        }

        if let tcp = tcpClient {
            tcp.sendSessionLogin(username, passwordMD5)
        }

        let loginCmd = CommandParser.loginCmd(username, passwordMD5)
        sendCommand(loginCmd)
        sendCommand(CommandParser.setProtocolRCS())
        sendCommand(CommandParser.requestRadioState())

        connectionState = .connected

        Task {
            _ = await AuthService.trackOnline(username, passwordMD5, station.serverId)
        }
    }

    private func tryV10(host: String, port: Int) async -> Bool {
        let udp = UDPClient()
        udp.onAudio = { [weak self] data in self?.audioBridge.pushRXAudio(data) }
        udp.onCommand = { [weak self] text in
            Task { @MainActor in self?.dispatchCommand(text) }
        }
        udp.onControl = { [weak self] byte in
            Task { @MainActor in self?.handleControlByte(byte) }
        }
        udp.onDisconnected = { [weak self] in
            Task { @MainActor in
                if self?.udpClient === udp { self?.connectionState = .disconnected }
            }
        }

        let connected = await udp.connect(host: host, port: port)
        if !connected { return false }

        let flowing = await udp.waitForDataFlow(timeoutMs: 3000)
        if !flowing {
            udp.disconnect()
            return false
        }

        udpClient = udp
        tcpClient = nil
        return true
    }

    private func tryV7(host: String, port: Int, voipPort: Int) async -> Bool {
        let tcp = TCPClientV7(voipPort: voipPort > 0 ? voipPort : 4524)
        tcp.onAudio = { [weak self] data in self?.audioBridge.pushRXAudio(data) }
        tcp.onCommand = { [weak self] text in
            Task { @MainActor in self?.dispatchCommand(text) }
        }
        tcp.onControl = { [weak self] byte in
            Task { @MainActor in self?.handleControlByte(byte) }
        }
        tcp.onDisconnected = { [weak self] in
            Task { @MainActor in
                if self?.tcpClient === tcp { self?.connectionState = .disconnected }
            }
        }

        let connected = await tcp.connect(host: host, port: port)
        if !connected { return false }

        let flowing = await tcp.waitForDataFlow(timeoutMs: 5000)
        if !flowing {
            tcp.disconnect()
            return false
        }

        tcpClient = tcp
        udpClient = nil
        return true
    }

    // MARK: - Disconnect

    func disconnect() {
        audioBridge.stop()
        ipexClient?.disconnect(); ipexClient = nil
        let udp = udpClient; let tcp = tcpClient
        udpClient = nil; tcpClient = nil
        udp?.disconnect(); tcp?.disconnect()
        radioState.reset(); serverInfo.reset()
        rotatorState.reset(); ampState.reset(); switchState.reset()
        radioStateData = nil; serverInfoData = nil
        rotatorStateData = nil; ampStateData = nil; switchStateData = nil
        chatMessages = []
        connectionState = .authenticated
    }

    func logout() {
        disconnect()
        username = ""; passwordMD5 = ""
        connectionState = .disconnected
    }

    // MARK: - Send Commands

    func sendCommand(_ command: String) {
        if command.contains("frequency") {
            print("[SendCommand] \(command)")
        }
        if let tcp = tcpClient {
            tcp.sendCommandString(command)
        } else if let udp = udpClient {
            udp.sendCommandString(command)
        }
    }

    func sendPTT(_ on: Bool) {
        tcpClient?.sendPTT(on)
        udpClient?.sendPTT(on)
    }

    // MARK: - Command Dispatch

    private func dispatchCommand(_ command: String) {
        commandCount += 1
        if commandCount <= 30 {
            let preview = String(command.prefix(120))
            print("[Dispatch] #\(commandCount): \(preview)")
        }

        let radioCommand = translateV7Command(command)

        if let radioCommand {
            let changed = radioState.processCommand(radioCommand)
            if changed {
                scheduleStateUpdate()
            }
        } else if command.hasPrefix("radio::") || command.hasPrefix("chat::") {
            let changed = radioState.processCommand(command)
            if changed { scheduleStateUpdate() }
        }

        if command.hasPrefix("post::") || command.hasPrefix("chat::") || command.hasPrefix("mem::") || command.hasPrefix("log::") {
            let chatMsg = serverInfo.processCommand(command)
            serverInfoData = serverInfo.toData()
            if let chatMsg {
                chatMessages.append(chatMsg)
                if chatMessages.count > 200 { chatMessages.removeFirst(chatMessages.count - 200) }
            }
        }

        if command.hasPrefix("rotator::") {
            rotatorState.processCommand(command)
            rotatorStateData = rotatorState.toData()
        }
        if command.hasPrefix("amp::") {
            ampState.processCommand(command)
            ampStateData = ampState.toData()
        }
        if command.hasPrefix("switch::") {
            switchState.processCommand(command)
            switchStateData = switchState.toData()
        }
    }

    private func translateV7Command(_ command: String) -> String? {
        guard command.hasPrefix("post::") else { return nil }
        return command.replacingOccurrences(of: "post::", with: "radio::")
    }

    private func handleControlByte(_ byte: UInt8) {
        switch byte {
        case ControlByte.PTT:
            var data = radioState.toData()
            data.txEnabled = true
            radioStateData = data
        case ControlByte.PTT_OFF:
            var data = radioState.toData()
            data.txEnabled = false
            radioStateData = data
        default: break
        }
    }

    private func scheduleStateUpdate() {
        radioStateData = radioState.toData()
    }
}
