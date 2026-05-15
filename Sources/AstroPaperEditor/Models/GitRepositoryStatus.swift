import Foundation

struct GitRepositoryStatus: Equatable {
    var isRepository: Bool
    var branch: String
    var remoteURL: String
    var hasChanges: Bool
    var summary: String

    static let unknown = GitRepositoryStatus(
        isRepository: false,
        branch: "",
        remoteURL: "",
        hasChanges: false,
        summary: "Git status not loaded"
    )
}

