import SwiftUI

struct ResultView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            BreadcrumbBar(path: model.focusPath) { model.jump(to: $0) }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if let focus = model.focus {
                SunburstView(
                    segments: model.segments,
                    focus: focus,
                    onDrill: { model.drill(into: $0) },
                    onAscend: { model.ascend() }
                )
                .padding(16)
            } else {
                Spacer()
            }

            Divider()

            HStack {
                Button {
                    model.returnToStart()
                } label: {
                    Label("New Scan", systemImage: "arrow.left")
                }
                Spacer()
                if let focus = model.focus {
                    Text(byteString(focus.allocatedSize))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

/// Horizontally scrolling breadcrumb of the focus path; the last crumb is the focus.
struct BreadcrumbBar: View {
    let path: [FileNode]
    let onSelect: (FileNode) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(path.enumerated()), id: \.offset) { index, node in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Button {
                        onSelect(node)
                    } label: {
                        Text(node.displayName)
                            .lineLimit(1)
                            .fontWeight(index == path.count - 1 ? .bold : .regular)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct FailedView: View {
    let model: AppModel
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Scan failed")
                .font(.title2.bold())
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button {
                model.returnToStart()
            } label: {
                Label("Back", systemImage: "arrow.left")
            }
        }
        .padding(40)
    }
}
