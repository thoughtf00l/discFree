import Foundation

/// A throttled snapshot of scan progress.
public struct ScanProgress: Sendable, Equatable {
    /// Number of directory entries visited so far (files, directories, symlinks, ...).
    public var itemsScanned: Int
    /// Running total of counted physical bytes so far (hard links counted once).
    public var bytesAccumulated: Int64
    /// Absolute path of the directory most recently started.
    public var currentPath: String

    public init(itemsScanned: Int, bytesAccumulated: Int64, currentPath: String) {
        self.itemsScanned = itemsScanned
        self.bytesAccumulated = bytesAccumulated
        self.currentPath = currentPath
    }
}

/// An update emitted by `DiskScanner.scan(at:)`.
///
/// The stream emits `.progress` repeatedly (throttled) and exactly one terminal
/// `.finished` carrying the fully built, size-aggregated tree, after which it finishes.
public enum ScanUpdate: Sendable {
    case progress(ScanProgress)
    case finished(FileNode)
}

/// Errors thrown by the scan engine.
enum ScanError: Error, Equatable {
    /// The scan root could not be accessed (does not exist, not a directory, or `stat` failed).
    case cannotAccessRoot(path: String, errno: Int32)
}
