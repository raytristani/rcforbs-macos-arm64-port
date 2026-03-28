import Foundation

enum AuthService {
    private static let loginURL = "https://api.remotehams.com/v2/login.php"

    static func authenticate(_ user: String, _ password: String) async -> AuthResult {
        let passMD5 = md5(password)
        return await authenticateWithMD5(user, passMD5)
    }

    static func authenticateWithMD5(_ user: String, _ passwordMD5: String) async -> AuthResult {
        let passDoubleHash = md5(passwordMD5)
        let encodedUser = user.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? user
        let valid = validationToken(user, passDoubleHash)

        let body = "user=\(encodedUser)&pass=\(passDoubleHash)&valid=\(valid)&getkey=true"

        guard let url = URL(string: loginURL) else {
            return AuthResult(success: false, message: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let text = String(data: data, encoding: .utf8) ?? ""

            if text.hasPrefix("Valid") {
                let parts = text.components(separatedBy: ",")
                let apiKey = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : nil
                return AuthResult(success: true, message: text, apiKey: apiKey)
            }
            return AuthResult(success: false, message: text)
        } catch {
            return AuthResult(success: false, message: error.localizedDescription)
        }
    }

    static func trackOnline(_ user: String, _ passwordMD5: String, _ orbId: String?) async -> Bool {
        let passDoubleHash = md5(passwordMD5)
        let encodedUser = user.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? user
        let valid = md5(encodedUser + passDoubleHash)

        var body = "user=\(encodedUser)&pass=\(passDoubleHash)&varMe=valYou&logonline=true&valid=\(valid)"
        if let orbId { body += "&orbid=\(orbId)" }

        guard let url = URL(string: loginURL) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let text = String(data: data, encoding: .utf8) ?? ""
            return text.contains("Valid")
        } catch {
            return false
        }
    }
}
