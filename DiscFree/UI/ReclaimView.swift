import SwiftUI
import DiscFreeCore

/// The "Reclaim" pane: a category-first list of developer-reclaimable items with per-item and
/// per-group checkboxes, and a footer that batch-moves the selection to the Trash. Shown inside
/// `ResultView` in place of the sunburst/contents area when `resultPane == .reclaim`.
struct ReclaimView: View {
    let model: AppModel

    var body: some View {
        Group {
            if model.scanActive {
                emptyState("Available after the scan completes.")
            } else if model.reclaimGroups.isEmpty {
                emptyState("Nothing reclaimable found.")
            } else {
                content
            }
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: Binding(
                get: { model.pendingReclaimTrash != nil },
                set: { if !$0 { model.cancelReclaimTrash() } }
            ),
            presenting: model.pendingReclaimTrash
        ) { _ in
            Button("Move to Trash", role: .destructive) { model.confirmReclaimTrash() }
            Button("Cancel", role: .cancel) { model.cancelReclaimTrash() }
        } message: { pending in
            Text(trashMessage(for: pending))
        }
    }

    private func emptyState(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        VStack(spacing: 0) {
            List {
                ForEach(model.reclaimGroups, id: \.category) { group in
                    Section {
                        ForEach(group.items, id: \.node.id) { item in
                            ReclaimItemRow(
                                item: item,
                                rootName: model.root?.name ?? "",
                                isSelected: model.isReclaimItemSelected(item),
                                onToggle: { model.toggleReclaimItem(item) },
                                onReveal: { model.reveal(item.node) }
                            )
                        }
                    } header: {
                        ReclaimGroupHeader(
                            group: group,
                            state: groupState(group),
                            onToggle: { model.toggleReclaimGroup(group) }
                        )
                    }
                }
            }
            .listStyle(.inset)

            Divider()
            footer
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("\(model.reclaimSelectedCount) items · \(byteString(model.reclaimSelectedBytes)) selected")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            Button {
                model.requestReclaimTrash()
            } label: {
                Text("Move Selected to Trash…")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.reclaimSelection.isEmpty || model.scanActive)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// The tri-state checkbox value for a group: on when all items are selected, mixed when some
    /// are, off when none are.
    private func groupState(_ group: ReclaimGroup) -> ReclaimCheckbox.State {
        let selected = group.items.filter { model.isReclaimItemSelected($0) }.count
        if selected == 0 { return .off }
        if selected == group.items.count { return .on }
        return .mixed
    }

    private func trashMessage(for pending: AppModel.PendingReclaimTrash) -> String {
        var message = "\(pending.count) items (\(byteString(pending.bytes))) will be moved to the "
            + "Trash. Everything can be put back from the Trash."
        if pending.warnsLosesState {
            message += "\n\nSome selected items hold data that cannot be regenerated "
                + "(see their category descriptions)."
        }
        return message
    }
}

/// A minimal tap-to-toggle checkbox supporting an indeterminate (mixed) state, which the macOS
/// `Toggle` checkbox style cannot show. Used for both group headers and item rows.
private struct ReclaimCheckbox: View {
    enum State { case off, on, mixed }

    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(state == .off ? Color.secondary : Color.accentColor)
        }
        .buttonStyle(.plain)
    }

    private var symbol: String {
        switch state {
        case .off: return "square"
        case .on: return "checkmark.square.fill"
        case .mixed: return "minus.square.fill"
        }
    }
}

/// One group's section header: a tri-state checkbox that selects/deselects the whole group, the
/// category name, its risk badge and total, and the category's consequence as a caption below.
private struct ReclaimGroupHeader: View {
    let group: ReclaimGroup
    let state: ReclaimCheckbox.State
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                ReclaimCheckbox(state: state, action: onToggle)
                Text(group.category.displayName)
                    .font(.headline)
                RiskBadge(category: group.category)
                Spacer(minLength: 8)
                Text(byteString(group.totalBytes))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Text(group.category.consequence)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

/// One reclaimable item: a checkbox bound to its selection, its path shown relative to the scan
/// root, and its size. Tapping the row toggles selection; the context menu reveals it in Finder.
private struct ReclaimItemRow: View {
    let item: ReclaimItem
    let rootName: String
    let isSelected: Bool
    let onToggle: () -> Void
    let onReveal: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ReclaimCheckbox(state: isSelected ? .on : .off, action: onToggle)
            Text(relativePath)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(byteString(item.bytes))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
        .contextMenu {
            Button {
                onReveal()
            } label: {
                Label("Reveal in Finder", systemImage: "magnifyingglass")
            }
        }
    }

    /// `item.path` with the scan root's absolute-path prefix (`rootName`) stripped, so a deep item
    /// reads as its location within the scan rather than a full absolute path. Falls back to the
    /// absolute path if the prefix does not match.
    private var relativePath: String {
        guard !rootName.isEmpty, item.path.hasPrefix(rootName) else { return item.path }
        var remainder = String(item.path.dropFirst(rootName.count))
        if remainder.hasPrefix("/") { remainder.removeFirst() }
        return remainder.isEmpty ? item.path : remainder
    }
}
