import Foundation

/// The JSON models emitted on stdout. Structure is stable (key *order* is not guaranteed);
/// optional fields are omitted when nil. All are `Codable` so tests can round-trip them.

/// One node in a shaped scan tree.
///
/// `unreadable` is present only when the directory could not be read. `children` is present
/// for directories (possibly empty when pruned or not descended into) and absent for files.
struct TreeNodeDTO: Codable, Equatable {
    let name: String
    let bytes: Int64
    let dir: Bool
    let unreadable: Bool?
    let children: [TreeNodeDTO]?
}

/// The result of `discfree scan`.
struct ScanResultDTO: Codable, Equatable {
    let path: String
    let total_bytes: Int64
    let unreadable_count: Int
    let truncated: Bool
    let tree: TreeNodeDTO
}

/// One developer-reclaimable item root, used by `dev` and `clean`.
struct DevItemDTO: Codable, Equatable {
    let path: String
    let category: String
    let bytes: Int64
}

/// The result of `discfree dev`.
struct DevResultDTO: Codable, Equatable {
    let items: [DevItemDTO]
    let total_bytes: Int64
}

/// The result of `discfree clean` without `--yes` (or with `--dry-run`): a plan only.
struct CleanPlanDTO: Codable, Equatable {
    let dry_run: Bool
    let planned: [DevItemDTO]
    let total_bytes: Int64
    let hint: String
}

/// One item that was moved to Trash (or found already gone).
///
/// `note` is present only for items that had already vanished between scan and trash; those
/// contribute nothing to `reclaimed_bytes` because this run did not move them.
struct TrashedItemDTO: Codable, Equatable {
    let path: String
    let category: String
    let bytes: Int64
    let note: String?
}

/// One item that could not be trashed.
struct FailedItemDTO: Codable, Equatable {
    let path: String
    let message: String
}

/// The result of `discfree clean --yes`.
struct CleanResultDTO: Codable, Equatable {
    let dry_run: Bool
    let trashed: [TrashedItemDTO]
    let failed: [FailedItemDTO]
    let reclaimed_bytes: Int64
}
