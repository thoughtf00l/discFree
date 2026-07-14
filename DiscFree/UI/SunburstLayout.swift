import SwiftUI
import DiscFreeCore

/// One drawable ring segment. Cheap value data: the view never walks the `FileNode`
/// tree while rendering — it renders this precomputed array. The `node` reference is
/// kept only so a click can re-focus without an index lookup.
struct SunburstSegment: Identifiable, Sendable {
    let id: ObjectIdentifier
    let node: FileNode
    let depth: Int          // ring index, 1 = innermost ring outside the hole
    let startAngle: Double  // radians in [0, 2π), 0 = top, increasing clockwise
    let endAngle: Double
    let hue: Double
    let saturation: Double
    let brightness: Double
    let isUnreadable: Bool
    /// Whether this node is a developer-reclaimable item or lives inside one.
    let isDev: Bool
    /// The node's reclaimable share, used to tint the segment when highlighting: 1 for a dev
    /// item and its descendants, `devSize / allocatedSize` for any other node (0 when
    /// `allocatedSize == 0`). Only meaningful while highlighting; it is 1 when highlighting is
    /// off, so `color` reproduces the full branch color unchanged.
    let reclaimableFraction: Double

    var color: Color {
        if isUnreadable { return Color(hue: 0, saturation: 0, brightness: 0.55) }
        return tinted(saturation: saturation, brightness: brightness)
    }

    var highlightedColor: Color {
        if isUnreadable { return Color(hue: 0, saturation: 0, brightness: 0.72) }
        return tinted(saturation: max(0.2, saturation - 0.12),
                      brightness: min(1.0, brightness + 0.14))
    }

    /// Blends the full branch color toward the neutral gray (hue 0, saturation 0, same
    /// brightness ramp) by `sqrt(reclaimableFraction)`: saturation scales toward 0 and
    /// brightness interpolates toward the gray's value. The `sqrt` gives a perceptual boost so
    /// even a small reclaimable share stays visibly warm. Fraction 1 reproduces the full color;
    /// fraction 0 collapses to the plain gray, matching the old all-gray look. (Brightness
    /// blending is a no-op while both endpoints share the ramp, kept general so the blend stays
    /// correct if they ever diverge.)
    private func tinted(saturation fullSaturation: Double, brightness fullBrightness: Double) -> Color {
        let t = min(1, max(0, reclaimableFraction)).squareRoot()
        let grayBrightness = fullBrightness
        return Color(hue: hue,
                     saturation: fullSaturation * t,
                     brightness: grayBrightness + (fullBrightness - grayBrightness) * t)
    }
}

/// One row of the contents panel: a child of the focus, its display size, and whether the
/// child is a dev item or inside one. Precomputed off the main thread alongside the sunburst
/// so the panel never walks the tree while rendering.
struct ContentsPanelRow: Identifiable, Sendable {
    let node: FileNode
    /// Size shown for the row: the node's `allocatedSize`.
    let displaySize: Int64
    /// True when the row is a dev-item root or inside one — not merely a container of dev items.
    let isDev: Bool

    var id: ObjectIdentifier { ObjectIdentifier(node) }
}

/// Builds the sunburst segment layout for a focus node, limited to a few depth levels
/// and culling slivers below a minimum angle. Pure and side-effect free, so it can run
/// off the main thread.
enum SunburstLayout {
    static let maxDepth = 5
    static let minAngle = 0.5 * Double.pi / 180  // 0.5° — below this a slice is invisible

    static func build(focus: FileNode, highlight: Bool) -> [SunburstSegment] {
        var segments: [SunburstSegment] = []
        guard let children = focus.children else { return segments }

        // "Inside a dev item" for the focus itself; threaded down the walk from here so
        // `DevClassifier.isWithinDevItem` is never called per node.
        let focusIsDev = DevClassifier.isWithinDevItem(focus)
        let total = focus.allocatedSize
        guard total > 0 else { return segments }

        // Depth 1 fills the full circle; each included top-level branch gets a distinct hue.
        let entries = sortedEntries(of: children, parentIsDev: focusIsDev)
        let branchCount = entries.count
        var cursor = 0.0
        for (index, entry) in entries.enumerated() {
            let extent = 2 * Double.pi * Double(entry.size) / Double(total)
            let start = cursor
            cursor += extent
            guard extent >= minAngle else { continue }  // consume the angle, skip the sliver
            let hue = branchCount > 0 ? Double(index) / Double(branchCount) : 0
            append(entry.node, depth: 1, start: start, end: cursor, hue: hue,
                   isDev: entry.isDev, fraction: entry.fraction, highlight: highlight,
                   into: &segments)
            recurse(entry.node, depth: 2, start: start, end: cursor,
                    hue: hue, nodeIsDev: entry.isDev, highlight: highlight, into: &segments)
        }
        return segments
    }

    /// The focus node's direct children as panel rows, sized by `allocatedSize`.
    static func rows(focus: FileNode) -> [ContentsPanelRow] {
        guard let children = focus.children else { return [] }
        let focusIsDev = DevClassifier.isWithinDevItem(focus)
        return sortedEntries(of: children, parentIsDev: focusIsDev)
            .map { ContentsPanelRow(node: $0.node, displaySize: $0.size, isDev: $0.isDev) }
    }

    /// The focus's `allocatedSize`. Drives the panel share bars, the center label, and the
    /// status text.
    static func focusDisplayTotal(focus: FileNode) -> Int64 {
        focus.allocatedSize
    }

    private static func recurse(
        _ node: FileNode, depth: Int, start: Double, end: Double,
        hue: Double, nodeIsDev: Bool, highlight: Bool, into segments: inout [SunburstSegment]
    ) {
        guard depth <= maxDepth, let children = node.children else { return }
        let parentTotal = node.allocatedSize
        guard parentTotal > 0 else { return }

        let span = end - start
        let entries = sortedEntries(of: children, parentIsDev: nodeIsDev)
        var cursor = start
        for entry in entries {
            let extent = span * Double(entry.size) / Double(parentTotal)
            let childStart = cursor
            cursor += extent
            guard extent >= minAngle else { continue }
            append(entry.node, depth: depth, start: childStart, end: cursor, hue: hue,
                   isDev: entry.isDev, fraction: entry.fraction, highlight: highlight,
                   into: &segments)
            recurse(entry.node, depth: depth + 1, start: childStart, end: cursor,
                    hue: hue, nodeIsDev: entry.isDev, highlight: highlight, into: &segments)
        }
    }

    private static func append(
        _ node: FileNode, depth: Int, start: Double, end: Double, hue: Double,
        isDev: Bool, fraction: Double, highlight: Bool, into segments: inout [SunburstSegment]
    ) {
        // Outer rings get lighter, less saturated shades of the branch hue.
        let saturation = max(0.28, 0.80 - Double(depth - 1) * 0.11)
        let brightness = min(0.97, 0.70 + Double(depth - 1) * 0.06)
        segments.append(
            SunburstSegment(
                id: ObjectIdentifier(node),
                node: node,
                depth: depth,
                startAngle: start,
                endAngle: end,
                hue: hue,
                saturation: saturation,
                brightness: brightness,
                isUnreadable: node.isUnreadable,
                isDev: isDev,
                // Highlighting off: full color, so the fraction is forced to 1.
                reclaimableFraction: highlight ? fraction : 1
            )
        )
    }

    /// Children mapped to (node, allocatedSize, isDev, reclaimableFraction), sorted by size
    /// descending. `parentIsDev` is the "inside a dev item" flag of the parent, threaded down so
    /// no per-node `isWithinDevItem` walk is needed. `fraction` is 1 for a dev node (item or
    /// descendant), otherwise its `devSize / allocatedSize` share (0 when empty).
    private static func sortedEntries(
        of children: [FileNode], parentIsDev: Bool
    ) -> [(node: FileNode, size: Int64, isDev: Bool, fraction: Double)] {
        children
            .map { child -> (node: FileNode, size: Int64, isDev: Bool, fraction: Double) in
                let isDev = parentIsDev || child.devCategory != nil
                let fraction: Double
                if isDev {
                    fraction = 1
                } else if child.allocatedSize > 0 {
                    fraction = Double(child.devSize) / Double(child.allocatedSize)
                } else {
                    fraction = 0
                }
                return (child, child.allocatedSize, isDev, fraction)
            }
            .sorted { $0.size > $1.size }
    }
}
