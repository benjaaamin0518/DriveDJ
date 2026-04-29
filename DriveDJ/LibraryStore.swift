import Foundation
import Combine
import MusicKit
actor LibraryStore {
    private let fileName = "track-library.json"
    private var cache: [Song] = []
    //private var snapshot = PlaybackSnapshot()
    private let moodEngine = MoodEngine()
    //private let viewModel = DriveDJViewModel()
    var session = DriveSessionManager.shared
    
    init() {
        //cache = Self.defaultSeedTracks()
    }

    func load(orchestrator:DriveDJOrchestrator, desiredCount: Int = 8) async throws -> [Song] {
//        if !cache.isEmpty { return cache }
//        if let loaded = Self.readFromDisk(fileName: fileName), !loaded.isEmpty {
//            cache = loaded
//            return loaded
//        }
        // var orchestrator = DriveDJOrchestrator()
         
         //cache = Self.defaultSeedTracks()
        await MainActor.run {
            if DriveSessionManager.shared.speedKPH == 0 {
                DriveSessionManager.shared.speedKPH = 80
            }
        }

        let state = await session.currentState()
        let mood = await moodEngine.mood(for: state)
        let params = await session.targetParams(for: mood)
        let freshTracks = try await orchestrator.fetchRecommendations(
            seedArtistId: "2DaxqgrOhkeH0fpeiQq2f4",
            targetEnergy: params.energy,
            targetTempo: params.tempo,
            desiredCount: max(desiredCount, 6)
        )

        cache = mergeUniqueSongs(freshTracks + cache)
        return Array(cache.prefix(desiredCount))
    }

//    func save(_ tracks: [Song]) {
//        cache = tracks
//        Self.writeToDisk(tracks, fileName: fileName)
//    }

//    func upsert(_ track: TrackRecord) async throws {
//        var current = try await load()
//        if let idx = current.firstIndex(where: { $0.id == track.id }) {
//            current[idx] = track
//        } else {
//            current.append(track)
//        }
//        save(current)
//    }

//    func replaceAll(_ tracks: [TrackRecord]) {
//        save(tracks)
//    }

    private static func defaultSeedTracks() -> [TrackRecord] {
        [
            TrackRecord(title: "Wonderwall", artist: "Oasis", tags: ["britpop", "anthem", "drive"]),
            TrackRecord(title: "No Surprises", artist: "Radiohead", tags: ["chill", "dream", "night"]),
            TrackRecord(title: "Sometimes", artist: "My Bloody Valentine", tags: ["shoegaze", "dream", "ambient"]),
            TrackRecord(title: "Lucky", artist: "Radiohead", tags: ["alt", "uplift", "mid"]),
            TrackRecord(title: "Champagne Supernova", artist: "Oasis", tags: ["rock", "end", "outro"]),
            TrackRecord(title: "Driver's High", artist: "L'Arc-en-Ciel", tags: ["drive", "peak", "rock"]),
            TrackRecord(title: "Sonic Reducer", artist: "The Dead Boys", tags: ["rock", "energetic"]),
            TrackRecord(title: "Kimi to Iu Hana", artist: "Asian Kung-Fu Generation", tags: ["indie", "mid", "drive"]),
            TrackRecord(title: "In the Aeroplane Over the Sea", artist: "Neutral Milk Hotel", tags: ["chill", "mid"]),
            TrackRecord(title: "My Iron Lung", artist: "Radiohead", tags: ["alt", "peak", "energetic"])
        ]
    }

    private static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private static func fileURL(fileName: String) -> URL {
        documentsDirectory().appendingPathComponent(fileName)
    }

    private static func readFromDisk(fileName: String) -> [TrackRecord]? {
        let url = fileURL(fileName: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([TrackRecord].self, from: data)
    }

    private static func writeToDisk(_ tracks: [TrackRecord], fileName: String) {
        let url = fileURL(fileName: fileName)
        guard let data = try? JSONEncoder.pretty.encode(tracks) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private func mergeUniqueSongs(_ songs: [Song]) -> [Song] {
        var seen = Set<String>()
        return songs.filter { song in
            seen.insert(Self.songKey(song)).inserted
        }
    }

    private static func songKey(_ song: Song) -> String {
        "\(normalized(song.title))|\(normalized(song.artistName))"
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
