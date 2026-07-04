import SwiftUI

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

    var color: Color {
        isUnreadable
            ? Color(hue: 0, saturation: 0, brightness: 0.55)
            : Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    var highlightedColor: Color {
        isUnreadable
            ? Color(hue: 0, saturation: 0, brightness: 0.72)
            : Color(hue: hue,
                    saturation: max(0.2, saturation - 0.12),
                    brightness: min(1.0, brightness + 0.14))
    }
}

/// Builds the sunburst segment layout for a focus node, limited to a few depth levels
/// and culling slivers below a minimum angle. Pure and side-effect free, so it can run
/// off the main thread.
enum SunburstLayout {
    static let maxDepth = 5
    static let minAngle = 0.5 * Double.pi / 180  // 0.5° — below this a slice is invisible

    static func build(focus: FileNode) -> [SunburstSegment] {
        var segments: [SunburstSegment] = []
        let total = focus.allocatedSize
        guard total > 0, let children = focus.children else { return segments }

        // Depth 1 fills the full circle; each top-level branch gets a distinct hue.
        let sorted = children.sorted { $0.allocatedSize > $1.allocatedSize }
        let branchCount = sorted.count
        var cursor = 0.0
        for (index, child) in sorted.enumerated() {
            let extent = 2 * Double.pi * Double(child.allocatedSize) / Double(total)
            let start = cursor
            cursor += extent
            guard extent >= minAngle else { continue }  // consume the angle, skip the sliver
            let hue = branchCount > 0 ? Double(index) / Double(branchCount) : 0
            append(child, depth: 1, start: start, end: cursor, hue: hue, into: &segments)
            recurse(child, depth: 2, start: start, end: cursor, hue: hue, into: &segments)
        }
        return segments
    }

    private static func recurse(
        _ node: FileNode, depth: Int, start: Double, end: Double,
        hue: Double, into segments: inout [SunburstSegment]
    ) {
        guard depth <= maxDepth,
              node.allocatedSize > 0,
              let children = node.children else { return }

        let parentTotal = node.allocatedSize
        let span = end - start
        let sorted = children.sorted { $0.allocatedSize > $1.allocatedSize }
        var cursor = start
        for child in sorted {
            let extent = span * Double(child.allocatedSize) / Double(parentTotal)
            let childStart = cursor
            cursor += extent
            guard extent >= minAngle else { continue }
            append(child, depth: depth, start: childStart, end: cursor, hue: hue, into: &segments)
            recurse(child, depth: depth + 1, start: childStart, end: cursor, hue: hue, into: &segments)
        }
    }

    private static func append(
        _ node: FileNode, depth: Int, start: Double, end: Double,
        hue: Double, into segments: inout [SunburstSegment]
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
                isUnreadable: node.isUnreadable
            )
        )
    }
}
