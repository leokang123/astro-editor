import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NewDocumentSheet: View {
    @ObservedObject var store: BlogStore
    @Binding var activeSheet: ActiveSheet?
    @State private var title = ""
    @State private var description = ""
    @State private var tags = "general"
    @State private var order = ""
    @State private var featured = false
    @State private var ogImageURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Document")
                .font(.title2)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("general, notes", text: $tags)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Order")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Optional, e.g. 1", text: $order)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("Featured", isOn: $featured)

            VStack(alignment: .leading, spacing: 8) {
                Text("Social Preview Image")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(ogImageURL?.lastPathComponent ?? "Not selected")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(ogImageURL == nil ? .secondary : .primary)
                    Spacer()
                    if ogImageURL != nil {
                        Button("Remove") {
                            ogImageURL = nil
                        }
                    }
                    Button("Choose Image...") {
                        chooseOGImage()
                    }
                }
            }

            Text("Location: \(locationText)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Spacer()
                Button("Cancel") { activeSheet = nil }
                Button("Create") {
                    store.createDocument(
                        title: title,
                        description: description,
                        tagsText: tags,
                        order: order,
                        featured: featured,
                        ogImageSourceURL: ogImageURL,
                        parentID: store.creationParentID
                    )
                    activeSheet = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 460)
    }

    private func chooseOGImage() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic, .webP]
        panel.message = "Choose an image for social previews."

        if panel.runModal() == .OK {
            ogImageURL = panel.url
        }
    }

    private var locationText: String {
        store.creationLocationText(parentID: store.creationParentID)
    }
}
