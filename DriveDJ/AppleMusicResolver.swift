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
    func resolveSong(from candidate: CyaniteSearchCandidate) async throws -> Song? {
        try await requestAuthorization()
        let query = candidate.title

        var request = MusicCatalogSearchRequest(
            term: query,
            types: [Song.self]
        )
        request.limit = 25

        let response = try await request.response()
        let normalizedQuery = Self.normalized(query)

        let exactMatch = response.songs.first { song in
            Self.normalized(song.title) == normalizedQuery
        }
        if let exactMatch {
            return exactMatch
        }

        let containsMatch = response.songs.first { song in
            let title = Self.normalized(song.title)
            return title.contains(normalizedQuery) || normalizedQuery.contains(title)
        }
        if let containsMatch {
            return containsMatch
        }

        return response.songs.first
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

private extension AppleMusicResolver {
    static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
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
