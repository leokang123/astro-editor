import SwiftUI

struct CommitPushSheet: View {
    @ObservedObject var store: BlogStore
    @Binding var activeSheet: ActiveSheet?
    @State private var commitMessage = "Update blog"

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
                        Text(store.gitStatus.branch.isEmpty ? "-" : store.gitStatus.branch)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("Remote")
                            .foregroundStyle(.secondary)
                        Text(store.gitStatus.remoteURL.isEmpty ? "Not configured" : store.gitStatus.remoteURL)
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

            if !store.gitLog.isEmpty {
                Text(store.gitLog)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
            }

            HStack {
                Button {
                    store.refreshGitStatus()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isGitOperationRunning)

                Spacer()

                Button("Cancel") {
                    activeSheet = nil
                }
                .keyboardShortcut(.cancelAction)
                .disabled(store.isGitOperationRunning)

                Button {
                    store.commitAndPush(message: commitMessage)
                } label: {
                    Label(store.isGitOperationRunning ? "Pushing" : "Commit & Push", systemImage: "paperplane")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(store.isGitOperationRunning || commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            store.refreshGitStatus()
        }
    }

    private var changesText: String {
        if store.gitStatus.summary == "Loading Git status..." {
            return "Checking..."
        }
        guard store.gitStatus.isRepository else { return "Unavailable" }
        guard store.gitStatus.hasChanges else { return "Working tree clean" }
        return store.gitStatus.summary.components(separatedBy: "\n").first ?? "Changed files found"
    }
}
