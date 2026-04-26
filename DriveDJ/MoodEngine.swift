import Foundation

struct MoodEngine {
    func mood(for state: DriveState) -> DriveMood {
        if state.remainingMinutes <= 8 { return .end }

        let speedScore: Double
        switch state.speedKPH {
        case ..<25: speedScore = 0.10
        case 25..<50: speedScore = 0.28
        case 50..<75: speedScore = 0.55
        case 75..<100: speedScore = 0.78
        default: speedScore = 0.95
        }

        let routeScore = min(max(state.routeIntensity, 0.0), 1.0) * 0.25
        let cityScore = min(max(state.cityDensity, 0.0), 1.0) * 0.15
        let weatherScore = min(max(state.weatherSeverity, 0.0), 1.0) * 0.12
        let nightScore = state.isNight ? 0.15 : 0.0

        let total = speedScore + routeScore + cityScore + weatherScore + nightScore

        switch total {
        case ..<0.28: return .chill
        case ..<0.48: return .mid
        case ..<0.75: return .up
        default: return .peak
        }
    }
}
