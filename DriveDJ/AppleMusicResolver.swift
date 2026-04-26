import Foundation
import MusicKit

actor AppleMusicResolver {
    func requestAuthorization() async throws {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            throw AppleMusicResolverError.authorizationDenied
        }
    }

    func resolveSong(title: String, artist: String) async throws -> Song? {
        try await requestAuthorization()

        var request = MusicCatalogSearchRequest(term: "\(title) \(artist)", types: [Song.self])
        request.limit = 10

        let response = try await request.response()

        let best = response.songs.first { song in
            let titleMatch = song.title.localizedCaseInsensitiveContains(title)
            let artistMatch = song.artistName.localizedCaseInsensitiveContains(artist)
            return titleMatch && artistMatch
        }

        return best ?? response.songs.first
    }

    func resolveSongs(records: [TrackRecord]) async throws -> [Song] {
        try await requestAuthorization()

        var results: [Song] = []
        for record in records {
            if let song = try await resolveSong(title: record.title, artist: record.artist) {
                results.append(song)
            }
        }
        return results
    }
}

enum AppleMusicResolverError: LocalizedError {
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Apple Music authorization was denied."
        }
    }
}
