import Foundation

/// Owns the application's writable directories and keeps platform path rules
/// out of storage, cache, logging, and migration code.
///
/// The macOS paths intentionally remain byte-for-byte compatible with the
/// existing app. Windows uses `%LOCALAPPDATA%` because these files are local
/// application state rather than user documents or roaming settings. The
/// Windows shell can later add a user-facing import/export location without
/// changing any of these internal paths.
enum AppPaths {
    static let appName = "PokeTokenBar"

    /// Parent directory for application-owned state.
    ///
    /// Keeping the parent separate is important for the one-time TokenMac →
    /// PokeTokenBar migration, which must look for both sibling directories.
    static var applicationSupportRoot: URL {
        #if os(Windows)
        let environment = ProcessInfo.processInfo.environment
        let base = environment["LOCALAPPDATA"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("AppData", isDirectory: true)
                .appendingPathComponent("Local", isDirectory: true)
        return base
        #else
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #endif
    }

    /// Directory containing PokeTokenBar's state, cache, and snapshots.
    static var applicationDirectory: URL {
        applicationSupportRoot.appendingPathComponent(appName, isDirectory: true)
    }

    /// Directory used for the rolling app log and crash markers.
    ///
    /// macOS keeps the historical `~/Library/Logs` location so existing
    /// troubleshooting instructions and installed users keep working.
    /// Windows has no equivalent Library directory, so logs stay beside the
    /// app's local state under `%LOCALAPPDATA%`.
    static var logDirectory: URL {
        #if os(Windows)
        return applicationDirectory.appendingPathComponent("Logs", isDirectory: true)
        #else
        return FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        #endif
    }

    static func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
