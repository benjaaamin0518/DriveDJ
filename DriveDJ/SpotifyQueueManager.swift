import Foundation

actor SpotifyQueueManager {
    private var queue: [String] = []   // Spotify track ID の配列
    private var cursor: Int = 0

    func setQueue(_ trackIDs: [String]) {
        queue = trackIDs
        cursor = 0
    }

    func append(_ trackID: String) {
        queue.append(trackID)
    }

    func nextTrackID() -> String? {
        guard cursor < queue.count else { return nil }
        defer { cursor += 1 }
        return queue[cursor]
    }

    func peekNextTrackID() -> String? {
        guard cursor < queue.count else { return nil }
        return queue[cursor]
    }

    func reset() {
        queue.removeAll()
        cursor = 0
    }

    func remainingCount() -> Int {
        max(queue.count - cursor, 0)
    }
}
