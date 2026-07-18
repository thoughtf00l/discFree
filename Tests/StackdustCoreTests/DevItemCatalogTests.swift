import XCTest
@testable import StackdustCore

/// Tests for the catalog's derived probe-root list (`knownRootPaths`).
final class DevItemCatalogTests: XCTestCase {
    private let home = "/Users/probe"
    private var roots: [String]!

    override func setUp() {
        super.setUp()
        roots = DevItemCatalog(home: home).knownRootPaths
    }

    func testContainsCollapsedTopLevelRoots() {
        XCTAssertTrue(roots.contains("\(home)/Library/Developer"))
        XCTAssertTrue(roots.contains("\(home)/Library/Caches"))
        XCTAssertTrue(roots.contains("\(home)/.npm"))
        XCTAssertTrue(roots.contains("\(home)/go/pkg/mod"))
    }

    func testNestedRootsAreCollapsedIntoTheirParent() {
        // Exact paths that live inside another root must not be probed separately: the Xcode
        // and CoreSimulator anchors are inside Library/Developer; the pinned cache folders are
        // inside Library/Caches.
        XCTAssertFalse(roots.contains("\(home)/Library/Developer/Xcode"))
        XCTAssertFalse(roots.contains("\(home)/Library/Developer/Xcode/DerivedData"))
        XCTAssertFalse(roots.contains("\(home)/Library/Developer/CoreSimulator/Devices"))
        XCTAssertFalse(roots.contains("\(home)/Library/Caches/Homebrew"))
        XCTAssertFalse(roots.contains("\(home)/Library/Caches/com.apple.dt.Xcode"))
    }

    func testNoRootIsNestedInsideAnother() {
        for (index, outer) in roots.enumerated() {
            for inner in roots[(index + 1)...] {
                XCTAssertFalse(
                    inner.hasPrefix(outer + "/"),
                    "\(inner) is nested inside \(outer)"
                )
            }
        }
    }

    func testRootsAreAbsoluteAndUnique() {
        XCTAssertEqual(roots.count, Set(roots).count)
        XCTAssertTrue(roots.allSatisfy { $0.hasPrefix("/") })
    }
}
