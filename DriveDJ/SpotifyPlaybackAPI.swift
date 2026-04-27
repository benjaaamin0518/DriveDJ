import Foundation


struct SpotifyTrackDTO: Decodable {
    let id: String
    let name: String
}

final class SpotifyPlaybackAPI {
    let tokenProvider: SpotifyOAuthManager
    var orchestrator: DriveDJOrchestrator


    init(orchestrator:DriveDJOrchestrator) {
        self.tokenProvider = SpotifyOAuthManager()
        self.orchestrator = orchestrator
        
    }

    func play(trackID: String, deviceID: String? = nil) async throws {
        let token = try await tokenProvider.currentAccessToken()
        let spotifyManager = SpotifyPlaybackManager(orchestrator:orchestrator)
        //var spotifyAuthManager = SpotifyAuthManager(playbackManager:spotifyManager)
        var spotifyAuthManager = SpotifyAuthManager.share
        spotifyAuthManager.startAuth(spotifyManager:spotifyManager, trackId:trackID)
        try await orchestrator.start()

        var components = URLComponents(string: "https://api.spotify.com/v1/me/player/play")!
        if let deviceID {
            components.queryItems = [.init(name: "device_id", value: deviceID)]
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "uris": ["spotify:track:\(trackID)"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func addToQueue(trackID: String, deviceID: String? = nil) async throws {
        let token = try await tokenProvider.currentAccessToken()

        var components = URLComponents(string: "https://api.spotify.com/v1/me/player/queue")!
        var items = [URLQueryItem(name: "uri", value: "spotify:track:\(trackID)")]
        if let deviceID {
            items.append(URLQueryItem(name: "device_id", value: deviceID))
        }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func skipToNext(deviceID: String? = nil) async throws {
        let token = try await tokenProvider.currentAccessToken()

        var components = URLComponents(string: "https://api.spotify.com/v1/me/player/next")!
        if let deviceID {
            components.queryItems = [.init(name: "device_id", value: deviceID)]
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func getCurrentQueue() async throws -> [SpotifyTrackDTO] {
        let token = try await tokenProvider.currentAccessToken()

        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/queue")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // 実際のレスポンスは current item + queue の形なので、必要に応じてDTOを追加してください
        print(String(data: data, encoding: .utf8) ?? "")
        return []
    }
}
