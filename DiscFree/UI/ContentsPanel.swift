import SwiftUI

/// The right-hand contents list: the focus node's children, largest first.
struct ContentsPanel: View {
    let focusTotal: Int64
    let rows: [FileNode]
    @Binding var hovered: FileNode?
    let onDrill: (FileNode) -> Void
    let onReveal: (FileNode) -> Void
    let onTrash: (FileNode) -> Void

    var body: some View {
        List {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, node in
                ContentsRow(
                    node: node,
                    focusTotal: focusTotal,
                    hue: rows.count > 0 ? Double(index) / Double(rows.count) : 0,
                    isHovered: hovered === node
                )
                .contentShape(Rectangle())
                .onTapGesture { onDrill(node) }
                .onHover { isInside in
                    if isInside { hovered = node }
                    else if hovered === node { hovered = nil }
                }
                .contextMenu {
                    Button {
                        onReveal(node)
                    } label: {
                        Label("Reveal in Finder", systemImage: "magnifyingglass")
                    }
                    Button(role: .destructive) {
                        onTrash(node)
                    } label: {
                        Label("Move to Trash…", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}

private struct ContentsRow: View {
    let node: FileNode
    let focusTotal: Int64
    let hue: Double
    let isHovered: Bool

    private var share: Double {
        focusTotal > 0 ? Double(node.allocatedSize) / Double(focusTotal) : 0
    }

    private var swatch: Color {
        node.isUnreadable ? Color(white: 0.55) : Color(hue: hue, saturation: 0.7, brightness: 0.82)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(node.isUnreadable ? Color.secondary : swatch)
                .frame(width: 18)

            Text(node.displayName)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            shareBar

            Text(byteString(node.allocatedSize))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)

            Text(percentText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 44, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .opacity(isDrillable ? 1 : 0)
        }
        .padding(.vertical, 2)
        .listRowBackground(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    private var shareBar: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.quaternary).frame(width: 60, height: 5)
            Capsule().fill(swatch).frame(width: max(1, 60 * share), height: 5)
        }
    }

    private var isDrillable: Bool {
        node.isDirectory && node.children != nil && node.allocatedSize > 0
    }

    private var iconName: String {
        if node.isUnreadable { return "lock.fill" }
        return node.isDirectory ? "folder.fill" : "doc.fill"
    }

    private var percentText: String {
        share >= 0.001 ? String(format: "%.1f%%", share * 100) : "<0.1%"
    }
}
