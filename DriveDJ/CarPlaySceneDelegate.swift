import Foundation
import CarPlay
import SwiftUI

@objc(CarPlaySceneDelegate)
@MainActor
final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private let viewModel = DriveDJViewModel()
    private let session = DriveSessionManager.shared

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        session.setCarPlayConnected(true)
        Task {
            try await viewModel.bootstrap()
            try await refreshTemplate()
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        self.interfaceController = nil
        session.setCarPlayConnected(false)
    }

    private func refreshTemplate() async throws {
        try await viewModel.refreshSetlist()
        let template = makeRootTemplate()
        try await interfaceController?.setRootTemplate(template, animated: false)
    }

    private func makeRootTemplate() -> CPTemplate {
        let moodItem = CPListItem(text: "Mood", detailText: viewModel.snapshot.mood.rawValue)
        let trackItem = CPListItem(
            text: "Now Playing",
            detailText: "\(viewModel.snapshot.currentTitle) — \(viewModel.snapshot.currentArtist)"
        )
        let statusItem = CPListItem(text: "Status", detailText: viewModel.snapshot.status)

        moodItem.handler = { _, completion in
            Task { try await self.viewModel.refreshSetlist(); try await self.refreshTemplate() }
            completion()
        }

        trackItem.handler = { _, completion in
            Task { try await self.viewModel.playPreparedSetlist(); try await self.refreshTemplate() }
            completion()
        }

        statusItem.handler = { _, completion in
            completion()
        }

        let section = CPListSection(items: [moodItem, trackItem, statusItem])
        let template = CPListTemplate(title: AppConfig.appName, sections: [section])
        return template
    }
}
