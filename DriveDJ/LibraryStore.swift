import Foundation
import Combine

actor LibraryStore {
    private let fileName = "track-library.json"
    private var cache: [TrackRecord] = []
    //let snapshot = PlaybackSnapshot()
    //private let viewModel = DriveDJViewModel()
    var session = DriveSessionManager.shared
    
    init() {
        //cache = Self.defaultSeedTracks()
    }

     func  load() async throws -> [TrackRecord] {
//        if !cache.isEmpty { return cache }
//        if let loaded = Self.readFromDisk(fileName: fileName), !loaded.isEmpty {
//            cache = loaded
//            return loaded
//        }
         var orchestrator = DriveDJOrchestrator()
         let state = await session.currentState()
         cache = Self.defaultSeedTracks()
         await MainActor.run {
             DriveSessionManager.shared.speedKPH = 50
         }
         //let result = try await orchestrator.nextSetlist(for: state, current:nil)
         //let tracks: [TrackRecord?] = [try await session.fetchNextTrack(mood: snapshot.mood)]
         //cache = tracks.compactMap { $0 }
        return cache
    }

    func save(_ tracks: [TrackRecord]) {
        cache = tracks
        Self.writeToDisk(tracks, fileName: fileName)
    }

    func upsert(_ track: TrackRecord) async throws {
        var current = try await load()
        if let idx = current.firstIndex(where: { $0.id == track.id }) {
            current[idx] = track
        } else {
            current.append(track)
        }
        save(current)
    }

    func replaceAll(_ tracks: [TrackRecord]) {
        save(tracks)
    }

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
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
