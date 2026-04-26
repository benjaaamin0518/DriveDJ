import Foundation

struct SpotifySearchResponse: Decodable {
    struct Tracks: Decodable {
        let items: [SpotifyTrack]
    }

    let tracks: Tracks
}
struct SpotifyRecommendationResponse: Decodable {
    let tracks: [SpotifyTrack]
}
struct SpotifyTrack: Decodable {
    let id: String
    let name: String
    let popularity: Int?
    let artists: [SpotifyArtist]
}

struct SpotifyArtist: Decodable {
    let name: String
}

struct SpotifyAudioFeaturesResponse: Decodable {
    let audio_features: [SpotifyAudioFeature]
}

struct SpotifyAudioFeature: Decodable {
    let id: String
    let tempo: Double
    let energy: Double
    let valence: Double
}

actor SpotifyWebAPI {
    private let oauth: SpotifyOAuthManager

    init(oauth: SpotifyOAuthManager = SpotifyOAuthManager()) {
        self.oauth = oauth
    }

    func searchTrack(title: String, artist: String) async throws -> SpotifyTrack? {
        let token = try await oauth.currentAccessToken()
        var components = URLComponents(string: "https://api.spotify.com/v1/search")!
        components.queryItems = [
            .init(name: "q", value: "\(title) \(artist)"),
            .init(name: "type", value: "track"),
            .init(name: "limit", value: "5")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
        return decoded.tracks.items.first
    }

    func audioFeatures(trackIDs: [String]) async throws -> [String: SpotifyAudioFeature] {
        guard !trackIDs.isEmpty else { return [:] }

        let token = try await oauth.currentAccessToken()
        let ids = trackIDs.joined(separator: ",")
        var components = URLComponents(string: "https://api.spotify.com/v1/audio-features")!
        components.queryItems = [.init(name: "ids", value: ids)]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(SpotifyAudioFeaturesResponse.self, from: data)
        var map: [String: SpotifyAudioFeature] = [:]
        for feature in decoded.audio_features {
            map[feature.id] = feature
        }
        return map
    }
    func fetchRecommendations(
        seedArtistId: String,
        targetEnergy: Double,
        targetTempo: Double
    ) async throws -> [SpotifyTrack] {

        let urlString =
        "https://api.spotify.com/v1/recommendations?" +
        "seed_artists=\(seedArtistId)&" +
        "target_energy=\(targetEnergy)&" +
        "target_tempo=\(targetTempo)&" +
        "limit=20"

        let url = URL(string: urlString)!

        var request = URLRequest(url: url)
        let token = try await oauth.currentAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        let decoded = try JSONDecoder().decode(SpotifyRecommendationResponse.self, from: data)
        return decoded.tracks
    }
}
