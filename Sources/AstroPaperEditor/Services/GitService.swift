import Foundation

final class GitService {
    func status(at projectRoot: URL) async -> GitRepositoryStatus {
        do {
            _ = try runGit(["rev-parse", "--is-inside-work-tree"], at: projectRoot)
        } catch {
            return GitRepositoryStatus(
                isRepository: false,
                branch: "",
                remoteURL: "",
                hasChanges: false,
                summary: "Git is not initialized"
            )
        }

        let branch = (try? runGit(["branch", "--show-current"], at: projectRoot).trimmedOutput) ?? ""
        let remote = (try? runGit(["remote", "get-url", "origin"], at: projectRoot).trimmedOutput) ?? ""
        let changes = (try? runGit(["status", "--short"], at: projectRoot).trimmedOutput) ?? ""

        return GitRepositoryStatus(
            isRepository: true,
            branch: branch,
            remoteURL: remote,
            hasChanges: !changes.isEmpty,
            summary: changes.isEmpty ? "Working tree clean" : changes
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

        let branch = (try? runGit(["branch", "--show-current"], at: projectRoot).trimmedOutput) ?? ""
        guard !branch.isEmpty else {
            throw GitServiceError.missingBranch
        }

        let beforeAdd = try runGit(["status", "--short"], at: projectRoot).trimmedOutput
        guard !beforeAdd.isEmpty else {
            return "No changes to commit."
        }

        var log = ""
        log += try runGit(["add", "."], at: projectRoot).output

        let staged = try runGit(["diff", "--cached", "--name-only"], at: projectRoot).trimmedOutput
        guard !staged.isEmpty else {
            return "No staged changes to commit."
        }

        log += try runGit(["commit", "-m", cleanMessage], at: projectRoot).output
        log += try runGit(["push", "-u", "origin", branch], at: projectRoot).output
        return log.isEmpty ? "Pushed \(branch)." : log
    }

    private func isRepository(at projectRoot: URL) -> Bool {
        (try? runGit(["rev-parse", "--is-inside-work-tree"], at: projectRoot).trimmedOutput) == "true"
    }

    private func hasOrigin(at projectRoot: URL) -> Bool {
        (try? runGit(["remote", "get-url", "origin"], at: projectRoot).trimmedOutput.isEmpty) == false
    }

    @discardableResult
    private func runGit(_ arguments: [String], at projectRoot: URL) throws -> GitCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = projectRoot

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw GitServiceError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return GitCommandResult(output: output)
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
    case missingBranch
    case missingRemote
    case notRepository

    var errorDescription: String? {
        switch self {
        case .commandFailed(let output):
            return output.isEmpty ? "Git command failed." : output
        case .emptyCommitMessage:
            return "Commit message is required."
        case .invalidBranch:
            return "Branch name is required."
        case .invalidRemoteURL:
            return "Remote URL is required."
        case .missingBranch:
            return "Current Git branch could not be detected."
        case .missingRemote:
            return "Git remote origin is not configured."
        case .notRepository:
            return "Git is not initialized for this project."
        }
    }
}

