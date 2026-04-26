import Foundation
import MusicKit
actor DriveDJOrchestrator {
    //static let shared = DriveDJOrchestrator()
    private let moodEngine = MoodEngine()
    private let selector = TrackSelector()
    private let library = LibraryStore()
    private let spotify = SpotifyWebAPI()
    private let appleMusic = AppleMusicPlaybackService.shared
    let scheduler = PlaybackScheduler()
    var session = DriveSessionManager.shared
    
    init () {
        scheduler.start(
            orchestrator: self,
            session: session
        )
    }

    func bootstrapLibrary() async throws -> [TrackRecord] {
        try await library.load()
    }

    func enrichLibrary() async throws -> [TrackRecord] {
        let tracks = try await library.load()
        var enriched = tracks

        // 1) Resolve Spotify track IDs and audio features
        for idx in enriched.indices {
            guard enriched[idx].spotifyID == nil else { continue }
            if let found = try? await spotify.searchTrack(title: enriched[idx].title, artist: enriched[idx].artist) {
                enriched[idx].spotifyID = found.id
            }
        }

        let spotifyIDs = enriched.compactMap(\.spotifyID)
        let featureMap = try await spotify.audioFeatures(trackIDs: spotifyIDs)

        for idx in enriched.indices {
            guard let spotifyID = enriched[idx].spotifyID,
                  let feature = featureMap[spotifyID] else { continue }
            enriched[idx].bpm = feature.tempo
            enriched[idx].energy = feature.energy
            enriched[idx].valence = feature.valence
        }

        // 2) Resolve Apple Music IDs
        for idx in enriched.indices {
            guard enriched[idx].appleMusicID == nil else { continue }
            if let song = try? await AppleMusicResolver().resolveSong(title: enriched[idx].title, artist: enriched[idx].artist) {
                enriched[idx].appleMusicID = song.id.rawValue
            }
        }

        await library.replaceAll(enriched)
        return enriched
    }

    func nextSetlist(for state: DriveState, current: TrackRecord?, limit: Int = 12) async throws -> (mood: DriveMood, setlist: [TrackRecord]) {
        let mood = moodEngine.mood(for: state)
        let tracks = try await library.load()
        let items = selector.buildSetlist(mood: mood, currentTrack: current, library: tracks, count: limit)
        return (mood, items.map(\.track))
    }

    func playSetlist(for state: DriveState, current: TrackRecord?) async throws -> (DriveMood, [TrackRecord]) {
        let result = try await nextSetlist(for: state, current: current)
        try await appleMusic.play(records: result.setlist)
        return result
    }
}
