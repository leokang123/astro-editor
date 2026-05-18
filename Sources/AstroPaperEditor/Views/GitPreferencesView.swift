import AppKit
import SwiftUI

struct GitPreferencesView: View {
    @ObservedObject var gitController: GitController
    let hasProject: Bool
    let projectRoot: URL
    var onRefreshGitStatus: () -> Void
    var onConfigureGit: (String, String) -> Void
    @State private var remoteURL = ""
    @State private var branch = "main"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Git")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Configure the repository used by Commit & Push.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onRefreshGitStatus()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!hasProject || gitController.isOperationRunning)
            }

            GroupBox("Status") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Project")
                            .foregroundStyle(.secondary)
                        Text(projectPathText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("Git")
                            .foregroundStyle(.secondary)
                        Text(gitController.status.gitExecutablePath.isEmpty ? "-" : gitController.status.gitExecutablePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("Repository")
                            .foregroundStyle(.secondary)
                        Text(gitController.status.isRepository ? "Initialized" : "Not initialized")
                    }

                    GridRow {
                        Text("Branch")
                            .foregroundStyle(.secondary)
                        Text(gitController.status.branch.isEmpty ? "-" : gitController.status.branch)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("Remote")
                            .foregroundStyle(.secondary)
                        Text(gitController.status.remoteURL.isEmpty ? "Not configured" : gitController.status.remoteURL)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("Changes")
                            .foregroundStyle(.secondary)
                        Text(changesText)
                    }

                    GridRow {
                        Text("Details")
                            .foregroundStyle(.secondary)
                        Text(gitController.status.summary)
                            .lineLimit(6)
                            .textSelection(.enabled)
                    }
                }
                .padding(8)
            }

            GroupBox("Remote") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Remote URL")
                            .foregroundStyle(.secondary)
                        TextField("https://github.com/user/repo.git", text: $remoteURL)
                            .textFieldStyle(.roundedBorder)
                            .disabled(!hasProject)
                    }

                    GridRow {
                        Text("Branch")
                            .foregroundStyle(.secondary)
                        TextField("main", text: $branch)
                            .textFieldStyle(.roundedBorder)
                            .disabled(!hasProject)
                    }
                }
                .padding(8)
            }

            HStack {
                Button {
                    loadCurrentStatusIntoFields()
                } label: {
                    Label("Use Current", systemImage: "arrow.down.doc")
                }
                .disabled(!hasProject)

                Spacer()

                Button {
                    onConfigureGit(remoteURL, branch)
                } label: {
                    Label(gitController.status.isRepository ? "Update Remote" : "Initialize Git", systemImage: "gearshape")
                }
                .disabled(!hasProject || gitController.isOperationRunning || remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || branch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !hasProject {
                ProjectRequiredPlaceholder()
            } else if !gitController.log.isEmpty {
                ScrollView {
                    Text(gitController.log)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: .infinity)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            } else {
                Spacer()
            }
        }
        .onAppear {
            if hasProject {
                onRefreshGitStatus()
                loadCurrentStatusIntoFields()
            }
        }
        .onChange(of: hasProject) { hasProject in
            if hasProject {
                onRefreshGitStatus()
                loadCurrentStatusIntoFields()
            }
        }
        .onChange(of: gitController.status) { status in
            guard hasProject else { return }
            if !status.remoteURL.isEmpty {
                remoteURL = status.remoteURL
            }
            if !status.branch.isEmpty {
                branch = status.branch
            }
        }
    }

    private var projectPathText: String {
        guard hasProject else { return "No project selected" }
        return gitController.status.projectRootPath.isEmpty ? projectRoot.path : gitController.status.projectRootPath
    }

    private func loadCurrentStatusIntoFields() {
        if !gitController.status.remoteURL.isEmpty {
            remoteURL = gitController.status.remoteURL
        }
        if !gitController.status.branch.isEmpty {
            branch = gitController.status.branch
        }
    }

    private var changesText: String {
        guard hasProject else { return "Unavailable" }
        guard gitController.status.isRepository else { return "Unavailable" }
        return gitController.status.hasChanges ? "Changed files found" : "Working tree clean"
    }
}
