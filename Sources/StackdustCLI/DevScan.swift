import StackdustCore
import Foundation

/// Gathers reclaimable items for `dev` and `clean`, in one of two modes:
///
/// - **Known locations** (no paths given): probe only the catalog's fixed roots. Fast — it
///   never walks the places that cannot contain a dev item — but blind to name-rule items
///   outside those roots (a `node_modules` deep inside some unlisted directory).
/// - **Given directories** (paths given): walk each one fully so the name rules see everything
///   under it. This is the pre-existing `dev <path>` behavior, scoped to exactly what the
///   caller pointed at — known locations outside the given paths are NOT mixed in, so `clean`
///   never touches anything the caller did not name.
enum DevScan {

    static func collectItems(
        paths: [String], catalog: DevItemCatalog
    ) async throws -> [DevSelection.Item] {
        paths.isEmpty
            ? try await probeKnownRoots(catalog: catalog)
            : try await walk(paths: paths, catalog: catalog)
    }

    // MARK: - Known locations

    private static func probeKnownRoots(
        catalog: DevItemCatalog
    ) async throws -> [DevSelection.Item] {
        var items: [DevSelection.Item] = []
        var unreadable: [String] = []
        var scannedCount = 0

        for root in catalog.knownRootPaths {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: root, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            let tree = try await ScanRunner.scanTree(at: URL(fileURLWithPath: root).standardizedFileURL)
            if tree.isUnreadable {
                unreadable.append(root)
                continue
            }
            scannedCount += 1
            DevClassifier.classify(tree, using: catalog)
            items.append(contentsOf: DevSelection.collect(tree))
        }

        // Nothing was readable at all: that is the Full Disk Access failure mode, not the
        // "partial data still counts" case.
        if scannedCount == 0 && !unreadable.isEmpty {
            throw CLIError(
                code: "permission_denied",
                message: "None of the known locations could be read.",
                path: unreadable[0],
                hint: fullDiskAccessHint,
                exit: .permissionDenied
            )
        }
        if !unreadable.isEmpty {
            Output.note(
                "note: \(unreadable.count) known location(s) could not be read: "
                + unreadable.joined(separator: ", ")
            )
        }
        return DevSelection.sorted(items)
    }

    // MARK: - Given directories

    private static func walk(
        paths: [String], catalog: DevItemCatalog
    ) async throws -> [DevSelection.Item] {
        var items: [DevSelection.Item] = []
        for path in collapseNested(paths) {
            let tree = try await ScanRunner.run(path: path)
            DevClassifier.classify(tree, using: catalog)
            items.append(contentsOf: DevSelection.collect(tree))
        }
        return DevSelection.sorted(items)
    }

    /// Drops exact duplicates and paths nested inside another given path, so an item is never
    /// collected (or trashed) twice; mirrors the collapse `DevItemCatalog.knownRootPaths` does
    /// for its own roots.
    static func collapseNested(_ paths: [String]) -> [String] {
        let standardized = Set(paths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
        var roots: [String] = []
        for path in standardized.sorted() {
            if let last = roots.last, path.hasPrefix(last == "/" ? "/" : last + "/") { continue }
            roots.append(path)
        }
        return roots
    }
}
