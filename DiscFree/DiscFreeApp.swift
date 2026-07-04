import SwiftUI

@main
struct DiscFreeApp: App {
    var body: some Scene {
        Window("DiscFree", id: "main") {
            ContentView()
        }
        .defaultSize(width: 900, height: 680)
        .windowResizability(.contentMinSize)
    }
}
