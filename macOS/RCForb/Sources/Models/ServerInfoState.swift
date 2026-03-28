import Foundation

/// Server info state model ported from server-info.ts
class ServerInfoState {
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

    func reset() {
        serverId = ""; serverVersion = ""; serverUptime = ""; serverTime = ""
        radioName = ""; radioDriver = ""
        radioOpen = false; radioInUse = false; radioInUseBy = ""
        tot = 180
    }

    func processCommand(_ command: String) -> ChatMessage? {
        if command.hasPrefix("post::id::") {
            serverId = String(command.dropFirst("post::id::".count))
        } else if command.hasPrefix("post::version::") {
            serverVersion = String(command.dropFirst("post::version::".count))
        } else if command.hasPrefix("post::heartbeat::") {
            serverUptime = String(command.dropFirst("post::heartbeat::".count))
        } else if command.hasPrefix("post::time::") {
            serverTime = String(command.dropFirst("post::time::".count))
        } else if command.hasPrefix("post::lasttuner::") {
            radioInUseBy = String(command.dropFirst("post::lasttuner::".count))
        } else if command.hasPrefix("post::tot::") {
            tot = Int(command.dropFirst("post::tot::".count)) ?? 180
        } else if command.hasPrefix("post::radio-open") {
            radioOpen = true
            radioInUse = false
        } else if command.hasPrefix("post::radio-in-use") {
            radioInUse = true
            radioOpen = false
            let rest = String(command.dropFirst("post::radio-in-use".count))
            if rest.hasPrefix("::") {
                radioInUseBy = String(rest.dropFirst(2))
            }
        } else if command.hasPrefix("post::radio-closed") {
            radioOpen = false
            radioInUse = false
        } else if command.hasPrefix("chat::") {
            let raw = String(command.dropFirst("chat::".count))
            return parseChatMessage(raw)
        }
        return nil
    }

    func toData() -> ServerInfoData {
        ServerInfoData(
            serverId: serverId,
            serverVersion: serverVersion,
            serverUptime: serverUptime,
            serverTime: serverTime,
            radioName: radioName,
            radioDriver: radioDriver,
            radioOpen: radioOpen,
            radioInUse: radioInUse,
            radioInUseBy: radioInUseBy,
            tot: tot
        )
    }
}

private func parseChatMessage(_ raw: String) -> ChatMessage {
    let decoded = raw.removingPercentEncoding?.replacingOccurrences(of: "+", with: " ") ?? raw
    let parts = decoded.components(separatedBy: "::")

    var user = ""
    var text = decoded

    if parts.count >= 3 {
        user = parts[0]
        text = parts[2...].joined(separator: "::")
    } else if parts.count == 2 {
        user = parts[0]
        text = parts[1]
    }

    text = text
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")

    return ChatMessage(
        user: user,
        text: text,
        timestamp: Date(),
        isSystem: user.isEmpty || user == "System"
    )
}
