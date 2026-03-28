import Foundation

enum LobbyService {
    private static let feedURL = "http://online.remotehams.com/xmlfeed.php"

    static func fetchStations() async -> [RemoteStation] {
        guard let url = URL(string: feedURL) else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let xml = String(data: data, encoding: .utf8) ?? ""
            return parseStationXML(xml)
        } catch {
            print("[LobbyService] Fetch error: \(error)")
            return []
        }
    }

    private static func parseStationXML(_ xml: String) -> [RemoteStation] {
        var stations: [RemoteStation] = []

        let pattern = "<Radio>([\\s\\S]*?)</Radio>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))

        for match in matches {
            if let range = Range(match.range(at: 1), in: xml) {
                let block = String(xml[range])
                if let station = parseRadioBlock(block) {
                    stations.append(station)
                }
            }
        }
        return stations
    }

    private static func getField(_ block: String, _ tag: String) -> String {
        let pattern = "<\(tag)>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
              let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
              let range = Range(match.range(at: 1), in: block) else { return "" }
        return String(block[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseRadioBlock(_ block: String) -> RemoteStation? {
        let orbId = getField(block, "OrbId")
        let domain = getField(block, "Domain")
        guard !orbId.isEmpty, !domain.isEmpty else { return nil }

        let port = Int(getField(block, "Port")) ?? 4525
        let voipPort = Int(getField(block, "VoipPort")) ?? 4524

        return RemoteStation(
            serverId: orbId,
            serverName: getField(block, "ServerName").isEmpty ? "Unknown" : getField(block, "ServerName"),
            description: getField(block, "Message"),
            host: domain,
            port: port,
            voipPort: voipPort,
            online: getField(block, "Online").lowercased() == "true",
            radioInUse: false,
            radioOpen: true,
            serverVersion: getField(block, "Version"),
            radioModel: getField(block, "RadioName"),
            country: getField(block, "Country"),
            gridSquare: getField(block, "Grid"),
            latitude: Double(getField(block, "Latitude")) ?? 0,
            longitude: Double(getField(block, "Longitude")) ?? 0,
            userCount: Int(getField(block, "Users")) ?? 0,
            maxUsers: Int(getField(block, "MaxUsers")) ?? 0,
            isV7: false
        )
    }
}
