import Foundation

final class SpotifyTokenManager {

    struct TokenResponse: Decodable {
        let access_token: String
        let token_type: String
        let expires_in: Int
    }

    private var accessToken: String?
    private var expiresAt: Date?

    func getValidToken() async throws -> String {
        if let token = accessToken,
           let expiresAt,
           Date() < expiresAt {
            
            return token
        }

        return try await fetchAccessToken()
    }

    private func fetchAccessToken() async throws -> String {
        guard
            let clientId = Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_CLIENT_ID") as? String,
            let clientSecret = Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_CLIENT_SECRET") as? String
        else {
            throw NSError(domain: "ConfigError", code: -1)
        }

        let credentials = "\(clientId):\(clientSecret)"
        let base64 = Data(credentials.utf8).base64EncodedString()

        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        request.httpBody = "grant_type=client_credentials"
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "TokenError", code: -1)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        self.accessToken = tokenResponse.access_token
        self.expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))

        return tokenResponse.access_token
    }
}
