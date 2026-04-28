//import Foundation
//import MusicKit
//struct TrackSelector {
//    func buildSetlist(
//        mood: DriveMood,
//        currentTrack: Song?,
//        library: [Song],
//        count: Int = 12
//    ) -> [SetlistItem] {
//        var remaining = library
//        var result: [SetlistItem] = []
//        var previous = currentTrack
//
//        while result.count < count, !remaining.isEmpty {
//            guard let next = selectNextTrack(mood: mood, currentTrack: previous, pool: remaining) else { break }
//            let score = score(next, mood: mood, currentTrack: previous)
//            result.append(SetlistItem(track: next, score: score))
//            remaining.removeAll { $0.id == next.id }
//            previous = next
//        }
//
//        return result
//    }
//
//    func selectNextTrack(
//        mood: DriveMood,
//        currentTrack: Song?,
//        pool: [Song]
//    ) -> Song? {
//        guard !pool.isEmpty else { return nil }
//
//        let filtered = pool.filter { matchesMood($0, mood: mood) }
//        let candidates = filtered.isEmpty ? pool : filtered
//
//        return candidates.max { lhs, rhs in
//            score(lhs, mood: mood, currentTrack: currentTrack) < score(rhs, mood: mood, currentTrack: currentTrack)
//        }
//    }
//
//    private func matchesMood(_ track: Song, mood: DriveMood) -> Bool {
//        let energy = track.energy ?? 0.5
//        let bpm = track.bpm ?? 100
//
//        switch mood {
//        case .chill:
//            return energy < 0.48 || bpm < 95 || hasTag(track, ["chill", "ambient", "dream", "shoegaze"])
//        case .mid:
//            return (energy >= 0.35 && energy < 0.7) || hasTag(track, ["indie", "alt", "rock"])
//        case .up:
//            return energy >= 0.6 && bpm >= 100 || hasTag(track, ["anthem", "rock", "drive"])
//        case .peak:
//            return energy >= 0.75 && bpm >= 110 || hasTag(track, ["energetic", "arena", "peak"])
//        case .end:
//            return energy < 0.6 || hasTag(track, ["outro", "closing", "end", "night"])
//        }
//    }
//
//    private func score(_ track: Song, mood: DriveMood, currentTrack: TrackRecord?) -> Double {
//        let energy = track.energy ?? 0.5
//        let bpm = track.bpm ?? 100
//        let valence = track.valence ?? 0.5
//
//        let target: (bpm: Double, energy: Double, valence: Double)
//        switch mood {
//        case .chill: target = (78, 0.30, 0.35)
//        case .mid:   target = (92, 0.48, 0.48)
//        case .up:    target = (118, 0.68, 0.58)
//        case .peak:  target = (132, 0.86, 0.68)
//        case .end:   target = (84, 0.38, 0.42)
//        }
//
//        let bpmGap = abs(bpm - target.bpm)
//        let energyGap = abs(energy - target.energy)
//        let valenceGap = abs(valence - target.valence)
//
//        var continuityBonus = 0.0
//        if let currentTrack {
//            let currentBPM = currentTrack.bpm ?? bpm
//            let currentEnergy = currentTrack.energy ?? energy
//            let bpmDiff = abs(bpm - currentBPM)
//            let energyDiff = abs(energy - currentEnergy)
//
//            continuityBonus += max(0, 20 - bpmDiff) * 0.07
//            continuityBonus += max(0, 0.35 - energyDiff) * 1.2
//        }
//
//        let tagBonus: Double
//        switch mood {
//        case .chill:
//            tagBonus = hasTag(track, ["ambient", "dream", "shoegaze"]) ? 0.9 : 0.0
//        case .mid:
//            tagBonus = hasTag(track, ["indie", "alt", "pop"]) ? 0.7 : 0.0
//        case .up:
//            tagBonus = hasTag(track, ["rock", "anthem", "drive"]) ? 0.8 : 0.0
//        case .peak:
//            tagBonus = hasTag(track, ["energetic", "arena", "peak"]) ? 1.0 : 0.0
//        case .end:
//            tagBonus = hasTag(track, ["outro", "closing", "night"]) ? 0.9 : 0.0
//        }
//
//        let base = 10.0
//        return base
//            - bpmGap * 0.05
//            - energyGap * 2.0
//            - valenceGap * 0.4
//            + continuityBonus
//            + tagBonus
//    }
//
//    private func hasTag(_ track: TrackRecord, _ keywords: [String]) -> Bool {
//        let lowered = track.tags.map { $0.lowercased() }
//        return keywords.contains { keyword in
//            lowered.contains(where: { $0.contains(keyword) })
//        }
//    }
//}
