import XCTest
@testable import PokeTokenBar

final class AppPathsTests: XCTestCase {
    func testApplicationDirectoryKeepsTheAppName() {
        XCTAssertEqual(AppPaths.applicationDirectory.lastPathComponent, AppPaths.appName)
    }

    func testLogDirectoryIsStableForTheCurrentPlatform() {
        XCTAssertEqual(AppPaths.logDirectory.lastPathComponent, "Logs")
        #if os(macOS)
        XCTAssertEqual(AppPaths.logDirectory.deletingLastPathComponent().lastPathComponent, "Library")
        #else
        XCTAssertEqual(AppPaths.logDirectory.deletingLastPathComponent().lastPathComponent, AppPaths.appName)
        #endif
    }
}
