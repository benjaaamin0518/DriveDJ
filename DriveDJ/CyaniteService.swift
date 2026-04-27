import Foundation

struct CyaniteSearchCandidate: Decodable {
    let id: String
    let title: String
}

struct CyaniteGraphQLResponse<T: Decodable>: Decodable {
    let data: T
}

struct FreeTextSearchData: Decodable {
    let freeTextSearch: FreeTextSearchResult
}

struct FreeTextSearchResult: Decodable {
    let edges: [FreeTextSearchEdge]
}

struct FreeTextSearchEdge: Decodable {
    let node: CyaniteSearchCandidate
}

enum CyaniteDecade: String, CaseIterable {
    case s70s = "1970s"
    case s80s = "1980s"
    case s90s = "1990s"
    case s2000s = "2000s"
    case s2010s = "2010s"
    case s2020s = "2020s"

    var searchWord: String { rawValue }
}

enum TrackStyle: CaseIterable {
    case auto
    case rock
    case ballad
    case mixed
}

actor CyaniteService {
    private let accessToken: String

    init() {
        self.accessToken = AppConfig.cyaneteApiToken
    }

    func fetchCandidates(
        targetEnergy: Double,
        targetTempo: Double,
        mood: DriveMood,
        decade: CyaniteDecade? = nil,
        style: TrackStyle = .auto,
        randomOffset: Int? = nil
    ) async throws -> [CyaniteSearchCandidate] {

        let resolvedStyle = resolveStyle(
            targetEnergy: targetEnergy,
            targetTempo: targetTempo,
            style: style
        )

        let searchText = makeSearchText(
            targetEnergy: targetEnergy,
            targetTempo: targetTempo,
            mood: mood.rawValue,
            decade: decade,
            style: resolvedStyle
        )

        let query = """
        query FreeTextSearch($searchText: String!, $first: Int!) {
          freeTextSearch(
            first: $first
            target: { spotify: {} }
            searchText: $searchText
          ) {
            ... on FreeTextSearchConnection {
              edges {
                node {
                  id
                  title
                }
              }
            }
            ... on FreeTextSearchError {
              code
              message
            }
          }
        }
        """

        let body: [String: Any] = [
            "query": query,
            "variables": [
                "searchText": searchText,
                "first": 50
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.cyanite.ai/graphql")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(CyaniteGraphQLResponse<FreeTextSearchData>.self, from: data)
        let candidates = decoded.data.freeTextSearch.edges.map(\.node).shuffled()

        guard !candidates.isEmpty else { return [] }

        let offset = randomOffset ?? Int.random(in: 0..<candidates.count)
        let normalizedOffset = offset % candidates.count
        let rotated = Array(candidates[normalizedOffset...] + candidates[..<normalizedOffset])

        return rotated
    }

    private func resolveStyle(
        targetEnergy: Double,
        targetTempo: Double,
        style: TrackStyle
    ) -> TrackStyle {
        switch style {
        case .auto:
            if targetEnergy >= 0.75 || targetTempo >= 120 {
                return .rock
            } else if targetEnergy <= 0.45 && targetTempo <= 95 {
                return .ballad
            } else {
                return .mixed
            }
        default:
            return style
        }
    }

    private func makeSearchText(
        targetEnergy: Double,
        targetTempo: Double,
        mood: String,
        decade: CyaniteDecade?,
        style: TrackStyle
    ) -> String {
        let moodWord = mood.lowercased()

        let energyWord: String
        switch targetEnergy {
        case ..<0.35:
            energyWord = ["calm", "quiet", "soft"].randomElement()!
        case ..<0.7:
            energyWord = ["balanced", "steady", "midtempo"].randomElement()!
        default:
            energyWord = ["energetic", "driving", "upbeat"].randomElement()!
        }

        let tempoWord: String
        switch targetTempo {
        case ..<90:
            tempoWord = ["slow", "laid back", "relaxing"].randomElement()!
        case ..<120:
            tempoWord = ["midtempo", "groovy", "flowing"].randomElement()!
        default:
            tempoWord = ["fast", "upbeat", "dynamic"].randomElement()!
        }

        let vocalWord = [
            "vocal song",
            "singer",
            "lyrics",
            "pop song"
        ].randomElement()!

        let styleWord: String
        switch style {
        case .rock:
            styleWord = [
                "rock",
                "alternative rock",
                "anthemic rock",
                "driving rock",
                "indie rock"
            ].randomElement()!
        case .ballad:
            styleWord = [
                "ballad",
                "soft ballad",
                "power ballad",
                "acoustic ballad",
                "emotional ballad"
            ].randomElement()!
        case .mixed:
            styleWord = [
                "song",
                "track",
                "music",
                "driving song",
                "road trip song"
            ].randomElement()!
        case .auto:
            styleWord = "song"
        }

        let decadeWord = decade?.searchWord

        let parts = [
            moodWord,
            energyWord,
            tempoWord,
            styleWord,
            decadeWord,
            vocalWord
        ].compactMap { $0 }

        return parts.joined(separator: " ")
    }
}
