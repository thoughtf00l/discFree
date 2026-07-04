import SwiftUI
import Observation

/// Drives the whole app: the start → scanning → result state machine, the scan task and
/// its cancellation, and the (off-main-thread) sunburst layout for the current focus node.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case idle
        case scanning
        case result
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var progress = ScanProgress(itemsScanned: 0, bytesAccumulated: 0, currentPath: "")
    private(set) var root: FileNode?
    private(set) var segments: [SunburstSegment] = []

    /// Current focus (center of the sunburst). Changing it recomputes the layout.
    private(set) var focus: FileNode?

    private let scanner = DiskScanner()
    private var scanTask: Task<Void, Never>?
    private var layoutTask: Task<Void, Never>?

    /// Root-to-focus chain, for the breadcrumb.
    var focusPath: [FileNode] {
        guard let focus else { return [] }
        var chain: [FileNode] = []
        var node: FileNode? = focus
        while let current = node {
            chain.append(current)
            node = current.parent
        }
        return chain.reversed()
    }

    // MARK: - Scanning

    func startScan(at url: URL) {
        cancelScan()
        phase = .scanning
        progress = ScanProgress(itemsScanned: 0, bytesAccumulated: 0, currentPath: url.path)
        root = nil
        focus = nil
        segments = []

        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await update in self.scanner.scan(at: url) {
                    switch update {
                    case .progress(let progress):
                        self.progress = progress
                    case .finished(let tree):
                        self.root = tree
                        self.setFocus(tree)
                        self.phase = .result
                    }
                }
            } catch is CancellationError {
                self.phase = .idle
            } catch {
                self.phase = .failed(error.localizedDescription)
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
    }

    func returnToStart() {
        cancelScan()
        layoutTask?.cancel()
        layoutTask = nil
        phase = .idle
        root = nil
        focus = nil
        segments = []
    }

    // MARK: - Navigation

    func drill(into node: FileNode) {
        guard node.children != nil, node.allocatedSize > 0 else { return }
        setFocus(node)
    }

    func ascend() {
        if let parent = focus?.parent {
            setFocus(parent)
        }
    }

    func jump(to node: FileNode) {
        setFocus(node)
    }

    // MARK: - Layout

    private func setFocus(_ node: FileNode) {
        focus = node
        rebuildLayout(for: node)
    }

    private func rebuildLayout(for node: FileNode) {
        layoutTask?.cancel()
        layoutTask = Task { [weak self] in
            let built = await Task.detached(priority: .userInitiated) {
                SunburstLayout.build(focus: node)
            }.value
            guard !Task.isCancelled else { return }
            self?.segments = built
        }
    }
}
