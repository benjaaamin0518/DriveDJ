import Foundation
class PlaybackPositionManager {
    private var startDate: Date?
    private var accumulatedTime: TimeInterval = 0
    private var isPlaying: Bool = false

    func play() {
        if !isPlaying {
            startDate = Date()
            isPlaying = true
        }
    }

    func pause() {
        if isPlaying, let start = startDate {
            accumulatedTime += Date().timeIntervalSince(start)
            startDate = nil
            isPlaying = false
        }
    }

    func reset() {
        startDate = nil
        accumulatedTime = 0
        isPlaying = false
    }

    func playbackPosition() -> TimeInterval {
        if isPlaying, let start = startDate {
            return accumulatedTime + Date().timeIntervalSince(start)
        } else {
            return accumulatedTime
        }
    }
}
