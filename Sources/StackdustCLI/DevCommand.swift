import ArgumentParser
import StackdustCore
import Foundation

extension Stackdust {
    /// `stackdust dev [<path> ...]` — list reclaimable item roots: probe the known locations,
    /// or fully scan the given directories.
    struct Dev: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List reclaimable items (build/package caches, app caches, logs, iOS backups, Adobe media caches, ...).",
            discussion: """
            Without arguments, probes only the known cache and build locations (Xcode, \
            simulators, package-manager caches, per-app caches, ...) — fast, but blind to \
            project artifacts in arbitrary places. Pass one or more directories (e.g. where \
            your projects live) to scan them fully instead; only items under those \
            directories are reported.

            Reports only the roots of reclaimable items (e.g. a whole node_modules or app cache \
            folder), never the files inside them, sorted largest-first.

            Examples:
              stackdust dev --json                 # known locations only (fast)
              stackdust dev ~/dev --min-size 100M  # full scan of a projects directory
            """
        )

        @Argument(help: "Directories to scan fully (e.g. project roots). Omit to probe only the known locations.")
        var paths: [String] = []

        @Flag(name: .long, help: "Emit machine-readable JSON on stdout.")
        var json = false

        @Option(name: .customLong("min-size"), help: "Only list items at least SIZE (e.g. 500M, 1.5G).")
        var minSize: String?

        func run() async throws {
            try await runCommand(json: json) {
                try await execute()
            }
        }

        private func execute() async throws {
            let minBytes = try parseMinSize(minSize)

            let collected = try await DevScan.collectItems(paths: paths, catalog: DevItemCatalog())
            let items = DevSelection.filter(
                collected,
                categories: nil,
                minSize: minBytes
            )
            let dtos = items.map {
                DevItemDTO(
                    path: $0.path, category: $0.category.rawValue,
                    risk: $0.category.riskToken, bytes: $0.bytes
                )
            }
            let total = dtos.reduce(Int64(0)) { $0 + $1.bytes }

            if json {
                Output.line(try Output.json(DevResultDTO(items: dtos, total_bytes: total)))
            } else {
                Output.line(HumanTables.devItemsByCategory(items))
            }
        }
    }
}
