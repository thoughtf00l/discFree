import SwiftUI

struct ContentView: View {
    let themeStore: ThemeStore
    @State private var model = AppModel()

    var body: some View {
        Group {
            switch model.phase {
            case .idle:
                StartView(model: model)
            case .scanning:
                ScanningView(model: model)
            case .result:
                ResultView(model: model)
            case .failed(let message):
                FailedView(model: model, message: message)
            }
        }
        .frame(minWidth: 720, minHeight: 560)
        .tint(themeStore.selected.accent.color)
        // Custom background paints the whole window (title bar included) and forces the
        // control scheme by its luminance so labels stay readable; nil follows the system.
        .containerBackground(backgroundStyle, for: .window)
        .preferredColorScheme(themeStore.selected.colorScheme)
        .environment(\.themeBackground, themeStore.selected.background)
        .onChange(of: themeStore.selected, initial: true) { _, theme in
            model.themePalette = theme.colors
        }
        .task { model.attemptResume() }
    }

    private var backgroundStyle: AnyShapeStyle {
        if let background = themeStore.selected.background {
            AnyShapeStyle(background.color)
        } else {
            AnyShapeStyle(.windowBackground)
        }
    }
}

#Preview {
    ContentView(themeStore: ThemeStore())
}
