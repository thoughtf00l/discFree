# DiscFree

A macOS disk-space analyzer that knows what developer junk looks like.

DiscFree scans a folder (or the whole disk), shows where the space went as an
interactive sunburst chart, and highlights things that are safe to reclaim:
Xcode DerivedData, old simulators, package-manager caches, `node_modules`,
Rust `target` directories, Docker VM disks, and more. Cleanup always moves
items to the Trash — nothing is ever deleted permanently.

It ships in two forms sharing the same scanning core:

- **DiscFree.app** — a SwiftUI app with a sunburst chart, dev-junk highlighting,
  and one-click Move to Trash.
- **`discfree` CLI** — built for AI coding agents and scripts: JSON output,
  stable exit codes, never interactive, same Trash-only safety contract.

## How this was built

This project was created by Claude, Anthropic's AI models — not written by a
human programmer. Claude Opus wrote the code and Claude Fable 5 reviewed and
committed it. The human in the loop, [@thoughtf00l](https://github.com/thoughtf00l),
provided the idea, high-level direction, and occasional course corrections,
but none of the code. The same applies to this README.

## Install

Requires macOS 15 (Sequoia) or later. The app is a universal binary
(Apple Silicon and Intel).

### Homebrew

```sh
brew tap thoughtf00l/tap
brew trust thoughtf00l/tap   # one-time, required by Homebrew 6+
brew install --cask discfree
```

The app is not notarized; the cask clears the macOS quarantine flag on
install, so it opens without a Gatekeeper prompt.

### Manual download

Download `DiscFree.zip` from the [latest release](https://github.com/thoughtf00l/discFree/releases/latest),
unzip it into `/Applications`, then either allow the app in
System Settings → Privacy & Security → **Open Anyway**, or clear the
quarantine flag yourself:

```sh
xattr -d com.apple.quarantine /Applications/DiscFree.app
```

### Build from source

Requires Xcode 16 or later.

```sh
git clone https://github.com/thoughtf00l/discFree.git
cd discFree

# The app
xcodebuild -project DiscFree.xcodeproj -scheme DiscFree -configuration Release build

# The CLI
swift build -c release   # binary lands at .build/release/discfree
```

## Full Disk Access

Scanning protected locations (`~/Library`, Desktop, Documents, …) requires
Full Disk Access — grant it in System Settings → Privacy & Security →
Full Disk Access. For the CLI, grant it to the **terminal app** the CLI runs
in, not to `discfree` itself. Scanning unprotected paths needs no setup.

## The `discfree` CLI

```sh
discfree scan ~/dev --json        # disk usage as a size-sorted tree
discfree dev ~/dev --json         # developer-reclaimable items, largest first
discfree clean ~/dev --category xcodeBuild --min-size 500M   # prints the plan, touches nothing
discfree clean ~/dev --category xcodeBuild --min-size 500M --yes   # moves to Trash
```

Without `--yes`, `clean` only prints what it would do. With `--yes`, selected
items are moved to the Trash (recoverable), never unlinked. See
[AGENTS.md](AGENTS.md) for the full contract: JSON shapes, exit codes, and
the recommended agent workflow.

## Safety

- Deletion means `FileManager.trashItem` — everything goes to the Trash and
  can be put back.
- Only items the classifier recognized as developer artifacts can be selected
  for cleanup.
- The CLI never prompts and never reads stdin; without `--yes` it never
  modifies anything.

## License

[MIT](LICENSE)
