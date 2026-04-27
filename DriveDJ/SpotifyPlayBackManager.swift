import SpotifyiOS

@MainActor
final class SpotifyPlaybackManager: NSObject, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    let configuration = SPTConfiguration(
        clientID: AppConfig.spotifyClientID,
        redirectURL: URL(string: AppConfig.spotifyRedirectURI)!
    )
    private var trackId = ""
    private lazy var appRemote: SPTAppRemote = {
        let remote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        remote.delegate = self
        return remote
    }()

    private let orchestrator: DriveDJOrchestrator

    init(orchestrator: DriveDJOrchestrator) {
        self.orchestrator = orchestrator
        super.init()
    }

    func connect(accessToken: String, trackId:String) async{
        appRemote.connectionParameters.accessToken = accessToken
        self.trackId = trackId
        print("yahooooo")
        await MainActor.run{
            if let url = URL(string: "spotify://") {
                 UIApplication.shared.open(url)
            }
            if !appRemote.isConnected {
                appRemote.connect()
            }
        if let url = URL(string: "drivedj://callback") {
             UIApplication.shared.open(url)
        }
        }
    }

    func disconnect() {
        if appRemote.isConnected {
            appRemote.disconnect()
        }
    }

    // MARK: - Delegate

    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("✅ Connected")

        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: nil)
        appRemote.playerAPI?.play("spotify:track:\(trackId)", callback: nil)
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("❌ Connection failed:", error ?? "unknown")
        
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("🔌 Disconnected:", error ?? "none")
    }

    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        print("ちゃんげ！！")
        Task {
            try await orchestrator.handleTrackChanged(trackURI: playerState.track.uri)
        }
    }
}
