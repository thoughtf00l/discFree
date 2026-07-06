import Foundation

/// Coarse grouping of developer-reclaimable items, used to colour/label them later.
/// Backed by `String` so it can be persisted or shown without a separate mapping table.
enum DevCategory: String, Sendable {
    /// Xcode build products, archives, device-support symbols, and Xcode's own caches.
    case xcodeBuild
    /// CoreSimulator device images and caches.
    case simulators
    /// Downloaded, re-fetchable package/dependency data (SwiftPM, npm, Gradle, Cargo, …).
    case packageCache
    /// Project-local, regenerable build output (`target`, `build`, `.build`, `__pycache__`, …).
    case projectArtifacts
    /// Docker's Linux VM disk images.
    case docker
}

/// The set of rules that identify developer-reclaimable items in a scanned tree.
///
/// There are two rule kinds:
/// - **Absolute path rules** match a fixed location under the user's home directory
///   (e.g. `~/Library/Developer/Xcode/DerivedData`), plus one suffix rule for the
///   `… DeviceSupport` directories directly under `~/Library/Developer/Xcode`.
/// - **Name rules** match a directory of a given name anywhere in the tree, some behind a
///   guard that avoids false positives (e.g. `Pods` only next to a `Podfile`).
///
/// The home directory is injected so tests can point the absolute rules at a synthetic tree.
/// All matching reads only the in-memory `FileNode` tree; it never touches the disk.
struct DevItemCatalog {

    /// A guard that must hold for a name rule to match.
    enum NameGuard {
        /// No guard: the name alone is sufficient.
        case none
        /// A sibling (another child of the same parent) with one of these names must exist.
        case sibling(Set<String>)
        /// A direct child with this name must exist.
        case child(String)
    }

    /// A name rule: the category to assign and the guard that must hold.
    struct NameRule {
        let category: DevCategory
        let guardKind: NameGuard
    }

    /// Absolute path (no trailing slash) → category, for the fixed home-relative locations.
    let exactPaths: [String: DevCategory]

    /// The directory whose direct children ending in " DeviceSupport" are Xcode device support.
    let deviceSupportParent: String

    /// Directory name → rule, matched anywhere in the tree.
    let nameRules: [String: NameRule]

    init(home: String = FileManager.default.homeDirectoryForCurrentUser.path) {
        // Normalise: drop a trailing slash so joins produce "<home>/<relative>", not "//".
        let home = (home.count > 1 && home.hasSuffix("/")) ? String(home.dropLast()) : home

        // Home-relative location → category. Turned into absolute paths below.
        let relative: [(String, DevCategory)] = [
            ("Library/Developer/Xcode/DerivedData", .xcodeBuild),
            ("Library/Developer/Xcode/Archives", .xcodeBuild),
            ("Library/Developer/Xcode/UserData/Previews", .xcodeBuild),
            ("Library/Developer/CoreSimulator/Devices", .simulators),
            ("Library/Developer/CoreSimulator/Caches", .simulators),
            ("Library/Caches/com.apple.dt.Xcode", .xcodeBuild),
            ("Library/Caches/org.swift.swiftpm", .packageCache),
            ("Library/org.swift.swiftpm", .packageCache),
            ("Library/Caches/CocoaPods", .packageCache),
            ("Library/Caches/org.carthage.CarthageKit", .packageCache),
            ("Library/Caches/Homebrew", .packageCache),
            ("Library/Caches/pip", .packageCache),
            ("Library/Caches/Yarn", .packageCache),
            (".npm", .packageCache),
            (".gradle/caches", .packageCache),
            (".m2/repository", .packageCache),
            (".cargo/registry", .packageCache),
            (".cargo/git", .packageCache),
            ("go/pkg/mod", .packageCache),
            ("Library/Containers/com.docker.docker/Data/vms", .docker),
        ]
        var exact: [String: DevCategory] = [:]
        for (path, category) in relative {
            exact["\(home)/\(path)"] = category
        }
        self.exactPaths = exact
        self.deviceSupportParent = "\(home)/Library/Developer/Xcode"

        self.nameRules = [
            "node_modules": NameRule(category: .packageCache, guardKind: .none),
            "__pycache__": NameRule(category: .projectArtifacts, guardKind: .none),
            ".terraform": NameRule(category: .packageCache, guardKind: .none),
            "DerivedData": NameRule(category: .xcodeBuild, guardKind: .none),
            "Pods": NameRule(category: .packageCache, guardKind: .sibling(["Podfile"])),
            ".build": NameRule(category: .projectArtifacts, guardKind: .sibling(["Package.swift"])),
            "Carthage": NameRule(category: .packageCache, guardKind: .sibling(["Cartfile"])),
            "target": NameRule(category: .projectArtifacts, guardKind: .sibling(["Cargo.toml"])),
            "build": NameRule(category: .projectArtifacts,
                              guardKind: .sibling(["gradlew", "build.gradle", "build.gradle.kts"])),
            ".venv": NameRule(category: .projectArtifacts, guardKind: .child("pyvenv.cfg")),
            "venv": NameRule(category: .projectArtifacts, guardKind: .child("pyvenv.cfg")),
            ".next": NameRule(category: .projectArtifacts, guardKind: .sibling(["package.json"])),
            ".nuxt": NameRule(category: .projectArtifacts, guardKind: .sibling(["package.json"])),
        ]
    }

    /// Returns the category if `node` (whose absolute path is `path`) is a dev-item root, else nil.
    /// Only directories match; guards are checked against the in-memory tree, never the disk.
    func category(for node: FileNode, path: String) -> DevCategory? {
        guard node.isDirectory else { return nil }

        if let category = exactPaths[path] {
            return category
        }
        if node.name.hasSuffix(" DeviceSupport"),
           path == "\(deviceSupportParent)/\(node.name)" {
            return .xcodeBuild
        }
        if let rule = nameRules[node.name], satisfies(rule.guardKind, at: node) {
            return rule.category
        }
        return nil
    }

    private func satisfies(_ guardKind: NameGuard, at node: FileNode) -> Bool {
        switch guardKind {
        case .none:
            return true
        case .sibling(let names):
            guard let siblings = node.parent?.children else { return false }
            return siblings.contains { $0 !== node && names.contains($0.name) }
        case .child(let name):
            guard let children = node.children else { return false }
            return children.contains { $0.name == name }
        }
    }
}
