import Foundation
import Network

/// IpEx NAT traversal client ported from ipex-client.ts
class IpExClient {
    private static let IPEX_HOST = "ipex.remotehams.com"
    private static let IPEX_PORT: UInt16 = 7005

    private var connection: NWConnection?
    private var isConnectedFlag = false
    private var heartbeatTimer: DispatchSourceTimer?
    private var timeoutTimer: DispatchSourceTimer?
    private var lastDataTime = Date()
    private var lineBuffer = ""
    private let queue = DispatchQueue(label: "com.rcforb.ipex")

    var onHolePunchGo: ((String) -> Void)?
    var onHolePunchOk: (() -> Void)?
    var onHolePunchFail: (() -> Void)?
    var onServerNotFound: (() -> Void)?
    var onDisconnected: (() -> Void)?

    var isConnected: Bool { isConnectedFlag }

    func connect() async -> Bool {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(Self.IPEX_HOST),
            port: NWEndpoint.Port(integerLiteral: Self.IPEX_PORT)
        )
        let conn = NWConnection(to: endpoint, using: .tcp)
        self.connection = conn

        return await withCheckedContinuation { continuation in
            conn.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isConnectedFlag = true
                    self?.lastDataTime = Date()
                    self?.startHeartbeat()
                    self?.startReceiving()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    self?.handleDisconnect()
                    continuation.resume(returning: false)
                default: break
                }
            }
            conn.start(queue: queue)

            queue.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self, !self.isConnectedFlag else { return }
                conn.cancel()
            }
        }
    }

    func disconnect() {
        isConnectedFlag = false
        stopTimers()
        connection?.cancel()
        connection = nil
        onDisconnected?()
    }

    private func handleDisconnect() {
        guard isConnectedFlag else { return }
        isConnectedFlag = false
        stopTimers()
        connection = nil
        onDisconnected?()
    }

    func holePunchRequest(_ serverEndpoint: String, _ clientPort: Int) {
        send("ClientConnectRequest,\(serverEndpoint),\(clientPort)\n")
    }

    func connectRequestCompleted() { send("ClientConnectRequest,OK\n") }
    func connectRequestFailed() { send("ClientConnectRequest,FAIL\n") }

    private func send(_ data: String) {
        guard let conn = connection, isConnectedFlag else { return }
        conn.send(content: data.data(using: .utf8), completion: .contentProcessed { _ in })
    }

    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else { return }
            self.processData(String(data: data, encoding: .utf8) ?? "")
            self.startReceiving()
        }
    }

    private func processData(_ data: String) {
        lastDataTime = Date()
        lineBuffer += data
        var lines = lineBuffer.components(separatedBy: "\n")
        lineBuffer = lines.removeLast()
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { processLine(trimmed) }
        }
    }

    private func processLine(_ line: String) {
        if line.hasPrefix("ClientConnectRequest,GO") {
            let parts = line.components(separatedBy: ",")
            let endpoint = parts.count > 2 ? parts[2] : ""
            onHolePunchGo?(endpoint)
        } else if line == "ClientConnectRequest,OK" {
            onHolePunchOk?()
        } else if line == "ClientConnectRequest,FAIL" {
            onHolePunchFail?()
        } else if line.hasPrefix("ServerNotFound") {
            onServerNotFound?()
        }
    }

    private func startHeartbeat() {
        heartbeatTimer = DispatchSource.makeTimerSource(queue: queue)
        heartbeatTimer?.schedule(deadline: .now(), repeating: 4)
        heartbeatTimer?.setEventHandler { [weak self] in
            self?.send("\(Int(Date().timeIntervalSince1970 * 1000))\n")
        }
        heartbeatTimer?.resume()

        timeoutTimer = DispatchSource.makeTimerSource(queue: queue)
        timeoutTimer?.schedule(deadline: .now() + 1, repeating: 1)
        timeoutTimer?.setEventHandler { [weak self] in
            guard let self else { return }
            if Date().timeIntervalSince(self.lastDataTime) > 15 {
                print("[IpEx] Heartbeat timeout")
                self.handleDisconnect()
            }
        }
        timeoutTimer?.resume()
    }

    private func stopTimers() {
        heartbeatTimer?.cancel(); heartbeatTimer = nil
        timeoutTimer?.cancel(); timeoutTimer = nil
    }
}
