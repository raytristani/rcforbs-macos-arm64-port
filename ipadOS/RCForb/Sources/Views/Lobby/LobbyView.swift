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
            header
            stationList
            footer
        }
        .background(Color(hex: "#2a2a2a"))
        .onAppear { loadStations() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Text("Station Lobby")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.cream)

                Spacer()

                MetalButton(title: loading ? "Loading..." : "Refresh", isOn: false, style: .light) {
                    loadStations()
                }
                .disabled(loading)

                MetalButton(title: "Logout", isOn: false, style: .dark) {
                    connectionManager.logout()
                }
            }

            StyledTextField(placeholder: "Search stations...", text: $search)
                .frame(height: 30)
                .padding(.horizontal, 12)
                .background(
                    LinearGradient(colors: [Color(hex: "#555444"), Color(hex: "#444333")], startPoint: .top, endPoint: .bottom)
                )
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.btnBorder, lineWidth: 1))
                .cornerRadius(4)
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

    private func stationRow(_ station: RemoteStation) -> some View {
        let isSelected = selected == station.serverId
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.serverName)
                        .font(.system(size: 15, weight: .medium))
                    if !station.description.isEmpty {
                        Text(station.description)
                            .font(.system(size: 12))
                            .opacity(0.6)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text(station.isV7 ? "V7" : "V10")
                    .font(.system(size: 11))
                    .foregroundColor(Color.cream)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(station.isV7 ? Color(hex: "#884444") : Color(hex: "#448844"))
                    .cornerRadius(4)
            }

            HStack(spacing: 16) {
                Label(station.radioModel, systemImage: "radio")
                    .font(.system(size: 12))
                    .foregroundColor(Color.labelSubtle)
                Label(station.country, systemImage: "globe")
                    .font(.system(size: 12))
                    .foregroundColor(Color.labelSubtle)
                if !station.gridSquare.isEmpty {
                    Label(station.gridSquare, systemImage: "square.grid.2x2")
                        .font(.system(size: 12))
                        .foregroundColor(Color.labelSubtle)
                }
                if !station.serverVersion.isEmpty {
                    Text("v\(station.serverVersion)")
                        .font(.system(size: 11))
                        .foregroundColor(Color.labelSubtle.opacity(0.6))
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            isSelected
            ? AnyView(LinearGradient(colors: [Color.cream, Color.creamDark], startPoint: .top, endPoint: .bottom))
            : AnyView(Color.clear)
        )
        .foregroundColor(isSelected ? Color.textDark : Color.cream)
        .contentShape(Rectangle())
        .onTapGesture {
            if selected == station.serverId {
                Task { await connectionManager.connectToStation(station) }
            } else {
                selected = station.serverId
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(filtered.count) station\(filtered.count != 1 ? "s" : "") online")
            Spacer()
            Text("Tap a station to select, tap again to connect")
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
