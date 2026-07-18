---
name: stackdust
description: Analyze macOS disk usage and reclaim space with the stackdust CLI — scan directories, list reclaimable developer items (Xcode caches, simulators, package caches, node_modules), and move them to the Trash safely. Use when the user asks what is eating disk space, wants space freed, or wants build artifacts and caches cleaned.
---

# Stackdust CLI

`stackdust` analyzes disk usage on macOS and reclaims space safely: it never
prompts, never reads stdin, and never deletes permanently — cleaning moves items
to the Trash (recoverable). Primary data goes to stdout, progress and errors to
stderr.

Use `stackdust` from PATH; if it is not installed there, fall back to
`/Applications/Stackdust.app/Contents/Helpers/stackdust`.

## Commands

Pass `--json` to any subcommand for a single-line JSON object on stdout; errors
then become JSON on stderr:
`{"error": "<machine_code>", "message": "...", "path"?: "...", "hint"?: "..."}`.
A `truncated: true` field plus a stderr hint tell you when narrowing flags hid
data. SIZE values are decimal: `500M` = 500,000,000; `K`/`M`/`G`/`T`, fractions
allowed (`1.5G`).

- `stackdust scan <path> [--json] [--depth N] [--top N] [--min-size SIZE]` —
  disk usage as a size-sorted tree (defaults: `--depth 2`, `--top 20` children
  per directory). `bytes` is physical size on disk; hard links and APFS
  firmlink duplicates count once. Directories evicted to iCloud are reported
  with `cloud_evicted: true`, occupy ~no local space, and are not descended
  into.
- `stackdust dev [<path> ...] [--json] [--min-size SIZE]` — reclaimable
  developer items, largest first. Without paths, probes only the known cache
  and build locations (Xcode, simulators, package-manager caches, per-app
  caches, ...) — takes seconds. With paths, scans those directories fully —
  that is what finds `node_modules`/`target`/`.venv` scattered through a
  projects tree — and reports only items under them. Categories: `xcodeBuild`,
  `xcodeArchives`, `deviceSupport`, `simulators`, `packageCache`,
  `projectArtifacts`, `docker`, `appCaches`, `logs`, `iosBackups`,
  `adobeCache`. JSON:
  `{"items": [{"path", "category", "risk", "bytes"}], "total_bytes"}`.
- `stackdust clean [<path> ...] [--json] [--category c1,c2] [--min-size SIZE]
  [--yes] [--dry-run]` — trash selected reclaimable items. Selects exactly like
  `dev` with the same arguments; nothing outside the given directories is ever
  selected.

## Safety contract

- Without `--yes` (or with `--dry-run`), `clean` only prints the plan and
  exits 0 — nothing is touched.
- With `--yes` it moves the selected items to the Trash — never unlinks.
- Only items the classifier marked as dev items can ever be selected.
- Idempotent: a path that vanished between scan and trash is reported with
  `"note": "already gone"` and does not fail the run.

## Risk tiers

Every `dev`/`clean` item carries a `risk` token:

- `safe` — regenerated at no cost beyond build time (`xcodeBuild`, `logs`).
  May be cleaned autonomously when it meets the user's size goal.
- `costs_time` — comes back on demand, paying network and time
  (`packageCache`, `projectArtifacts`, `appCaches`, `adobeCache`,
  `deviceSupport`). May be cleaned autonomously.
- `loses_state` — trashing destroys non-reproducible state (`simulators`,
  `xcodeArchives`, `docker`, `iosBackups`). Propose these to the human and
  clean only after explicit confirmation.

## Recommended flow

1. `stackdust dev --json` — list reclaimable items in the known locations (fast).
   When the user's projects are in scope, add their directories:
   `stackdust dev ~/dev --json`.
2. Decide what meets the goal, then review the plan with the same paths:
   `stackdust clean --category xcodeBuild,packageCache --min-size 500M`
3. Re-run the same command with `--yes` to trash the items.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | success (partial data — e.g. some unreadable subdirectories — still counts) |
| 2 | usage error: bad flag value, unknown category, path is not a directory |
| 3 | path not found |
| 4 | permission denied on the scan root |
| 5 | partial failure: some `clean --yes` operations failed |

Exit code 4 usually means the terminal app lacks Full Disk Access: grant it in
System Settings → Privacy & Security → Full Disk Access, then restart the
terminal. Scanning unprotected paths needs no setup.
