import SwiftUI

@main
struct DriveDJApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
   //private let container = SpotifyAuthManager.share
    var body: some Scene {
        WindowGroup {
            ContentView()
//                .onOpenURL { url in
//                    print("🔥 URL CALLBACK:", url)
//                    container.handleOpenURL(url)
//                }
        }
    }
}
