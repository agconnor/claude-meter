import Foundation
import ClaudeMeterCore

/// Fetches usage from Anthropic, refreshing the OAuth token first if it has expired.
final class UsageClient {
    private let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let tokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    private let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private let session = URLSession(configuration: .ephemeral)

    func fetch(completion: @escaping (Result<Usage, UsageError>) -> Void) {
        guard let creds = Keychain.readCredentials() else {
            return DispatchQueue.main.async { completion(.failure(.noCredentials)) }
        }
        let nowMs = Date().timeIntervalSince1970 * 1000
        if creds.expiresAt > 0, creds.expiresAt - nowMs < 60_000, !creds.refreshToken.isEmpty {
            refresh(refreshToken: creds.refreshToken) { [weak self] newToken in
                self?.getUsage(token: newToken ?? creds.accessToken, completion: completion)
            }
        } else {
            getUsage(token: creds.accessToken, completion: completion)
        }
    }

    private func getUsage(token: String, completion: @escaping (Result<Usage, UsageError>) -> Void) {
        var req = URLRequest(url: usageURL)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("ClaudeMeter (menu-bar)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15

        session.dataTask(with: req) { data, resp, err in
            let done: (Result<Usage, UsageError>) -> Void = { r in DispatchQueue.main.async { completion(r) } }
            if let err = err { return done(.failure(.network(err.localizedDescription))) }
            guard let http = resp as? HTTPURLResponse else { return done(.failure(.decode)) }
            guard (200..<300).contains(http.statusCode) else { return done(.failure(.http(http.statusCode))) }
            guard let data = data, let usage = UsageParser.parseUsage(data) else { return done(.failure(.decode)) }
            done(.success(usage))
        }.resume()
    }

    /// Exchanges the refresh token and writes the rotated tokens back to the keychain.
    private func refresh(refreshToken: String, completion: @escaping (String?) -> Void) {
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ])

        session.dataTask(with: req) { data, resp, _ in
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let access = json["access_token"] as? String else {
                return completion(nil)
            }
            let newRefresh = (json["refresh_token"] as? String) ?? refreshToken
            let expiresIn = (json["expires_in"] as? Double) ?? 0
            let expiresAt = Date().timeIntervalSince1970 * 1000 + expiresIn * 1000
            Keychain.updateTokens(accessToken: access, refreshToken: newRefresh, expiresAt: expiresAt)
            completion(access)
        }.resume()
    }
}
