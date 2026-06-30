import Foundation

struct GitRepositoryStatus: Equatable {
    var isRepository: Bool
    var branch: String
    var remoteURL: String
    var hasChanges: Bool
    var hasUnpushedCommits: Bool
    var summary: String
    var projectRootPath: String
    var gitExecutablePath: String

    static let unknown = GitRepositoryStatus(
        isRepository: false,
        branch: "",
        remoteURL: "",
        hasChanges: false,
        hasUnpushedCommits: false,
        summary: "Git status not loaded",
        projectRootPath: "",
        gitExecutablePath: ""
    )

    var representativeChangePath: String? {
        let lines = summary
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        let changeLine = lines.first { !$0.hasSuffix("changed files") && $0 != "..." }
        guard let changeLine else { return nil }

        guard changeLine.count > 2 else { return changeLine }
        let statusEnd = changeLine.index(changeLine.startIndex, offsetBy: 2)
        return String(changeLine[statusEnd...]).trimmingCharacters(in: .whitespaces)
    }
}
