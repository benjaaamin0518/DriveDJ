import Foundation

enum DriveMood: String, CaseIterable, Codable {
    case chill = "CHILL"
    case mid = "MID"
    case up = "UP"
    case peak = "PEAK"
    case end = "END"
}

enum MusicOriginPreference: String, CaseIterable, Codable, Identifiable {
    case japanese
    case western
    case mixed

    var id: Self { self }

    var displayName: String {
        switch self {
        case .japanese:
            return "邦楽"
        case .western:
            return "洋楽"
        case .mixed:
            return "両方"
        }
    }
}

enum MusicStylePreference: String, CaseIterable, Codable, Identifiable {
    case auto
    case rock
    case ballad
    case mixed
    case anison
    case cityPop

    var id: Self { self }

    var displayName: String {
        switch self {
        case .auto:
            return "自動"
        case .rock:
            return "ロック"
        case .ballad:
            return "バラード"
        case .mixed:
            return "ミックス"
        case .anison:
            return "アニソン"
        case .cityPop:
            return "CityPop"
        }
    }

    var cyaniteStyle: TrackStyle {
        switch self {
        case .auto:
            return .auto
        case .rock:
            return .rock
        case .ballad:
            return .ballad
        case .mixed:
            return .mixed
        case .anison:
            return .anison
        case .cityPop:
            return .cityPop
        }
    }
}

enum MusicDecadePreference: String, CaseIterable, Codable, Identifiable {
    case all
    case s70s
    case s80s
    case s90s
    case s2000s
    case s2010s
    case s2020s

    var id: Self { self }

    var displayName: String {
        switch self {
        case .all:
            return "すべて"
        case .s70s:
            return "70年代"
        case .s80s:
            return "80年代"
        case .s90s:
            return "90年代"
        case .s2000s:
            return "2000年代"
        case .s2010s:
            return "2010年代"
        case .s2020s:
            return "2020年代"
        }
    }

    var cyaniteDecade: CyaniteDecade? {
        switch self {
        case .all:
            return nil
        case .s70s:
            return .s70s
        case .s80s:
            return .s80s
        case .s90s:
            return .s90s
        case .s2000s:
            return .s2000s
        case .s2010s:
            return .s2010s
        case .s2020s:
            return .s2020s
        }
    }
}

struct DriveState: Codable, Equatable {
    var speedKPH: Double
    var isNight: Bool
    var remainingMinutes: Double
    var routeIntensity: Double   // 0.0 ... 1.0
    var cityDensity: Double      // 0.0 ... 1.0
    var weatherSeverity: Double  // 0.0 ... 1.0
}

struct WeatherSnapshot: Codable, Equatable {
    var condition: String = "Unavailable"
    var symbolName: String = "cloud.slash"
    var temperatureC: Double?
    var precipitationKPH: Double?
    var windKPH: Double?
    var severity: Double = 0
}

struct TrackRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var artist: String
    var spotifyID: String?
    var appleMusicID: String?
    var bpm: Double?
    var energy: Double?
    var valence: Double?
    var tags: [String]

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        spotifyID: String? = nil,
        appleMusicID: String? = nil,
        bpm: Double? = nil,
        energy: Double? = nil,
        valence: Double? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.spotifyID = spotifyID
        self.appleMusicID = appleMusicID
        self.bpm = bpm
        self.energy = energy
        self.valence = valence
        self.tags = tags
    }
}

struct SetlistItem: Identifiable, Hashable {
    let id = UUID()
    let track: TrackRecord
    let score: Double
}

struct PlaybackSnapshot: Codable, Equatable {
    var mood: DriveMood = .mid
    var currentTitle: String = "—"
    var currentArtist: String = "—"
    var status: String = "Ready"
    var queueCount: Int = 0
}
