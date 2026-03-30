import Foundation

struct FavoriteStation: Codable {
    let serverId: String
    let serverName: String
    let radioModel: String
    let description: String
    let host: String
    let port: Int
    let voipPort: Int
    let isV7: Bool
}

enum FavoritesStore {
    private static let key = "rcforb_favorites"

    static func save(_ favorites: [FavoriteStation]) {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> [FavoriteStation] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([FavoriteStation].self, from: data)
        else { return [] }
        return list
    }

    static func addFavorite(_ station: FavoriteStation) {
        var list = load()
        guard !list.contains(where: { $0.serverId == station.serverId }) else { return }
        list.append(station)
        save(list)
    }

    static func removeFavorite(_ serverId: String) {
        var list = load()
        list.removeAll { $0.serverId == serverId }
        save(list)
    }

    static func isFavorite(_ serverId: String) -> Bool {
        load().contains { $0.serverId == serverId }
    }
}
