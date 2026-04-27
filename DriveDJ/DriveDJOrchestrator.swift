import Foundation
import MusicKit
actor DriveDJOrchestrator {

    private let moodEngine = MoodEngine()
    private let selector = TrackSelector()
    private let library = LibraryStore()
    private let spotify = SpotifyWebAPI()
    private let queueManager = SpotifyQueueManager()
    private lazy var playbackAPI = SpotifyPlaybackAPI(orchestrator:self)
    private let scheduler = PlaybackScheduler()
    public var viewModel:DriveDJViewModel

    private let session = DriveSessionManager.shared

    private var lastTrackURI: String?
    private var isStarted = false

    init(viewModel:DriveDJViewModel) {
        //self.shared = DriveDJOrchestrator(viewModel)
        self.viewModel = viewModel
    }

    func start() async throws{
        guard !isStarted else { return }
        isStarted = true
        scheduler.start(orchestrator: self, session: session)

    }

    func bootstrapLibrary() async throws -> [TrackRecord] {
        try await library.load()
    }

    func enrichLibrary() async throws -> [TrackRecord] {
        let tracks = try await library.load()
        var enriched = tracks

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
        let ids = result.setlist.compactMap(\.spotifyID)

        await queueManager.setQueue(ids)

        guard let first = await queueManager.nextTrackID() else {
            return result
        }

        try await playbackAPI.play(trackID: first)

        // 最初の数曲は先に Spotify に積む
        for _ in 0..<2 {
            if let next = await queueManager.nextTrackID() {
                //try await playbackAPI.addToQueue(trackID: next)
                try await appendQueue(trackID: next)
            }
        }

        return result
    }

    func handleTrackChanged(trackURI: String) async throws{
        let currentID = Self.normalizeSpotifyTrackID(trackURI)
        let track = try await self.spotify.fetchTrack(trackID: currentID)
        guard let track else { return }
        guard let artist = track.artists.first?.name else { return }
        await viewModel.changeCurrentTrack(track: TrackRecord(title: track.name, artist: artist))
        guard currentID != lastTrackURI else { return }

        lastTrackURI = currentID
        await ensureUpcomingTrackQueued()
    }

    private func ensureUpcomingTrackQueued() async {
        do {
            if await queueManager.remainingCount() < 2 {
                let state = await session.currentState()
                let result = try await nextSetlist(for: state, current: nil, limit: 12)
                for track in result.setlist {
                    try await viewModel.addSetList(track:track)
                }
                let ids = result.setlist.compactMap(\.spotifyID)
                await queueManager.setQueue(ids)
            }

            guard let nextID = await queueManager.nextTrackID() else { return }
            try await appendQueue(trackID: nextID)
        } catch {
            print("ensureUpcomingTrackQueued error:", error)
        }
    }

    func appendQueue(trackID: String) async throws {
        try await playbackAPI.addToQueue(trackID: trackID)
    }

    private static func normalizeSpotifyTrackID(_ uri: String) -> String {
        uri.replacingOccurrences(of: "spotify:track:", with: "")
    }
}
