import Foundation

enum TreeEditError: Error, Equatable {
    /// The scan root has no parent and cannot be removed.
    case cannotRemoveRoot
    /// The node currently in focus must not be removed out from under the view.
    case cannotRemoveFocus
    /// The node is not present in its parent's children (already removed or detached).
    case nodeNotInTree
}

/// Non-UI tree mutation for deletion. Isolated from the scanner and the views so it can be
/// unit-tested directly.
enum TreeEditor {
    /// Detaches `node` from its parent and subtracts its aggregated size from every ancestor,
    /// keeping directory totals consistent.
    ///
    /// - Parameters:
    ///   - node: the node to remove.
    ///   - focus: the node currently shown; removing it is disallowed.
    /// - Returns: the removed node's former parent.
    @discardableResult
    static func remove(_ node: FileNode, keeping focus: FileNode) throws -> FileNode {
        guard node !== focus else { throw TreeEditError.cannotRemoveFocus }
        guard let parent = node.parent else { throw TreeEditError.cannotRemoveRoot }
        guard let index = parent.children?.firstIndex(where: { $0 === node }) else {
            throw TreeEditError.nodeNotInTree
        }

        parent.children?.remove(at: index)
        node.parent = nil

        let removedSize = node.allocatedSize
        var ancestor: FileNode? = parent
        while let current = ancestor {
            current.allocatedSize -= removedSize
            ancestor = current.parent
        }
        return parent
    }
}
