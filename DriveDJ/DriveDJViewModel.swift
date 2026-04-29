import Foundation
import Combine
import MusicKit
@MainActor
final class DriveDJViewModel: ObservableObject {
    @Published var snapshot = PlaybackSnapshot()
    //@Published var library: [TrackRecord] = []
    @Published var currentTrack: TrackRecord?
    @Published var upcomingTracks: [TrackRecord] = []
    @Published var isBusy: Bool = false
    static var debugText: String = ""
    private var cancellables = Set<AnyCancellable>()
    private let player = ApplicationMusicPlayer.shared
    var session = DriveSessionManager.shared

    private lazy var orchestrator = DriveDJOrchestrator(viewModel:self)
    init(){
        observeNowPlaying()
    }
    func bootstrap() async throws{
        isBusy = true
        defer { isBusy = false }

        //library = try await orchestrator.bootstrapLibrary()
        session.refreshNightFlag()
        snapshot.status = "ライブラリを読み込みました"
        //snapshot.queueCount = library.count
    }

//    func enrichLibrary() async {
//        isBusy = true
//        defer { isBusy = false }
//
//        do {
//            library = try await orchestrator.enrichLibrary()
//            snapshot.status = "Library enriched"
//            snapshot.queueCount = library.count
//        } catch {
//            snapshot.status = "Enrichment failed: \(error.localizedDescription)"
//        }
//    }
    private func observeNowPlaying() {
        player.state.objectWillChange
            .sink { [weak self] _ in
                Task {
                    await self?.updateCurrentTrack()
                }
            }
            .store(in: &cancellables)
    }

    private func updateCurrentTrack() async {
        let entry = player.queue.currentEntry
        let song = entry?.item as? Song
        guard let song else {return}
        self.currentTrack = TrackRecord(title:song.title,artist: song.artistName)

    }

    func refreshSetlist() async throws{
        let state = session.currentState()
        let result = try await orchestrator.nextSetlist(for: state, current: currentTrack)
        snapshot.mood = result.0
        upcomingTracks = result.1
        snapshot.queueCount = result.1.count

        if let first = result.1.first {
            currentTrack = first
            snapshot.currentTitle = first.title
            snapshot.currentArtist = first.artist
            snapshot.status = "\(result.1.count) 曲を準備しました"
        } else {
            snapshot.status = "候補曲が見つかりません"
        }
    }
    
    func addSetList(track:TrackRecord) async throws{
        if let currentTrack {
            let index = upcomingTracks.firstIndex(where: {currentTrack.artist == $0.artist && currentTrack.title == $0.title})
            if let index {
                upcomingTracks.removeSubrange((index+1)...)
            }
        }
        upcomingTracks.append(track)
        snapshot.queueCount = upcomingTracks.count

        snapshot.status = "\(snapshot.queueCount) 曲を準備しました"
    }
    func changeCurrentTrack(track:TrackRecord) {
        currentTrack = track
        snapshot.currentTitle = track.title
        snapshot.currentArtist = track.artist
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
            snapshot.status = "再生中"
        } catch {
            snapshot.status = "再生に失敗しました: \(error.localizedDescription)"
        }
    }

    func toggleTrip() {
        if session.isTripRunning {
            session.stopTrip()
            snapshot.status = "ドライブを終了しました"
        } else {
            session.startTrip()
            snapshot.status = "ドライブを開始しました"
        }
    }

    func tick() {
        session.refreshNightFlag()
        snapshot.mood = MoodEngine().mood(for: session.currentState())
        snapshot.queueCount = upcomingTracks.count
        snapshot.queueCount = upcomingTracks.count
    }
}
