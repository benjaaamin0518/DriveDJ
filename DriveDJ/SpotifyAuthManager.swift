import SpotifyiOS

final class SpotifyAuthManager: NSObject, SPTSessionManagerDelegate {
    //private var playbackManager: SpotifyPlaybackManager
    static let share = SpotifyAuthManager()
    var accessToken = ""
    var trackId = ""
    private var spotifyManager : SpotifyPlaybackManager?
    private let configuration = SPTConfiguration(
        clientID: AppConfig.spotifyClientID,
        redirectURL: URL(string: AppConfig.spotifyRedirectURI)!
    )

    lazy var sessionManager = SPTSessionManager(configuration: configuration, delegate: self)

    

    //init(playbackManager: SpotifyPlaybackManager) {
    override init() {
        self.spotifyManager = nil
        super.init()
    }

    func startAuth(spotifyManager:SpotifyPlaybackManager, trackId:String) {
        sessionManager.initiateSession(with: [.appRemoteControl], options: .default, campaign: nil)
        self.spotifyManager = spotifyManager
        self.trackId = trackId
    }

    // ✅ ここが最重要
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        Task{await MainActor.run{        print("🔥 AUTH SUCCESS")}}
        accessToken = session.accessToken
        print("🔑🔑🔑🔑🔑 \(accessToken)")
        guard let spotifyManager else{return}
        Task{ await spotifyManager.connect(accessToken: accessToken, trackId:trackId)}
    }
    func handleOpenURL(_ url: URL) {
        sessionManager.application(UIApplication.shared, open: url, options: [:])
    }

    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        print("Auth failed:", error)
    }
}
