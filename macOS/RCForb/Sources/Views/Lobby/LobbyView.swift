import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var search = ""
    @State private var loading = false
    @State private var selected: String?

    private var filtered: [RemoteStation] {
        if search.isEmpty { return connectionManager.stations }
        let q = search.lowercased()
        return connectionManager.stations.filter {
            $0.serverName.lowercased().contains(q) ||
            $0.radioModel.lowercased().contains(q) ||
            $0.country.lowercased().contains(q) ||
            $0.gridSquare.lowercased().contains(q) ||
            $0.description.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            // Station list
            stationList
            // Footer
            footer
        }
        .background(Color(hex: "#2a2a2a"))
        .onAppear { loadStations() }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("Station Lobby")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.cream)

            StyledTextField(placeholder: "Search stations...", text: $search)
                .frame(height: 26)
                .padding(.horizontal, 12)
                .background(
                    LinearGradient(colors: [Color(hex: "#555444"), Color(hex: "#444333")], startPoint: .top, endPoint: .bottom)
                )
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.btnBorder, lineWidth: 1))
                .cornerRadius(4)

            MetalButton(title: loading ? "Loading..." : "Refresh", isOn: false, style: .light) {
                loadStations()
            }
            .disabled(loading)

            MetalButton(title: "Logout", isOn: false, style: .dark) {
                connectionManager.logout()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Color.chassisGradientFrom, Color.chassisGradientTo], startPoint: .top, endPoint: .bottom)
        )
        .overlay(
            Rectangle().frame(height: 2).foregroundColor(Color.btnBorder),
            alignment: .bottom
        )
    }

    private var stationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    headerCell("STATION", width: nil)
                    headerCell("RADIO", width: 120)
                    headerCell("LOCATION", width: 100)
                    headerCell("GRID", width: 80)
                    headerCell("VER", width: 60)
                    headerCell("TYPE", width: 60)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                ForEach(filtered) { station in
                    stationRow(station)
                }

                if filtered.isEmpty && !loading {
                    Text(connectionManager.stations.isEmpty ? "No stations online" : "No matching stations")
                        .foregroundColor(Color.labelSubtle.opacity(0.5))
                        .padding(.vertical, 32)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func headerCell(_ title: String, width: CGFloat?) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .regular))
            .foregroundColor(Color.labelSubtle)
            .tracking(0.5)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .padding(.horizontal, 12)
    }

    private func stationRow(_ station: RemoteStation) -> some View {
        let isSelected = selected == station.serverId
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(station.serverName)
                    .font(.system(size: 13, weight: .medium))
                if !station.description.isEmpty {
                    Text(station.description)
                        .font(.system(size: 11))
                        .opacity(0.6)
                        .lineLimit(1)
                        .frame(maxWidth: 256, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)

            Text(station.radioModel)
                .font(.system(size: 13))
                .frame(width: 120, alignment: .leading)
                .padding(.horizontal, 12)

            Text(station.country)
                .font(.system(size: 13))
                .frame(width: 100, alignment: .leading)
                .padding(.horizontal, 12)

            Text(station.gridSquare)
                .font(.system(size: 13))
                .frame(width: 80, alignment: .leading)
                .padding(.horizontal, 12)

            Text(station.serverVersion)
                .font(.system(size: 13))
                .frame(width: 60, alignment: .leading)
                .padding(.horizontal, 12)

            Text(station.isV7 ? "V7" : "V10")
                .font(.system(size: 11))
                .foregroundColor(Color.cream)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(station.isV7 ? Color(hex: "#884444") : Color(hex: "#448844"))
                .cornerRadius(4)
                .frame(width: 60, alignment: .leading)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            isSelected
            ? AnyView(LinearGradient(colors: [Color.cream, Color.creamDark], startPoint: .top, endPoint: .bottom))
            : AnyView(Color.clear)
        )
        .foregroundColor(isSelected ? Color.textDark : Color.cream)
        .contentShape(Rectangle())
        .onTapGesture {
            selected = station.serverId
        }
        .onTapGesture(count: 2) {
            Task { await connectionManager.connectToStation(station) }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(filtered.count) station\(filtered.count != 1 ? "s" : "") online")
            Spacer()
            Text("Double-click a station to connect")
        }
        .font(.system(size: 11))
        .foregroundColor(Color.labelSubtle)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [Color(hex: "#555444"), Color(hex: "#444333")], startPoint: .top, endPoint: .bottom)
        )
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(Color.chassisGradientFrom),
            alignment: .top
        )
    }

    private func loadStations() {
        loading = true
        Task {
            _ = await connectionManager.refreshLobby()
            loading = false
        }
    }
}
