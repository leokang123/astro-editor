import Foundation

@MainActor
final class GitController: ObservableObject {
    @Published var log = ""
    @Published var status = GitRepositoryStatus.unknown
    @Published var isOperationRunning = false

    private let gitService: GitService

    init(gitService: GitService = GitService()) {
        self.gitService = gitService
    }

    var canRunOperation: Bool {
        !isOperationRunning
    }

    func refreshStatus(at projectRoot: URL) {
        let service = gitService
        status = GitRepositoryStatus(
            isRepository: false,
            branch: "",
            remoteURL: "",
            hasChanges: false,
            summary: "Loading Git status...",
            projectRootPath: projectRoot.path,
            gitExecutablePath: ""
        )

        Task.detached { [service, projectRoot] in
            let refreshedStatus = await service.status(at: projectRoot)
            await MainActor.run { [weak self] in
                self?.status = refreshedStatus
            }
        }
    }

    func configure(
        at projectRoot: URL,
        remoteURL: String,
        branch: String,
        onStatusText: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        guard !isOperationRunning else { return }
        let service = gitService
        isOperationRunning = true
        log = ""
        onStatusText("Configuring Git...")

        Task.detached { [service, projectRoot, remoteURL, branch] in
            do {
                let output = try service.configure(at: projectRoot, remoteURL: remoteURL, branch: branch)
                let refreshedStatus = await service.status(at: projectRoot)
                await MainActor.run { [weak self] in
                    self?.log = output
                    self?.status = refreshedStatus
                    self?.isOperationRunning = false
                    onStatusText("Git remote configured")
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isOperationRunning = false
                    onError(error.localizedDescription)
                }
            }
        }
    }

    func commitAndPush(
        at projectRoot: URL,
        message: String,
        onStatusText: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        guard !isOperationRunning else { return }
        let service = gitService
        isOperationRunning = true
        log = ""
        onStatusText("Committing and pushing...")

        Task.detached { [service, projectRoot, message] in
            do {
                let output = try await service.commitAndPush(at: projectRoot, message: message)
                let refreshedStatus = await service.status(at: projectRoot)
                await MainActor.run { [weak self] in
                    self?.log = output
                    self?.status = refreshedStatus
                    self?.isOperationRunning = false
                    onStatusText(output == "No changes to commit." ? "No changes to commit" : "Pushed to GitHub")
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isOperationRunning = false
                    onError(error.localizedDescription)
                }
            }
        }
    }
}
