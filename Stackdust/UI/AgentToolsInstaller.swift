import AppKit
import Foundation

/// Help-menu installers that expose the app's agent-facing surface: a PATH symlink
/// for the CLI embedded at Contents/Helpers/stackdust, and the bundled SKILL.md for
/// AI coding agents.
enum AgentToolsInstaller {
    /// Symlink, not a copy, so Sparkle updates keep the installed CLI current.
    private static let cliLinkPath = "/usr/local/bin/stackdust"

    private static var bundledCLI: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/stackdust")
    }

    // MARK: - Command line tool

    @MainActor
    static func installCommandLineTool() {
        let cli = bundledCLI
        guard FileManager.default.isExecutableFile(atPath: cli.path) else {
            alert(.warning, "The bundled CLI is missing",
                  "\(cli.path) was not found. Reinstall Stackdust to restore it.")
            return
        }
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: cliLinkPath)) == cli.path {
            alert(.informational, "Command line tool already installed",
                  "\(cliLinkPath) already points to this app. Run `stackdust --help` in a terminal.")
            return
        }
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try linkCLI(to: cli.path)
                }.value
                alert(.informational, "Command line tool installed",
                      "Created \(cliLinkPath). Run `stackdust --help` in a terminal to get started.")
            } catch let error as PrivilegedRunError where error.isUserCancellation {
                // The user dismissed the authorization dialog; that is an answer, not an error.
            } catch {
                alert(.warning, "Could not install the command line tool",
                      error.localizedDescription)
            }
        }
    }

    private static func linkCLI(to destination: String) throws {
        do {
            let fm = FileManager.default
            // Trash rather than delete whatever occupies the link path; a stale
            // install stays recoverable.
            if fm.fileExists(atPath: cliLinkPath) ||
                (try? fm.destinationOfSymbolicLink(atPath: cliLinkPath)) != nil {
                try fm.trashItem(at: URL(fileURLWithPath: cliLinkPath), resultingItemURL: nil)
            }
            try fm.createSymbolicLink(atPath: cliLinkPath, withDestinationPath: destination)
        } catch {
            // No write access to /usr/local/bin (or it does not exist): retry as admin.
            try linkCLIWithPrivileges(to: destination)
        }
    }

    private static func linkCLIWithPrivileges(to destination: String) throws {
        let singleQuoted = destination.replacingOccurrences(of: "'", with: "'\\''")
        let shell = "mkdir -p /usr/local/bin && ln -sf '\(singleQuoted)' \(cliLinkPath)"
        let appleScriptQuoted = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let osascript = Process()
        osascript.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osascript.arguments = ["-e", "do shell script \"\(appleScriptQuoted)\" with administrator privileges"]
        let stderr = Pipe()
        osascript.standardError = stderr
        try osascript.run()
        osascript.waitUntilExit()
        if osascript.terminationStatus != 0 {
            let detail = String(data: stderr.fileHandleForReading.readDataToEndOfFile(),
                                encoding: .utf8) ?? ""
            throw PrivilegedRunError(detail: detail)
        }
    }

    private struct PrivilegedRunError: LocalizedError {
        let detail: String

        /// osascript reports a dismissed authorization dialog as AppleScript error -128.
        var isUserCancellation: Bool { detail.contains("-128") }
        var errorDescription: String? {
            let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Installation failed." : trimmed
        }
    }

    // MARK: - Agent skills

    /// Agents that read the Agent Skills format (SKILL.md). The marker directory is
    /// evidence the agent is installed; skills go to its user-level skills directory
    /// (Codex reads the shared ~/.agents/skills).
    private static let skillTargets: [(agent: String, marker: String, skillsDir: String)] = [
        ("Claude Code", "~/.claude", "~/.claude/skills"),
        ("Codex", "~/.codex", "~/.agents/skills"),
    ]

    @MainActor
    static func installAgentSkills() {
        guard let skill = Bundle.main.url(forResource: "StackdustSkill", withExtension: "md"),
              let content = try? Data(contentsOf: skill) else {
            alert(.warning, "The bundled skill is missing",
                  "StackdustSkill.md was not found in the app's resources. Reinstall Stackdust to restore it.")
            return
        }
        let fm = FileManager.default
        var installed: [String] = []
        var failed: [String] = []
        for target in skillTargets {
            guard fm.fileExists(atPath: NSString(string: target.marker).expandingTildeInPath) else {
                continue
            }
            let dir = URL(fileURLWithPath: NSString(string: target.skillsDir).expandingTildeInPath)
                .appendingPathComponent("stackdust")
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                try content.write(to: dir.appendingPathComponent("SKILL.md"))
                installed.append("\(target.agent): \(target.skillsDir)/stackdust/SKILL.md")
            } catch {
                failed.append("\(target.agent): \(error.localizedDescription)")
            }
        }
        if installed.isEmpty && failed.isEmpty {
            let lookedFor = skillTargets.map { "\($0.marker) (\($0.agent))" }.joined(separator: ", ")
            alert(.informational, "No supported agents found",
                  "Looked for \(lookedFor). Install one of these agents and try again.")
        } else if failed.isEmpty {
            alert(.informational, "Agent skills installed",
                  "The stackdust skill now teaches these agents to scan and clean disk space:\n\n"
                  + installed.joined(separator: "\n"))
        } else {
            alert(.warning, "Some skills could not be installed",
                  (installed.isEmpty ? "" : "Installed:\n" + installed.joined(separator: "\n") + "\n\n")
                  + "Failed:\n" + failed.joined(separator: "\n"))
        }
    }

    // MARK: -

    @MainActor
    private static func alert(_ style: NSAlert.Style, _ title: String, _ message: String) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
