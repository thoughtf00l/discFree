import Sparkle
import SwiftUI

@main
struct StackdustApp: App {
    /// Started once for the app's lifetime; Sparkle schedules background checks itself
    /// and asks the user for consent before the first automatic one.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    /// Shared between the main window (chart colors) and the Settings scene (editing).
    @State private var themeStore = ThemeStore()

    var body: some Scene {
        Window("Stackdust", id: "main") {
            ContentView(themeStore: themeStore)
        }
        // No title-bar chrome: on macOS 26 the glass title bar ignores
        // titlebarAppearsTransparent, so themed backgrounds could never reach it. The traffic
        // lights float over the content; the top strip still drags the window.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }

        Settings {
            ThemeSettingsView(store: themeStore)
        }
    }
}
