import Foundation
import ClaudeMeterCore

/// Fetches usage from Anthropic. Strictly read-only with respect to the keychain:
/// it uses whatever access token Claude Code currently holds and never refreshes or
/// writes tokens — refreshing would rotate (invalidate) Claude Code's shared refresh
/// token and force a re-login, and writing would disturb the keychain item's ACL.
/// Because the token is re-read from the keychain on every fetch, Claude Code's own
/// refreshes are picked up automatically; if the token is expired and Claude Code
/// isn't running, the call 401s and we surface "open Claude Code".
final class UsageClient {
    private let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let session = URLSession(configuration: .ephemeral)

    func fetch(completion: @escaping (Result<Usage, UsageError>) -> Void) {
        guard let creds = Keychain.readCredentials() else {
            return DispatchQueue.main.async { completion(.failure(.noCredentials)) }
        }
        getUsage(token: creds.accessToken, completion: completion)
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
}
