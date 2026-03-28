import Foundation

enum CredentialStore {
    private static var credPath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RCForb", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("credentials.json")
    }

    static func save(_ user: String, _ password: String) {
        let dict = ["user": user, "password": password]
        guard let data = try? JSONEncoder().encode(dict) else { return }
        // Simple obfuscation (not security - just avoid plaintext on disk)
        let encoded = Data(data.map { $0 ^ 0x5A })
        try? encoded.write(to: credPath)
    }

    static func load() -> SavedCredentials? {
        guard let encoded = try? Data(contentsOf: credPath) else { return nil }
        let data = Data(encoded.map { $0 ^ 0x5A })
        guard let dict = try? JSONDecoder().decode([String: String].self, from: data),
              let user = dict["user"], let password = dict["password"] else { return nil }
        return SavedCredentials(user: user, password: password)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: credPath)
    }
}
