import Foundation

/// Human-readable "size on disk" string.
func byteString(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

extension FileNode {
    /// Display label: the last path component for the scan root (whose `name` is an
    /// absolute path), otherwise the entry name.
    var displayName: String {
        guard parent == nil else { return name }
        let last = (name as NSString).lastPathComponent
        return last.isEmpty ? name : last
    }
}
