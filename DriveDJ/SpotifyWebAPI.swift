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
    private let oauth: SpotifyTokenManager
    private let cyanite = CyaniteService()
    private var snapshot = PlaybackSnapshot()
    init(oauth: SpotifyTokenManager = SpotifyTokenManager()) {
        self.oauth = oauth
    }

    func searchTrack(title: String, artist: String) async throws -> SpotifyTrack? {
        let token = try await oauth.getValidToken()
        var components = URLComponents(string: "https://api.spotify.com/v1/search")!
        components.queryItems = [
            .init(name: "q", value: "\(title) \(artist)"),
            .init(name: "type", value: "track"),
            .init(name: "limit", value: "5"),
            .init(name: "scope", value: "user-read-private user-modify-playback-state")
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

        let token = try await oauth.getValidToken()
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
    /// Spotify track ID から title / artist を取得
     func fetchTrack(trackID: String, market: String? = nil) async throws -> SpotifyTrack? {
         let token = try await oauth.getValidToken()

         var components = URLComponents(string: "https://api.spotify.com/v1/tracks/\(trackID)")!
         if let market {
             components.queryItems = [
                 .init(name: "market", value: market)
             ]
         }

         var request = URLRequest(url: components.url!)
         request.httpMethod = "GET"
         request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

         let (data, response) = try await URLSession.shared.data(for: request)
         guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
             print(String(data: data, encoding: .utf8) ?? "no body")
             throw URLError(.badServerResponse)
         }

         return try JSONDecoder().decode(SpotifyTrack.self, from: data)
     }

     /// title / artist を分けて取り出すための便利メソッド
     func fetchTitleAndArtist(trackID: String) async throws -> (title: String, artist: String)? {
         guard let track = try await fetchTrack(trackID: trackID) else { return nil }
         let artist = track.artists.first?.name ?? ""
         return (title: track.name, artist: artist)
     }
//    func fetchRecommendations(
//        seedArtistId: String,
//        targetEnergy: Double,
//        targetTempo: Double
//    ) async throws -> [SpotifyTrack] {
//
//        let urlString =
//        "https://api.spotify.com/v1/recommendations?" +
//        "target_energy=\(targetEnergy)&" +
//        "target_tempo=\(targetTempo)&" +
//        "limit=20"
//
//        let url = URL(string: urlString)!
//
//        var request = URLRequest(url: url)
//        let token = try await oauth.currentAccessToken()
//        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//
//        let (data, _) = try await URLSession.shared.data(for: request)
//        await MainActor.run{
//            print(token)
//            DriveDJViewModel.debugText  = "url: \(url)\n token: \(token)"
//        }
//        let decoded = try JSONDecoder().decode(SpotifyRecommendationResponse.self, from: data)
//        return decoded.tracks
//    }
    func fetchRecommendations(
        seedArtistId: String,
        targetEnergy: Double,
        targetTempo: Double
    ) async throws -> [SpotifyTrack] {
        let result = try await cyanite.fetchCandidates(targetEnergy:targetEnergy, targetTempo:targetTempo,mood:snapshot.mood, decade:CyaniteDecade.s90s,style:TrackStyle.rock, randomOffset: 51)
        guard let track = result.first else {return []}
        await MainActor.run{
                DriveDJViewModel.debugText = "result: \(track.title)"
            }
        guard let spotifyTrack = try await searchTrack(title: track.title, artist: "") else {return []}
        await MainActor.run{
            DriveDJViewModel.debugText = "result: \(spotifyTrack.id)"
            print(spotifyTrack.id)
        }
        
        return [spotifyTrack]
    }
}
