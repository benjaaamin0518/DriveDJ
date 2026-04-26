import MusicKit

class PlaybackScheduler {

    private var task: Task<Void, Never>?
    let snapshot = PlaybackSnapshot()
    func start(
        orchestrator: DriveDJOrchestrator,
        session: DriveSessionManager
    ) {

        let player = ApplicationMusicPlayer.shared

        // 既存タスク停止
        task?.cancel()

        task = Task {
            while !Task.isCancelled {

                // 再生中かチェック
                if player.state.playbackStatus == .playing {

                    let state = await session.currentState()

                    do {
                        let result = try await orchestrator.nextSetlist(
                            for: state,
                            current: nil
                        )

                        let tracks: [TrackRecord?] = [
                            try await session.fetchNextTrack(mood: snapshot.mood)
                        ]

                        let cache = tracks.compactMap { $0 }

                        print("更新:", cache)

                    } catch {
                        print("エラー:", error)
                    }
                }

                // 1分待つ
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
