import XCTest
import StackdustCore
@testable import StackdustCLI

/// Tests for the two `dev`/`clean` gather modes over a synthetic home directory on disk.
final class DevScanTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DevScanTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: home)
    }

    private func makeFile(_ relativePath: String, bytes: Int = 16) throws {
        let url = home.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(repeating: 0x61, count: bytes).write(to: url)
    }

    // MARK: - Known-locations probe (no paths)

    func testProbeFindsItemsInKnownLocationsOnly() async throws {
        try makeFile("Library/Developer/Xcode/DerivedData/MyApp-abc/Build/x.o")
        try makeFile("Library/Caches/SomeApp/cache.db")
        // A name-rule item outside every known root: the probe must NOT see it.
        try makeFile("dev/website/node_modules/left-pad/index.js")

        let catalog = DevItemCatalog(home: home.path)
        let items = try await DevScan.collectItems(paths: [], catalog: catalog)

        let paths = items.map(\.path)
        XCTAssertTrue(paths.contains(home.appendingPathComponent("Library/Developer/Xcode/DerivedData").path))
        XCTAssertTrue(paths.contains(home.appendingPathComponent("Library/Caches/SomeApp").path))
        XCTAssertFalse(paths.contains { $0.hasSuffix("node_modules") })
    }

    func testProbeSkipsMissingRootsAndReturnsEmptyForEmptyHome() async throws {
        let catalog = DevItemCatalog(home: home.path)
        let items = try await DevScan.collectItems(paths: [], catalog: catalog)
        XCTAssertEqual(items, [])
    }

    // MARK: - Given directories (full walk)

    func testWalkFindsNameRuleItemsUnderGivenPathOnly() async throws {
        try makeFile("dev/website/node_modules/left-pad/index.js")
        // A known location outside the given path: must NOT be mixed in.
        try makeFile("Library/Developer/Xcode/DerivedData/MyApp-abc/Build/x.o")

        let catalog = DevItemCatalog(home: home.path)
        let items = try await DevScan.collectItems(
            paths: [home.appendingPathComponent("dev").path], catalog: catalog
        )

        let paths = items.map(\.path)
        XCTAssertEqual(paths, [home.appendingPathComponent("dev/website/node_modules").path])
    }

    func testWalkDoesNotDuplicateItemsForNestedPaths() async throws {
        try makeFile("dev/website/node_modules/left-pad/index.js")

        let catalog = DevItemCatalog(home: home.path)
        let items = try await DevScan.collectItems(
            paths: [
                home.appendingPathComponent("dev").path,
                home.appendingPathComponent("dev/website").path,
            ],
            catalog: catalog
        )

        XCTAssertEqual(items.count, 1)
    }

    // MARK: - collapseNested

    func testCollapseNestedDropsDuplicatesAndDescendants() {
        let collapsed = DevScan.collapseNested([
            "/a/b", "/a/b/c", "/a/b", "/a/bc", "/d",
        ])
        XCTAssertEqual(collapsed, ["/a/b", "/a/bc", "/d"])
    }

    func testCollapseNestedRootCoversEverything() {
        XCTAssertEqual(DevScan.collapseNested(["/", "/Users"]), ["/"])
    }
}
