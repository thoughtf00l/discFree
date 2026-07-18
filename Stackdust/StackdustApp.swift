import Sparkle
import SwiftUI

@main
struct StackdustApp: App {
    /// Started once for the app's lifetime; Sparkle schedules background checks itself
    /// and asks the user for consent before the first automatic one.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    var body: some Scene {
        Window("Stackdust", id: "main") {
            ContentView()
        }
        .defaultSize(width: 900, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}
