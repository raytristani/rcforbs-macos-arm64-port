import SwiftUI

struct LobbyView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var search = ""
    @State private var loading = false
    @State private var selected: String?
    @State private var showFavorites = false
    @State private var favorites: [FavoriteStation] = []


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
            // Main content with optional favorites sidebar
            HStack(spacing: 0) {
                stationList
                if showFavorites {
                    favoritesSidebar
                }
            }
            // Footer
            footer
        }
        .background(Color.background)
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
                .background(Color.inputBg)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.btnBorder, lineWidth: 1))
                .cornerRadius(8)

            MetalButton(title: loading ? "Loading..." : "Refresh", isOn: false, style: .light) {
                loadStations()
            }
            .disabled(loading)

            MetalButton(title: "Connect", isOn: false, style: .light) {
                guard let id = selected,
                      let station = filtered.first(where: { $0.id == id }) else { return }
                Task { await connectionManager.connectToStation(station) }
            }
            .disabled(selected == nil)
            .opacity(selected == nil ? 0.5 : 1.0)

            MetalButton(title: "My Stations", isOn: showFavorites, fontSize: 12) {
                showFavorites.toggle()
                if showFavorites { favorites = FavoritesStore.load() }
            }

            MetalButton(title: "Logout", isOn: false, style: .dark) {
                connectionManager.logout()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.chassisGradientTo)
        .overlay(
            Rectangle().frame(height: 2).foregroundColor(Color.btnBorder),
            alignment: .bottom
        )
    }

    private func isSelected(_ station: RemoteStation) -> Bool {
        selected == station.id
    }

    private var stationList: some View {
        Table(filtered, selection: $selected) {
            TableColumn("Station") { station in
                let sel = isSelected(station)
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.serverName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(sel ? Color.textDark : Color.cream)
                    if !station.description.isEmpty {
                        Text(station.description)
                            .font(.system(size: 11))
                            .foregroundColor(sel ? Color.textDark.opacity(0.7) : Color.mutedForeground)
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 200, ideal: 400)

            TableColumn("Radio") { station in
                Text(station.radioModel)
                    .foregroundColor(isSelected(station) ? Color.textDark : Color.cream)
            }
            .width(min: 80, ideal: 100, max: 120)

            TableColumn("Country") { station in
                Text(station.country)
                    .foregroundColor(isSelected(station) ? Color.textDark : Color.cream)
            }
            .width(min: 80, ideal: 110, max: 140)

            TableColumn("Grid") { station in
                Text(station.gridSquare)
                    .foregroundColor(isSelected(station) ? Color.textDark : Color.cream)
            }
            .width(min: 60, ideal: 70, max: 90)

            TableColumn("Ver") { station in
                Text(station.serverVersion)
                    .foregroundColor(isSelected(station) ? Color.textDark : Color.cream)
            }
            .width(min: 80, ideal: 110, max: 140)

            TableColumn("Proto") { station in
                Text(station.isV7 ? "V7" : "V10")
                    .font(.system(size: 11))
                    .foregroundColor(Color.cream)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(station.isV7 ? Color.ledRed : Color.ledGreen)
                    .cornerRadius(6)
            }
            .width(min: 40, ideal: 50, max: 60)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .onDoubleClickTableRow {
            guard let id = selected,
                  let station = filtered.first(where: { $0.id == id }) else { return }
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
        .background(Color.inputBg)
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

    // MARK: - Favorites Sidebar

    private var favoritesSidebar: some View {
        VStack(spacing: 0) {
            // Sidebar header
            Text("Favorites")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.cream)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.chassisGradientTo)

            if favorites.isEmpty {
                Spacer()
                Text("No favorites yet.\nSave a station while\nconnected to add it.")
                    .font(.system(size: 12))
                    .foregroundColor(Color.labelDim)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(favorites, id: \.serverId) { fav in
                            favoriteStationCard(fav)
                        }
                    }
                    .padding(6)
                }
            }
        }
        .frame(width: 260)
        .background(Color.background)
        .overlay(Rectangle().frame(width: 1).foregroundColor(Color.panelBorder), alignment: .leading)
    }

    private func favoriteStationCard(_ fav: FavoriteStation) -> some View {
        let isOnline = connectionManager.stations.contains { $0.serverId == fav.serverId && $0.online }

        return VStack(alignment: .leading, spacing: 2) {
            // Station name
            Text(fav.serverName)
                .font(.custom(FontRegistration.digital7Mono, size: 13))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#553300"))
                .lineLimit(1)

            // Radio model
            if !fav.radioModel.isEmpty {
                Text(fav.radioModel)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#887744"))
                    .lineLimit(1)
            }

            // Description
            if !fav.description.isEmpty {
                Text(fav.description)
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "#887744").opacity(0.7))
                    .lineLimit(1)
            }

            Spacer().frame(height: 4)

            // Bottom row: online status + remove button
            HStack {
                Circle()
                    .fill(isOnline ? Color(hex: "#44cc44") : Color(hex: "#cc4444"))
                    .frame(width: 6, height: 6)

                Text(isOnline ? "Online" : "Offline")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "#887744"))

                Spacer()

                Text("\u{2716}")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#AA6644"))
                    .onTapGesture {
                        FavoritesStore.removeFavorite(fav.serverId)
                        favorites = FavoritesStore.load()
                    }
                    .padding(2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(hex: "#E8D888"))
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture {
            if isOnline, let station = connectionManager.stations.first(where: { $0.serverId == fav.serverId }) {
                Task { await connectionManager.connectToStation(station) }
            } else {
                // Connect using saved info even if not in current lobby
                let station = RemoteStation(
                    serverId: fav.serverId,
                    serverName: fav.serverName,
                    description: fav.description,
                    host: fav.host,
                    port: fav.port,
                    voipPort: fav.voipPort,
                    online: true,
                    radioInUse: false,
                    radioOpen: false,
                    serverVersion: "",
                    radioModel: fav.radioModel,
                    country: "",
                    gridSquare: "",
                    latitude: 0.0,
                    longitude: 0.0,
                    userCount: 0,
                    maxUsers: 0,
                    isV7: fav.isV7
                )
                Task { await connectionManager.connectToStation(station) }
            }
        }
    }
}

// MARK: - Double-click support for Table rows via NSTableView hook

private struct TableDoubleClickModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.overlay {
            TableDoubleClickFinder(action: action)
                .frame(width: 0, height: 0)
        }
    }
}

private struct TableDoubleClickFinder: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = TableDoubleClickAnchor()
        view.coordinator = context.coordinator
        context.coordinator.action = action
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var action: (() -> Void)?
        var installed = false

        @objc func onDoubleClick() {
            action?()
        }
    }
}

/// Anchor view that hooks into NSTableView once added to the view hierarchy
private class TableDoubleClickAnchor: NSView {
    var coordinator: TableDoubleClickFinder.Coordinator?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let coordinator, !coordinator.installed else { return }
        // Retry a few times since the table may not be in the hierarchy immediately
        tryInstall(coordinator: coordinator, attempts: 10)
    }

    private func tryInstall(coordinator: TableDoubleClickFinder.Coordinator, attempts: Int) {
        if let tv = findTableViewUp(from: self) {
            tv.doubleAction = #selector(TableDoubleClickFinder.Coordinator.onDoubleClick)
            tv.target = coordinator
            coordinator.installed = true
        } else if attempts > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.tryInstall(coordinator: coordinator, attempts: attempts - 1)
            }
        }
    }

    /// Walk up from this view to find the enclosing NSTableView
    private func findTableViewUp(from view: NSView) -> NSTableView? {
        var current: NSView? = view
        while let v = current {
            if let tv = findTableViewDown(in: v) { return tv }
            current = v.superview
        }
        return nil
    }

    private func findTableViewDown(in view: NSView) -> NSTableView? {
        if let tv = view as? NSTableView { return tv }
        for sub in view.subviews {
            if let found = findTableViewDown(in: sub) { return found }
        }
        return nil
    }
}

extension View {
    func onDoubleClickTableRow(perform action: @escaping () -> Void) -> some View {
        modifier(TableDoubleClickModifier(action: action))
    }
}
