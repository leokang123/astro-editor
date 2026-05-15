import Foundation

final class GitService {
    func status(at projectRoot: URL) async -> GitRepositoryStatus {
        let gitPath = (try? gitExecutableURL().path) ?? "Not found"

        do {
            _ = try runGit(["rev-parse", "--is-inside-work-tree"], at: projectRoot)
        } catch {
            return GitRepositoryStatus(
                isRepository: false,
                branch: "",
                remoteURL: "",
                hasChanges: false,
                summary: error.localizedDescription,
                projectRootPath: projectRoot.path,
                gitExecutablePath: gitPath
            )
        }

        let branch = currentBranch(at: projectRoot)
        let remote = (try? runGit(["remote", "get-url", "origin"], at: projectRoot).trimmedOutput) ?? ""
        let changes = (try? runGit(["status", "--short"], at: projectRoot).trimmedOutput) ?? ""
        let summary = changes.isEmpty ? "Working tree clean" : summarizeChanges(changes)

        return GitRepositoryStatus(
            isRepository: true,
            branch: branch,
            remoteURL: remote,
            hasChanges: !changes.isEmpty,
            summary: summary,
            projectRootPath: projectRoot.path,
            gitExecutablePath: gitPath
        )
    }

    func configure(at projectRoot: URL, remoteURL: String, branch: String) throws -> String {
        let cleanRemote = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanRemote.isEmpty else {
            throw GitServiceError.invalidRemoteURL
        }
        guard !cleanBranch.isEmpty else {
            throw GitServiceError.invalidBranch
        }

        var log = ""
        if !isRepository(at: projectRoot) {
            log += try runGit(["init"], at: projectRoot).output
        }

        log += try runGit(["branch", "-M", cleanBranch], at: projectRoot).output

        if hasOrigin(at: projectRoot) {
            log += try runGit(["remote", "set-url", "origin", cleanRemote], at: projectRoot).output
        } else {
            log += try runGit(["remote", "add", "origin", cleanRemote], at: projectRoot).output
        }

        return log.isEmpty ? "Git remote configured." : log
    }

    func commitAndPush(at projectRoot: URL, message: String) async throws -> String {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMessage.isEmpty else {
            throw GitServiceError.emptyCommitMessage
        }
        guard isRepository(at: projectRoot) else {
            throw GitServiceError.notRepository
        }

        let remote = (try? runGit(["remote", "get-url", "origin"], at: projectRoot).trimmedOutput) ?? ""
        guard !remote.isEmpty else {
            throw GitServiceError.missingRemote
        }

        let branch = currentBranch(at: projectRoot)
        guard !branch.isEmpty else {
            throw GitServiceError.missingBranch
        }

        let beforeAdd = try runGit(["status", "--short"], at: projectRoot).trimmedOutput
        guard !beforeAdd.isEmpty else {
            return "No changes to commit."
        }

        _ = try runGit(["add", "."], at: projectRoot)

        let staged = try runGit(["diff", "--cached", "--name-only"], at: projectRoot).trimmedOutput
        guard !staged.isEmpty else {
            return "No staged changes to commit."
        }
        let stagedCount = staged.split(separator: "\n", omittingEmptySubsequences: true).count

        _ = try runGit(["commit", "-m", cleanMessage], at: projectRoot)
        _ = try runGit(["push", "-u", "origin", branch], at: projectRoot)
        return "Pushed to \(branch) (\(stagedCount) \(stagedCount == 1 ? "file" : "files"))."
    }

    private func isRepository(at projectRoot: URL) -> Bool {
        (try? runGit(["rev-parse", "--is-inside-work-tree"], at: projectRoot).trimmedOutput) == "true"
    }

    private func hasOrigin(at projectRoot: URL) -> Bool {
        (try? runGit(["remote", "get-url", "origin"], at: projectRoot).trimmedOutput.isEmpty) == false
    }

    private func currentBranch(at projectRoot: URL) -> String {
        let commands = [
            ["branch", "--show-current"],
            ["symbolic-ref", "--quiet", "--short", "HEAD"],
            ["rev-parse", "--abbrev-ref", "HEAD"],
        ]

        for command in commands {
            let output = (try? runGit(command, at: projectRoot).trimmedOutput) ?? ""
            if !output.isEmpty, output != "HEAD" {
                return output
            }
        }

        return ""
    }

    @discardableResult
    private func runGit(_ arguments: [String], at projectRoot: URL) throws -> GitCommandResult {
        let process = Process()
        process.executableURL = try gitExecutableURL()
        process.arguments = arguments
        process.currentDirectoryURL = projectRoot
        process.environment = processEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw GitServiceError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return GitCommandResult(output: output)
    }

    private func summarizeChanges(_ changes: String) -> String {
        let lines = changes
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        let preview = lines.prefix(8).joined(separator: "\n")

        if lines.count <= 8 {
            return preview
        }

        return "\(lines.count) changed files\n\(preview)\n..."
    }

    private func gitExecutableURL() throws -> URL {
        let candidates = [
            "/opt/homebrew/bin/git",
            "/usr/local/bin/git",
            "/usr/bin/git",
        ]

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        throw GitServiceError.gitNotFound
    }

    private func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["HOME"] = NSHomeDirectory()
        return environment
    }
}

private struct GitCommandResult {
    var output: String

    var trimmedOutput: String {
        output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum GitServiceError: LocalizedError {
    case commandFailed(String)
    case emptyCommitMessage
    case invalidBranch
    case invalidRemoteURL
    case gitNotFound
    case missingBranch
    case missingRemote
    case notRepository

    var errorDescription: String? {
        switch self {
        case .commandFailed(let output):
            return output.isEmpty ? "Git command failed." : "Git command failed: \(output)"
        case .emptyCommitMessage:
            return "Commit message is required."
        case .invalidBranch:
            return "Branch name is required."
        case .invalidRemoteURL:
            return "Remote URL is required."
        case .gitNotFound:
            return "Git executable was not found. Install Git or Xcode Command Line Tools."
        case .missingBranch:
            return "Current Git branch could not be detected."
        case .missingRemote:
            return "Git remote origin is not configured."
        case .notRepository:
            return "Git is not initialized for this project."
        }
    }
}
