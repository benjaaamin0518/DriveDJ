import Foundation
import Combine

@MainActor
final class DriveDJViewModel: ObservableObject {
    @Published var snapshot = PlaybackSnapshot()
    @Published var library: [TrackRecord] = []
    @Published var currentTrack: TrackRecord?
    @Published var upcomingTracks: [TrackRecord] = []
    @Published var isBusy: Bool = false

    var session = DriveSessionManager.shared

    private let orchestrator = DriveDJOrchestrator()

    func bootstrap() async throws{
        isBusy = true
        defer { isBusy = false }

        library = try await orchestrator.bootstrapLibrary()
        session.refreshNightFlag()
        snapshot.status = "Library loaded"
        snapshot.queueCount = library.count
    }

    func enrichLibrary() async {
        isBusy = true
        defer { isBusy = false }

        do {
            library = try await orchestrator.enrichLibrary()
            snapshot.status = "Library enriched"
            snapshot.queueCount = library.count
        } catch {
            snapshot.status = "Enrichment failed: \(error.localizedDescription)"
        }
    }

    func refreshSetlist() async throws{
        let state = session.currentState()
        let result = try await orchestrator.nextSetlist(for: state, current: currentTrack)
        snapshot.mood = result.mood
        upcomingTracks = result.setlist
        snapshot.queueCount = result.setlist.count

        if let first = result.setlist.first {
            currentTrack = first
            snapshot.currentTitle = first.title
            snapshot.currentArtist = first.artist
            snapshot.status = "Prepared \(result.setlist.count) tracks"
        } else {
            snapshot.status = "No candidate tracks"
        }
    }

    func playPreparedSetlist() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let state = session.currentState()
            let result = try await orchestrator.playSetlist(for: state, current: currentTrack)
            snapshot.mood = result.0
            upcomingTracks = result.1
            snapshot.queueCount = result.1.count
            if let first = result.1.first {
                currentTrack = first
                snapshot.currentTitle = first.title
                snapshot.currentArtist = first.artist
            }
            snapshot.status = "Playing"
        } catch {
            snapshot.status = "Playback failed: \(error.localizedDescription)"
        }
    }

    func toggleTrip() {
        if session.isTripRunning {
            session.stopTrip()
            snapshot.status = "Trip stopped"
        } else {
            session.startTrip()
            snapshot.status = "Trip started"
        }
    }

    func tick() {
        session.refreshNightFlag()
        snapshot.mood = MoodEngine().mood(for: session.currentState())
        snapshot.queueCount = upcomingTracks.count
    }
}
