import Foundation

enum AppConfig {
    static var spotifyClientID: String {
        Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_CLIENT_ID") as? String ?? ""
    }

    static var spotifyRedirectURI: String {
        Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_REDIRECT_URI") as? String ?? ""
    }
    
    static var cyaneteApiToken: String {
        Bundle.main.object(forInfoDictionaryKey: "CYANETE_API_TOKEN") as? String ?? ""
    }

    static var appName: String { "DriveDJ" }
}
