import AppKit
import SwiftUI

struct AssetImagePreferencesView: View {
    @ObservedObject var store: BlogStore
    @State private var preview: AssetImageCleanupPreview?
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Asset Images")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Finds files in src/assets/images that are not referenced by blog and page source files.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    scan()
                } label: {
                    Label(store.isAssetScanRunning ? "Scanning" : "Scan", systemImage: "magnifyingglass")
                }
                .disabled(store.isAssetScanRunning || store.isAssetOptimizeRunning)

                Button {
                    optimize()
                } label: {
                    Label(store.isAssetOptimizeRunning ? "Optimizing" : "Optimize", systemImage: "trash")
                }
                .disabled(store.isAssetScanRunning || store.isAssetOptimizeRunning || preview?.unusedImages.isEmpty != false)
            }

            GroupBox("Rule") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A file is kept when its filename appears in blog posts, pages, layouts, components, or site settings.")
                    Text("Unused files are moved to the macOS Trash, not permanently deleted.")
                        .foregroundStyle(.secondary)
                    Text(store.projectRoot.appendingPathComponent("src/assets/images", isDirectory: true).path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            if store.isAssetScanRunning || store.isAssetOptimizeRunning {
                VStack(spacing: 10) {
                    ProgressView()
                    Text(store.isAssetScanRunning ? "Scanning asset references..." : "Moving unused images to Trash...")
                        .font(.headline)
                    Text("You can keep using the app while this runs.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let preview {
                GroupBox("Scan Result") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("\(preview.allImageCount) total", systemImage: "photo")
                            Label("\(preview.unusedCount) unused", systemImage: preview.unusedCount == 0 ? "checkmark.circle" : "exclamationmark.triangle")
                                .foregroundStyle(preview.unusedCount == 0 ? .green : .orange)
                            Spacer()
                        }

                        if preview.unusedImages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 34))
                                    .foregroundStyle(.green)
                                Text("No unused images found")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 6) {
                                    ForEach(preview.unusedImages, id: \.path) { url in
                                        Label(url.lastPathComponent, systemImage: "photo")
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                            }
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(8)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("No scan yet")
                        .font(.headline)
                    Text("Run Scan before optimizing assets/images.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Text(message.isEmpty ? store.assetCleanupMessage : message)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([
                        store.projectRoot.appendingPathComponent("src/assets/images", isDirectory: true)
                    ])
                } label: {
                    Label("Show in Finder", systemImage: "finder")
                }
            }
            .font(.caption)
        }
        .onAppear {
            if preview == nil, !store.assetCleanupMessage.isEmpty {
                message = store.assetCleanupMessage
            }
        }
    }

    private func scan() {
        message = "Scanning assets/images..."
        Task {
            if let result = await store.previewUnusedAssetImages() {
                preview = result
            }
            message = store.assetCleanupMessage
        }
    }

    private func optimize() {
        guard let preview, !preview.unusedImages.isEmpty else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Move unused images to Trash?"
        alert.informativeText = "\(preview.unusedCount) files in src/assets/images are not referenced by source files. They will be moved to the macOS Trash."
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let imagesToTrash = preview.unusedImages
        message = "Moving unused images to Trash..."
        Task {
            guard let result = await store.moveAssetImagesToTrash(imagesToTrash) else {
                message = store.assetCleanupMessage
                return
            }

            let trashedPaths = Set(result.trashedImages.map { $0.standardizedFileURL.path })
            var updatedPreview = preview
            updatedPreview.unusedImages.removeAll { trashedPaths.contains($0.standardizedFileURL.path) }
            updatedPreview.allImageCount = max(0, updatedPreview.allImageCount - result.trashedImages.count)
            self.preview = updatedPreview
            message = store.assetCleanupMessage
        }
    }
}
