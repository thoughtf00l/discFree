import Foundation

/// Human-readable (non-JSON) renderers. These produce plain text with no ANSI escapes, so
/// they are safe when stdout is redirected; sizes are right-aligned into a column for scanning.
enum HumanTables {

    // MARK: - Scan tree

    /// Renders a shaped scan tree as an indented, size-aligned table.
    static func tree(_ root: TreeNodeDTO) -> String {
        var rows: [(size: String, label: String)] = []
        collectRows(root, depth: 0, into: &rows)
        let sizeWidth = rows.map(\.size.count).max() ?? 0
        return rows
            .map { "\(padLeft($0.size, to: sizeWidth))  \($0.label)" }
            .joined(separator: "\n")
    }

    private static func collectRows(
        _ node: TreeNodeDTO,
        depth: Int,
        into rows: inout [(size: String, label: String)]
    ) {
        let indent = String(repeating: "  ", count: depth)
        var label = indent + node.name
        if node.dir { label += "/" }
        if node.unreadable == true { label += "  (unreadable)" }
        rows.append((ByteSize.human(node.bytes), label))
        for child in node.children ?? [] {
            collectRows(child, depth: depth + 1, into: &rows)
        }
    }

    // MARK: - Dev / clean item tables

    /// Renders a list of dev items as a `size  category  path` table with a total line.
    static func devItems(_ items: [DevItemDTO], totalBytes: Int64) -> String {
        guard !items.isEmpty else { return "No developer-reclaimable items found." }
        let sizeWidth = items.map { ByteSize.human($0.bytes).count }.max() ?? 0
        let categoryWidth = items.map(\.category.count).max() ?? 0
        var lines = items.map { item in
            "\(padLeft(ByteSize.human(item.bytes), to: sizeWidth))  "
                + "\(padRight(item.category, to: categoryWidth))  \(item.path)"
        }
        lines.append("total: \(ByteSize.human(totalBytes)) across \(items.count) item(s)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Padding

    private static func padLeft(_ text: String, to width: Int) -> String {
        text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
    }

    private static func padRight(_ text: String, to width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }
}
