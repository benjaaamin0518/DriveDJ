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
