import Foundation
import Network

/// V10 UDP client ported from udp-client.ts
class UDPClient {
    private var connection: NWConnection?
    private var isConnectedFlag = false
    private var isDataFlowingFlag = false
    private var lastServerData = Date()
    private var heartbeatTimer: DispatchSourceTimer?
    private var pingTimer: DispatchSourceTimer?
    private var timeoutTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.rcforb.udp", qos: .userInteractive)

    var onAudio: ((Data) -> Void)?
    var onCommand: ((String) -> Void)?
    var onControl: ((UInt8) -> Void)?
    var onDisconnected: (() -> Void)?

    private var onDataFlowResume: ((Bool) -> Void)?

    var isConnected: Bool { isConnectedFlag }
    var isDataFlowing: Bool { isDataFlowingFlag }

    func connect(host: String, port: Int) async -> Bool {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        let params = NWParameters.udp
        params.requiredInterfaceType = .other
        let conn = NWConnection(to: endpoint, using: params)
        self.connection = conn

        return await withCheckedContinuation { continuation in
            var resumed = false
            let resume: (Bool) -> Void = { value in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: value)
            }

            conn.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isConnectedFlag = true
                    self?.isDataFlowingFlag = false
                    self?.lastServerData = Date()

                    let userInData = Data([ControlByte.USERIN])
                    for _ in 0..<3 {
                        self?.sendRaw(userInData)
                    }

                    self?.startHeartbeat()
                    self?.startReceiving()
                    resume(true)
                case .failed, .cancelled:
                    self?.handleDisconnect()
                    resume(false)
                default:
                    break
                }
            }
            conn.start(queue: queue)

            queue.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self, !self.isConnectedFlag else { return }
                conn.cancel()
                resume(false)
            }
        }
    }

    func disconnect() {
        guard isConnectedFlag || connection != nil else { return }
        sendRaw(Data([ControlByte.USEROUT]))
        stopTimers()
        isConnectedFlag = false
        isDataFlowingFlag = false
        connection?.cancel()
        connection = nil
        onDisconnected?()
    }

    private func handleDisconnect() {
        stopTimers()
        isConnectedFlag = false
        isDataFlowingFlag = false
        connection?.cancel()
        connection = nil
        onDisconnected?()
    }

    func sendRaw(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }

    func sendCommandString(_ text: String) {
        var packet = Data([ControlByte.UTF8STRING])
        packet.append(text.data(using: .utf8) ?? Data())
        sendRaw(packet)
    }

    func sendPTT(_ on: Bool) {
        sendRaw(Data([on ? ControlByte.PTT : ControlByte.PTT_OFF]))
    }

    func sendAudio(_ data: Data) {
        sendRaw(data)
    }

    private func startReceiving() {
        connection?.receiveMessage { [weak self] data, _, _, error in
            guard let self, let data, error == nil else { return }
            self.processPacket(data)
            self.startReceiving()
        }
    }

    private func processPacket(_ data: Data) {
        guard !data.isEmpty else { return }

        lastServerData = Date()
        if !isDataFlowingFlag {
            isDataFlowingFlag = true
            onDataFlowResume?(true)
            onDataFlowResume = nil
        }

        let type = classifyPacket(data)
        switch type {
        case .audio:
            onAudio?(data)
        case .command:
            let text = String(data: data.dropFirst(), encoding: .utf8) ?? ""
            onCommand?(text)
        case .pttOn:
            onControl?(ControlByte.PTT)
        case .pttOff:
            onControl?(ControlByte.PTT_OFF)
        case .keyOn:
            onControl?(ControlByte.KEY_ON)
        case .keyOff:
            onControl?(ControlByte.KEY_OFF)
        case .userOut:
            handleDisconnect()
        case .heartbeat, .pingpong, .userIn:
            break
        }
    }

    private func startHeartbeat() {
        heartbeatTimer = DispatchSource.makeTimerSource(queue: queue)
        heartbeatTimer?.schedule(deadline: .now(), repeating: .milliseconds(HEARTBEAT_INTERVAL_MS))
        heartbeatTimer?.setEventHandler { [weak self] in
            self?.sendRaw(Data([ControlByte.HEARTBEAT]))
        }
        heartbeatTimer?.resume()

        pingTimer = DispatchSource.makeTimerSource(queue: queue)
        pingTimer?.schedule(deadline: .now(), repeating: .milliseconds(PING_INTERVAL_MS))
        pingTimer?.setEventHandler { [weak self] in
            self?.sendRaw(Data([ControlByte.PINGPONG]))
        }
        pingTimer?.resume()

        timeoutTimer = DispatchSource.makeTimerSource(queue: queue)
        timeoutTimer?.schedule(deadline: .now() + 1, repeating: 1)
        timeoutTimer?.setEventHandler { [weak self] in
            guard let self else { return }
            if Date().timeIntervalSince(self.lastServerData) * 1000 > Double(HEARTBEAT_TIMEOUT_MS) {
                print("[UDPClient] Heartbeat timeout, disconnecting")
                self.handleDisconnect()
            }
        }
        timeoutTimer?.resume()
    }

    private func stopTimers() {
        heartbeatTimer?.cancel(); heartbeatTimer = nil
        pingTimer?.cancel(); pingTimer = nil
        timeoutTimer?.cancel(); timeoutTimer = nil
    }

    func waitForDataFlow(timeoutMs: Int = 8000) async -> Bool {
        if isDataFlowingFlag { return true }
        return await withCheckedContinuation { continuation in
            var resumed = false
            let resume: (Bool) -> Void = { value in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: value)
            }
            self.onDataFlowResume = resume
            queue.asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) { [weak self] in
                self?.onDataFlowResume?(false)
                self?.onDataFlowResume = nil
            }
        }
    }
}
