import SwiftUI

struct CommitPushSheet: View {
    @ObservedObject var gitController: GitController
    @Binding var activeSheet: ActiveSheet?
    @State private var commitMessage = "Update blog"
    var onRefreshGitStatus: () -> Void
    var onCommitAndPush: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Commit & Push")
                .font(.title2)
                .fontWeight(.semibold)

            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
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
                }
                .padding(8)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Commit message")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Commit message", text: $commitMessage)
                    .textFieldStyle(.roundedBorder)
            }

            if !gitController.log.isEmpty {
                Text(gitController.log)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
            }

            HStack {
                Button {
                    onRefreshGitStatus()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(gitController.isOperationRunning)

                Spacer()

                Button("Cancel") {
                    activeSheet = nil
                }
                .keyboardShortcut(.cancelAction)
                .disabled(gitController.isOperationRunning)

                Button {
                    onCommitAndPush(commitMessage)
                } label: {
                    Label(gitController.isOperationRunning ? "Pushing" : "Commit & Push", systemImage: "paperplane")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(gitController.isOperationRunning || commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            onRefreshGitStatus()
        }
    }

    private var changesText: String {
        if gitController.status.summary == "Loading Git status..." {
            return "Checking..."
        }
        guard gitController.status.isRepository else { return "Unavailable" }
        guard gitController.status.hasChanges else { return "Working tree clean" }
        return gitController.status.summary.components(separatedBy: "\n").first ?? "Changed files found"
    }
}
