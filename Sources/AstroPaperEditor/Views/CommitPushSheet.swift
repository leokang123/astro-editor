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

                    GridRow {
                        Text("Details")
                            .foregroundStyle(.secondary)
                        Text(store.gitStatus.summary)
                            .lineLimit(3)
                            .textSelection(.enabled)
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
                ScrollView {
                    Text(store.gitLog)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 80)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
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
        .frame(width: 520)
        .onAppear {
            store.refreshGitStatus()
        }
    }

    private var changesText: String {
        guard store.gitStatus.isRepository else { return "Unavailable" }
        return store.gitStatus.hasChanges ? "Changed files found" : "Working tree clean"
    }
}
