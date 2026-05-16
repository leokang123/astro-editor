import AppKit
import SwiftUI

struct DeveloperPreferencesView: View {
    @ObservedObject var store: BlogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Developer")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Manual local build tools for development checks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.runBuild()
                } label: {
                    Label(store.isBuilding ? "Building" : "Docker Build", systemImage: "hammer")
                }
                .disabled(store.isBuilding)

                Button {
                    store.openLocalhost()
                } label: {
                    Label("Open Localhost", systemImage: "safari")
                }
            }

            GroupBox("Docker Compose") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Runs in the selected blog project root:")
                        .foregroundStyle(.secondary)
                    Text("docker compose up --build -d")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Text("Local preview URL: \(BuildService.localPreviewURL.absoluteString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(store.projectRoot.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            if store.buildLog.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "hammer")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("No Docker build log yet")
                        .font(.headline)
                    Text("Run Docker Build when you want to test the local container.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Log tail")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(store.buildLog)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
