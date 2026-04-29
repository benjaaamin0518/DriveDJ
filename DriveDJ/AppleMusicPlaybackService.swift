import Foundation
import MusicKit

actor AppleMusicPlaybackService {
    static let shared = AppleMusicPlaybackService()
    let tracker = PlaybackPositionManager()
    private let player = ApplicationMusicPlayer.shared
    private let resolver = AppleMusicResolver()

    func authorizeIfNeeded() async throws {
        let status = await MusicAuthorization.request()
        guard status == .authorized else {
            throw AppleMusicPlaybackError.authorizationDenied
        }
    }

    func play(records: [TrackRecord]) async throws {
        try await authorizeIfNeeded()

        let songs = try await resolver.resolveSongs(records: records)
        guard !songs.isEmpty else {
            throw AppleMusicPlaybackError.noResolvableSongs
        }

        player.queue = ApplicationMusicPlayer.Queue(for: songs)
        try await player.play()
        tracker.play()
    }

    func play(record: TrackRecord) async throws {
        try await play(records: [record])
    }

    func pause() async {
        await player.pause()
        tracker.pause()
    }
    
    func appendQueue(song:Song) async {
        let currentEntry = player.queue.currentEntry
        let entries = player.queue.entries

        let currentIndex = entries.firstIndex { $0.id == currentEntry?.id } ?? 0

        let kept = Array(player.queue.entries.prefix(currentIndex + 1))
        let keptSongs = kept.compactMap { $0.item as? Song }
        // 追加したい曲
        let newSongs: [Song] = [song]

        // 新しいキューを作る
        let newQueue = keptSongs.map { $0 } + newSongs

        // 再セット
        player.queue = .init(for: newQueue)
    }


    func togglePlayPause() async throws {
        if player.state.playbackStatus == .playing {
            await player.pause()
            tracker.pause()
        } else {
            try await player.play()
            tracker.play()
        }
    }

    func playbackPosition() -> TimeInterval {
        tracker.playbackPosition()
    }

    func isPlaying() -> Bool {
        player.state.playbackStatus == .playing
    }
}

enum AppleMusicPlaybackError: LocalizedError {
    case authorizationDenied
    case noResolvableSongs

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Apple Music authorization denied."
        case .noResolvableSongs:
            return "No Apple Music songs could be resolved from the current setlist."
        }
    }
}
