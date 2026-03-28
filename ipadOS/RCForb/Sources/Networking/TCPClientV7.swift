import Foundation
import Network

/// V7 TCP client with dual connections ported from tcp-client-v7.ts
class TCPClientV7 {
    private var cmdConnection: NWConnection?
    private var audioConnection: NWConnection?
    private let voipPort: Int
    private var isConnectedFlag = false
    private var isDataFlowingFlag = false
    private var lastServerData = Date()
    private var heartbeatTimer: DispatchSourceTimer?
    private var timeoutTimer: DispatchSourceTimer?
    private var imaTimer: DispatchSourceTimer?
    private var cmdBuffer = ""
    private var audioBuffer = Data()
    private let queue = DispatchQueue(label: "com.rcforb.tcp", qos: .userInteractive)

    var onAudio: ((Data) -> Void)?
    var onCommand: ((String) -> Void)?
    var onControl: ((UInt8) -> Void)?
    var onDisconnected: (() -> Void)?

    private var onDataFlowResume: ((Bool) -> Void)?

    var isConnected: Bool { isConnectedFlag }

    init(voipPort: Int) {
        self.voipPort = voipPort
    }

    func connect(host: String, port: Int) async -> Bool {
        let cmdEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        let cmdConn = NWConnection(to: cmdEndpoint, using: .tcp)
        self.cmdConnection = cmdConn

        return await withCheckedContinuation { continuation in
            var resumed = false
            let resume: (Bool) -> Void = { value in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: value)
            }

            cmdConn.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    let audioEndpoint = NWEndpoint.hostPort(
                        host: NWEndpoint.Host(host),
                        port: NWEndpoint.Port(integerLiteral: UInt16(self.voipPort))
                    )
                    let audioConn = NWConnection(to: audioEndpoint, using: .tcp)
                    self.audioConnection = audioConn

                    audioConn.stateUpdateHandler = { [weak self] audioState in
                        guard let self else { return }
                        switch audioState {
                        case .ready:
                            self.isConnectedFlag = true
                            self.lastServerData = Date()
                            self.startHeartbeat()
                            self.startCmdReceive()
                            self.startAudioReceive()
                            resume(true)
                        case .failed, .cancelled:
                            resume(false)
                        default: break
                        }
                    }
                    audioConn.start(queue: self.queue)
                case .failed, .cancelled:
                    resume(false)
                default: break
                }
            }
            cmdConn.start(queue: queue)

            queue.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self, !self.isConnectedFlag else { return }
                cmdConn.cancel()
                resume(false)
            }
        }
    }

    func disconnect() {
        sendRawCmd(Data([ControlByte.USEROUT]))
        stopTimers()
        isConnectedFlag = false
        isDataFlowingFlag = false
        cmdConnection?.cancel(); cmdConnection = nil
        audioConnection?.cancel(); audioConnection = nil
        onDisconnected?()
    }

    private func handleDisconnect() {
        guard isConnectedFlag else { return }
        stopTimers()
        isConnectedFlag = false
        isDataFlowingFlag = false
        cmdConnection?.cancel(); cmdConnection = nil
        audioConnection?.cancel(); audioConnection = nil
        onDisconnected?()
    }

    func sendCommandString(_ text: String) {
        var cmd = text
        if cmd == "radio::request-state" {
            cmd = "set protocol rcs"
        }
        cmd = cmd.replacingOccurrences(of: "radio::", with: "post::")
        cmd = cmd.replacingOccurrences(of: "post::raw::", with: "k3term::")
        let data = (cmd + "\n").data(using: .utf8) ?? Data()
        cmdConnection?.send(content: data, completion: .contentProcessed { _ in })
    }

    func sendRawCmd(_ data: Data) {
        cmdConnection?.send(content: data, completion: .contentProcessed { _ in })
    }

    func sendPTT(_ on: Bool) {
        // V7 TCP: Send PTT as a framed string on the audio channel, matching
        // the C# SendDataPacket("PTT") format:
        //   bytes 0-3: payload length (int32 LE)
        //   byte 4: type (1 = control for PTT, 2 = audio/data for everything else)
        //   bytes 5-9: padding zeros
        //   bytes 10+: ASCII payload
        guard audioConnection != nil else { return }
        if on {
            let payload = "PTT".data(using: .ascii)!
            var packet = Data(count: 10 + payload.count)
            var len = Int32(payload.count).littleEndian
            withUnsafeBytes(of: &len) { packet.replaceSubrange(0..<4, with: $0) }
            packet[4] = 1 // type = control (specifically for PTT)
            packet.replaceSubrange(10..<(10 + payload.count), with: payload)
            audioConnection?.send(content: packet, completion: .contentProcessed { _ in })
        }
        // PTT OFF: no explicit packet needed — server detects absence of audio
    }

    func sendAudio(_ data: Data) {
        guard audioConnection != nil else { return }
        var header = Data(count: 10)
        var len = Int32(data.count).littleEndian
        withUnsafeBytes(of: &len) { header.replaceSubrange(0..<4, with: $0) }
        header[4] = 2 // packet type = audio/data (must be 2, matching C# SendAudioPacket)
        // bytes 5-9 remain zero (padding)
        audioConnection?.send(content: header + data, completion: .contentProcessed { _ in })
    }

    func sendSessionLogin(_ user: String, _ passwordMD5: String) {
        let sessionStr = "\(user.lowercased()),\(passwordMD5)"
        let strBytes = sessionStr.data(using: .ascii) ?? Data()
        var buf = Data(count: 64)
        var magic = Int32(54).littleEndian
        var strLen = Int32(strBytes.count).littleEndian
        withUnsafeBytes(of: &magic) { buf.replaceSubrange(0..<4, with: $0) }
        withUnsafeBytes(of: &strLen) { buf.replaceSubrange(4..<8, with: $0) }
        buf.replaceSubrange(8..<(8 + strBytes.count), with: strBytes)
        audioConnection?.send(content: buf, completion: .contentProcessed { _ in })
    }

    private func startCmdReceive() {
        cmdConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else { return }
            self.processCmdData(String(data: data, encoding: .utf8) ?? "")
            self.startCmdReceive()
        }
    }

    private func processCmdData(_ data: String) {
        lastServerData = Date()
        if !isDataFlowingFlag {
            isDataFlowingFlag = true
            onDataFlowResume?(true)
            onDataFlowResume = nil
        }

        cmdBuffer += data
        var lines = cmdBuffer.components(separatedBy: "\n")
        cmdBuffer = lines.removeLast()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                onCommand?(trimmed)
            }
        }
    }

    private func startAudioReceive() {
        audioConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else { return }
            self.processAudioData(data)
            self.startAudioReceive()
        }
    }

    private func processAudioData(_ data: Data) {
        audioBuffer.append(data)

        while audioBuffer.count >= 10 {
            let payloadLen = audioBuffer.withUnsafeBytes { $0.load(as: Int32.self) }.littleEndian

            if payloadLen == 0 {
                audioBuffer = Data(audioBuffer.dropFirst(4))
                continue
            }

            if payloadLen == 54 {
                if audioBuffer.count < 62 { break }
                audioBuffer = Data(audioBuffer.dropFirst(62))
                continue
            }

            if payloadLen < 0 || payloadLen > 8192 {
                audioBuffer = Data(audioBuffer.dropFirst(1))
                continue
            }

            let totalLen = 10 + Int(payloadLen)
            if audioBuffer.count < totalLen { break }

            if payloadLen > 0 && payloadLen < 19 {
                let pttByte = audioBuffer[4]
                if pttByte == 2 {
                    onControl?(ControlByte.PTT)
                } else if pttByte == 0 || pttByte == 1 {
                    onControl?(ControlByte.PTT_OFF)
                }
            } else if payloadLen >= 19 {
                let audioPayload = Data(audioBuffer[10..<totalLen])
                onAudio?(audioPayload)
            }

            audioBuffer = Data(audioBuffer.dropFirst(totalLen))
        }
    }

    private func startHeartbeat() {
        heartbeatTimer = DispatchSource.makeTimerSource(queue: queue)
        heartbeatTimer?.schedule(deadline: .now(), repeating: .milliseconds(HEARTBEAT_INTERVAL_MS))
        heartbeatTimer?.setEventHandler { [weak self] in
            self?.sendCommandString("post::heartbeat::\(Int(Date().timeIntervalSince1970 * 1000))")
            self?.sendCommandString("post::check::cantune")
        }
        heartbeatTimer?.resume()

        imaTimer = DispatchSource.makeTimerSource(queue: queue)
        imaTimer?.schedule(deadline: .now(), repeating: 2)
        imaTimer?.setEventHandler { [weak self] in
            guard self?.audioConnection != nil else { return }
            var ima = Data(count: 13)
            var imaLen = Int32(3).littleEndian
            withUnsafeBytes(of: &imaLen) { ima.replaceSubrange(0..<4, with: $0) }
            ima[4] = 2
            let imaStr = "IMA".data(using: .ascii)!
            ima.replaceSubrange(10..<13, with: imaStr)
            self?.audioConnection?.send(content: ima, completion: .contentProcessed { _ in })
        }
        imaTimer?.resume()

        timeoutTimer = DispatchSource.makeTimerSource(queue: queue)
        timeoutTimer?.schedule(deadline: .now() + 1, repeating: 1)
        timeoutTimer?.setEventHandler { [weak self] in
            guard let self else { return }
            if Date().timeIntervalSince(self.lastServerData) * 1000 > Double(HEARTBEAT_TIMEOUT_MS) {
                print("[TCPv7] Heartbeat timeout")
                self.handleDisconnect()
            }
        }
        timeoutTimer?.resume()
    }

    private func stopTimers() {
        heartbeatTimer?.cancel(); heartbeatTimer = nil
        timeoutTimer?.cancel(); timeoutTimer = nil
        imaTimer?.cancel(); imaTimer = nil
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
