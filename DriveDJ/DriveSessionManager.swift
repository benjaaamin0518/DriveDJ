import Foundation
import CoreLocation
import WeatherKit
import Combine
import MusicKit
@MainActor
final class DriveSessionManager: NSObject, ObservableObject {
    static let shared = DriveSessionManager()

    @Published var speedKPH: Double = 0
    @Published var isNight: Bool = false
    @Published var routeIntensity: Double = 0.25
    @Published var cityDensity: Double = 0.35
    @Published var tripDurationMinutes: Double = 45
    @Published var elapsedMinutes: Double = 0
    @Published var isTripRunning: Bool = false
    @Published private(set) var isCarPlayConnected: Bool = false
    @Published private(set) var weather = WeatherSnapshot()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var timer: Timer?
    private var previousLocation: CLLocation?
    private var lastGeocodeAt: Date?
    private var lastWeatherAt: Date?
    private var lastWeatherLocation: CLLocation?
    private var weatherTask: Task<Void, Never>?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
        locationManager.requestWhenInUseAuthorization()
    }

    var remainingMinutes: Double {
        max(tripDurationMinutes - elapsedMinutes, 0)
    }

    func startTrip() {
        if isTripRunning {
            startLocationUpdatesIfAuthorized()
            return
        }

        isTripRunning = true
        elapsedMinutes = 0
        startLocationUpdatesIfAuthorized()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedMinutes += 1
            self.refreshNightFlag()
        }
    }

    func stopTrip() {
        isTripRunning = false
        timer?.invalidate()
        timer = nil
        if !isCarPlayConnected {
            locationManager.stopUpdatingLocation()
        }
    }

    func setCarPlayConnected(_ isConnected: Bool) {
        isCarPlayConnected = isConnected
        if isConnected {
            startTrip()
        } else if !isTripRunning {
            locationManager.stopUpdatingLocation()
        }
    }

    func refreshNightFlag() {
        let hour = Calendar.current.component(.hour, from: Date())
        isNight = (hour >= 19 || hour <= 5)
    }

    func currentState() -> DriveState {
        DriveState(
            speedKPH: speedKPH,
            isNight: isNight,
            remainingMinutes: remainingMinutes,
            routeIntensity: routeIntensity,
            cityDensity: cityDensity,
            weatherSeverity: weather.severity
        )
    }

    private func startLocationUpdatesIfAuthorized() {
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    private func updateDerivedMetrics(for location: CLLocation) {
        let speed = max(location.speed, 0) * 3.6
        speedKPH = speed

        let headingDeltaFactor: Double
        let accelerationFactor: Double

        if let previousLocation {
            let timeDelta = max(location.timestamp.timeIntervalSince(previousLocation.timestamp), 1)
            let previousSpeed = max(previousLocation.speed, 0) * 3.6
            let acceleration = abs(speed - previousSpeed) / timeDelta
            accelerationFactor = min(acceleration / 12, 1)

            if location.course >= 0, previousLocation.course >= 0 {
                let delta = abs(location.course - previousLocation.course).truncatingRemainder(dividingBy: 360)
                let normalizedDelta = min(delta, 360 - delta)
                headingDeltaFactor = min(normalizedDelta / 90, 1)
            } else {
                headingDeltaFactor = 0
            }
        } else {
            accelerationFactor = 0
            headingDeltaFactor = 0
        }

        let speedFactor = min(speed / 110, 1)
        routeIntensity = min((speedFactor * 0.45) + (accelerationFactor * 0.35) + (headingDeltaFactor * 0.20), 1)
        previousLocation = location
    }

    private func refreshCityDensity(for location: CLLocation) {
        if geocoder.isGeocoding {
            return
        }

        if let lastGeocodeAt, Date().timeIntervalSince(lastGeocodeAt) < 300 {
            return
        }

        lastGeocodeAt = Date()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            let placemark = placemarks?.first
            let hasUrbanPlacemark = placemark?.locality != nil || placemark?.subLocality != nil
            let hasRoad = placemark?.thoroughfare != nil

            Task { @MainActor in
                self.cityDensity = hasUrbanPlacemark ? 0.70 : (hasRoad ? 0.45 : 0.20)
            }
        }
    }

    private func refreshWeatherIfNeeded(for location: CLLocation) {
        guard #available(iOS 16.0, *) else {
            weather = WeatherSnapshot(condition: "WeatherKit requires iOS 16", symbolName: "cloud.slash")
            return
        }

        if weatherTask != nil {
            return
        }

        let recentlyFetched = lastWeatherAt.map { Date().timeIntervalSince($0) < 600 } ?? false
        let movedEnough = lastWeatherLocation.map { location.distance(from: $0) >= 5_000 } ?? true

        if recentlyFetched && !movedEnough {
            return
        }

        weatherTask = Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor in
                    self.weatherTask = nil
                }
            }

            do {
                let weatherService = WeatherService.shared
                let current = try await weatherService.weather(for: location, including: .current)
                let precipitationKPH = current.precipitationIntensity.converted(to: .kilometersPerHour).value
                let windKPH = current.wind.speed.converted(to: .kilometersPerHour).value
                let p = min(max(precipitationKPH, 0.0), 12.0) / 12.0 * 0.55
                let w = min(max(windKPH, 0.0), 80.0) / 80.0 * 0.25
                let c = min(max(current.cloudCover, 0.0), 1.0) * 0.20

                let severity = min(p + w + c, 1.0)

                await MainActor.run {
                    self.lastWeatherAt = Date()
                    self.lastWeatherLocation = location
                    self.weather = WeatherSnapshot(
                        condition: String(describing: current.condition),
                        symbolName: current.symbolName,
                        temperatureC: current.temperature.converted(to: .celsius).value,
                        precipitationKPH: precipitationKPH,
                        windKPH: windKPH,
                        severity: severity
                    )
                }
            } catch {
                await MainActor.run {
                    self.lastWeatherAt = Date()
                    self.lastWeatherLocation = location
                    self.weather = WeatherSnapshot(
                        condition: "Weather unavailable",
                        symbolName: "cloud.slash",
                        temperatureC: nil,
                        precipitationKPH: nil,
                        windKPH: nil,
                        severity: 0
                    )
                }
            }
        }
    }
    func targetParams(for mood: DriveMood) -> (energy: Double, tempo: Double) {
        switch mood {
        case .chill:
            return (0.3, 70)
        case .mid:
            return (0.5, 90)
        case .up:
            return (0.7, 110)
        case .peak:
            return (0.9, 130)
        case .end:
            return (0.4, 80)
        }
    }
    func findAppleMusicId(title: String, artist: String) async throws -> String?  {
        let request = MusicCatalogSearchRequest(
            term: "\(artist) \(title)",
            types: [Song.self]
        )

        let response = try await request.response()
        return response.songs.first?.id.rawValue
    }
    func fetchNextTrack(mood: DriveMood) async throws -> TrackRecord? {

        let spotify = SpotifyWebAPI()

        let params = targetParams(for: mood)

        // とりあえずseed（Oasisとか）
        let seedArtistId = "2DaxqgrOhkeH0fpeiQq2f4" // Oasis

        guard let tracks = try? await spotify.fetchRecommendations(
            seedArtistId: seedArtistId,
            targetEnergy: params.energy,
            targetTempo: params.tempo
        ) else {
            return nil
        }

        for item in tracks {
            let title = item.name
            let artist = item.artists.first?.name ?? ""

            let appleId = try await findAppleMusicId(title: title, artist: artist)

            if let appleId {
                return TrackRecord(
                    title: title,
                    artist: artist,
                    tags: [],
                )
            }
        }

        return nil
    }
}

extension DriveSessionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        updateDerivedMetrics(for: location)
        refreshCityDensity(for: location)
        refreshWeatherIfNeeded(for: location)
        refreshNightFlag()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            startLocationUpdatesIfAuthorized()
        }
    }
}
