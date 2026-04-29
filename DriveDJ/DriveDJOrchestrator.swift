import Foundation
import MusicKit
actor DriveDJOrchestrator {
    private let moodEngine = MoodEngine()
    //private let selector = TrackSelector()
    //private var snapshot = PlaybackSnapshot()
    private let library = LibraryStore()
    //private let spotify = SpotifyWebAPI()
    //private let queueManager = SpotifyQueueManager()
    //private lazy var playbackAPI = SpotifyPlaybackAPI(orchestrator:self)
    private let player = AppleMusicPlaybackService.shared
    private let resolver = AppleMusicResolver()
    private let scheduler = PlaybackScheduler()
    public var viewModel:DriveDJViewModel
    private let cyanite = CyaniteService()
    private let session = DriveSessionManager.shared
    private var lastTrackURI: String?
    private var isStarted = false
    private var recentSongKeys: [String] = []
    private let recentSongLimit = 40

    init(viewModel:DriveDJViewModel) {
        //self.shared = DriveDJOrchestrator(viewModel)
        self.viewModel = viewModel
    }

    func start() async throws{
        guard !isStarted else { return }
        isStarted = true
        scheduler.start(orchestrator: self, session: session)

    }

    func bootstrapLibrary() async throws -> [Song] {
        try await library.load(orchestrator:self)
    }

    func enrichLibrary() async throws -> () {
//        let tracks = try await library.load(orchestrator:self)
//        var enriched = tracks
//
//        for idx in enriched.indices {
//            guard enriched[idx].spotifyID == nil else { continue }
//            if let found = try? await spotify.searchTrack(title: enriched[idx].title, artist: enriched[idx].artist) {
//                enriched[idx].spotifyID = found.id
//            }
  //      }

 //       let spotifyIDs = enriched.compactMap(\.spotifyID)
        //let featureMap = try await spotify.audioFeatures(trackIDs: spotifyIDs)

//        for idx in enriched.indices {
//            guard let spotifyID = enriched[idx].spotifyID,
//                  let feature = featureMap[spotifyID] else { continue }
//            enriched[idx].bpm = feature.tempo
//            enriched[idx].energy = feature.energy
//            enriched[idx].valence = feature.valence
//        }

//        for idx in enriched.indices {
//            guard enriched[idx].appleMusicID == nil else { continue }
//            if let song = try? await AppleMusicResolver().resolveSong(title: enriched[idx].title, artist: enriched[idx].artist) {
//                enriched[idx].appleMusicID = song.id.rawValue
//            }
//        }
//
//        await library.replaceAll(enriched)
//        return enriched
    }

    func nextSetlist(for state: DriveState, current: TrackRecord?, limit: Int = 12) async throws -> (DriveMood, [TrackRecord]) {
        let mood = moodEngine.mood(for: state)
        let tracks = try await library.load(orchestrator: self, desiredCount: limit)
        //let items = selector.buildSetlist(mood: mood, currentTrack: current, library: tracks, count: limit)
        return (mood, tracks.map{TrackRecord(title:$0.title, artist:$0.artistName)})
    }

    func playSetlist(for state: DriveState, current: TrackRecord?) async throws -> (DriveMood, [TrackRecord]) {
        try await start()
        let result = try await nextSetlist(for: state, current: current)
//        let ids = result.setlist.compactMap(\.spotifyID)
//
//        await queueManager.setQueue(ids)
//
//        guard let first = await queueManager.nextTrackID() else {
//            return result
//        }
//
//        try await playbackAPI.play(trackID: first)
//
//         最初の数曲は先に Spotify に積む
//        for _ in 0..<2 {
//            if let next = await queueManager.nextTrackID() {
//                //try await playbackAPI.addToQueue(trackID: next)
//                try await appendQueue(trackID: next)
//            }
//        }
        guard let current else {return result}
        try await viewModel.addSetList(track:current)
        //try await start()
        return result
    }

    func handleTrackChanged(trackURI: String) async throws{
//        let currentID = Self.normalizeSpotifyTrackID(trackURI)
//        let track = try await self.spotify.fetchTrack(trackID: currentID)
//        guard let track else { return }
//        guard let artist = track.artists.first?.name else { return }
//        await viewModel.changeCurrentTrack(track: TrackRecord(title: track.name, artist: artist))
//        guard currentID != lastTrackURI else { return }
//
//        lastTrackURI = currentID
//        await ensureUpcomingTrackQueued()
    }

    private func ensureUpcomingTrackQueued() async {
//        do {
//            if await queueManager.remainingCount() < 2 {
//                let state = await session.currentState()
//                let result = try await nextSetlist(for: state, current: nil, limit: 12)
//                for track in result.setlist {
//                    try await viewModel.addSetList(track:track)
//                }
//                let ids = result.setlist.compactMap(\.spotifyID)
//                await queueManager.setQueue(ids)
//            }
//
//            guard let nextID = await queueManager.nextTrackID() else { return }
//            try await appendQueue(trackID: nextID)
//        } catch {
//            print("ensureUpcomingTrackQueued error:", error)
//        }
    }

    func appendQueue(song:Song) async throws {
        //try await playbackAPI.addToQueue(trackID: trackID)
        await player.appendQueue(song : song)
    }

    private static func normalizeSpotifyTrackID(_ uri: String) -> String {
        uri.replacingOccurrences(of: "spotify:track:", with: "")
    }
    func fetchRecommendations(
        seedArtistId: String,
        targetEnergy: Double,
        targetTempo: Double,
        desiredCount: Int = 8
    ) async throws -> [Song] {
        let _ = seedArtistId
        let mood = await viewModel.snapshot.mood
        let upcomingTracks = await viewModel.upcomingTracks
        let currentTrack = await viewModel.currentTrack
        var excludedTitles = upcomingTracks.map(\.title)
        if let currentTrack {
            excludedTitles.append(currentTrack.title)
        }

        let candidates = try await cyanite.fetchCandidates(
            targetEnergy: targetEnergy,
            targetTempo: targetTempo,
            mood: mood,
            decade: CyaniteDecade.s90s,
            style: TrackStyle.rock,
            excludedTitles: excludedTitles,
            desiredCount: max(desiredCount * 3, 24)
        )

        await MainActor.run {
            DriveDJViewModel.debugText = "mood: \(mood.rawValue) • fetched: \(candidates.count)"
        }

        var excludedSongKeys = Set(upcomingTracks.map { Self.trackKey(title: $0.title, artist: $0.artist) })
        if let currentTrack {
            excludedSongKeys.insert(Self.trackKey(title: currentTrack.title, artist: currentTrack.artist))
        }

        var songs: [Song] = []
        var seenKeys = excludedSongKeys.union(recentSongKeys)

        for candidate in candidates {
            await MainActor.run {
                DriveDJViewModel.debugText = "title: \(candidate.title) • fetched: \(candidates.count)"
            }
            guard let song = try await resolver.resolveSong(from: candidate) else { continue }
            let key = Self.trackKey(title: song.title, artist: song.artistName)
            guard seenKeys.insert(key).inserted else { continue }
            songs.append(song)
            if songs.count == desiredCount {
                break
            }
        }

        if songs.isEmpty {
            seenKeys = excludedSongKeys
            for candidate in candidates {
                guard let song = try await resolver.resolveSong(from: candidate) else { continue }
                let key = Self.trackKey(title: song.title, artist: song.artistName)
                guard seenKeys.insert(key).inserted else { continue }
                songs.append(song)
                if songs.count == desiredCount {
                    break
                }
            }
        }

        rememberSongs(songs)

        let preview = songs.prefix(3).map { "\($0.title) - \($0.artistName)" }.joined(separator: "\n")
        await MainActor.run {
            DriveDJViewModel.debugText = preview.isEmpty ? "No unique songs resolved" : preview
        }

        return songs
    }

    private func rememberSongs(_ songs: [Song]) {
        recentSongKeys.append(contentsOf: songs.map { Self.trackKey(title: $0.title, artist: $0.artistName) })
        if recentSongKeys.count > recentSongLimit {
            recentSongKeys.removeFirst(recentSongKeys.count - recentSongLimit)
        }
    }

    private static func trackKey(title: String, artist: String) -> String {
        "\(normalized(title))|\(normalized(artist))"
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
