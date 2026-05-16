import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct InspectorView: View {
    @ObservedObject var store: BlogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Frontmatter", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
            }
            .padding(14)
            .background(.bar)

            if let document = store.currentDocument {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        InspectorCard {
                            FieldRow("Title") {
                                TextField("Title", text: frontmatterBinding(\.title))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider()
                            FieldRow("Order") {
                                TextField("Order", text: orderBinding)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider()
                            FieldRow("Description", alignment: .top) {
                                TextField("Description", text: frontmatterBinding(\.description), axis: .vertical)
                                    .lineLimit(2...4)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider()
                            Toggle("Featured", isOn: featuredBinding)
                            Divider()
                            FieldRow("Published") {
                                TextField("Published", text: frontmatterBinding(\.pubDatetime))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider()
                            FieldRow("Modified") {
                                TextField("Modified", text: frontmatterBinding(\.modDatetime))
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                            }
                        }

                        InspectorCard {
                            OGImageInspector(store: store)
                        }

                        InspectorCard {
                            TagsEditor(
                                documentID: document.id,
                                tags: document.frontmatter.tags,
                                store: store
                            )
                        }

                        if !document.frontmatter.extraLines.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Preserved Extra Fields")
                                    .font(.headline)
                                Text(document.frontmatter.extraLines.joined(separator: "\n"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.quaternary.opacity(0.35))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding()
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No document selected")
                        .font(.headline)
                    Text("Create or open a document to edit AstroPaper frontmatter.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                Spacer()
            }
        }
    }

    private func frontmatterBinding(_ keyPath: WritableKeyPath<Frontmatter, String>) -> Binding<String> {
        Binding(
            get: { store.currentDocument?.frontmatter[keyPath: keyPath] ?? "" },
            set: { value in
                store.updateFrontmatter { $0[keyPath: keyPath] = value }
            }
        )
    }

    private var orderBinding: Binding<String> {
        Binding(
            get: { store.currentDocument?.frontmatter.order ?? "" },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                store.updateFrontmatter { $0.order = trimmed.isEmpty ? nil : trimmed }
            }
        )
    }

    private var featuredBinding: Binding<Bool> {
        Binding(
            get: { store.currentDocument?.frontmatter.featured == true },
            set: { value in
                store.updateFrontmatter { $0.featured = value ? true : nil }
            }
        )
    }
}

private struct InspectorCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct FieldRow<Content: View>: View {
    var title: String
    var alignment: VerticalAlignment
    @ViewBuilder var content: Content

    init(_ title: String, alignment: VerticalAlignment = .center, @ViewBuilder content: () -> Content) {
        self.title = title
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            content
        }
    }
}

private struct TagsEditor: View {
    let documentID: String
    let tags: [String]
    @ObservedObject var store: BlogStore
    @State private var draft: String

    init(documentID: String, tags: [String], store: BlogStore) {
        self.documentID = documentID
        self.tags = tags
        self.store = store
        _draft = State(initialValue: tags.joined(separator: "\n"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("comma or line")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            TextEditor(text: Binding(
                get: { draft },
                set: { value in
                    draft = value
                    store.updateFrontmatter { $0.tags = value.trimmingForTags }
                }
            ))
            .font(.body)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 92)
            .padding(6)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.separator, lineWidth: 1)
            }
        }
        .onChange(of: documentID) { _ in
            draft = tags.joined(separator: "\n")
        }
    }
}

private struct OGImageInspector: View {
    @ObservedObject var store: BlogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("OG Image")
                Spacer()
                if hasImage {
                    Button("Clear") {
                        store.clearOGImage()
                    }
                    .buttonStyle(.bordered)
                }
                Button("Choose...") {
                    chooseImage()
                }
                .buttonStyle(.borderedProminent)
            }

            Group {
                if let image = nsImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .bottomLeading) {
                            Text(imageLabel)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.thinMaterial)
                        }
                        .allowsHitTesting(false)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: hasImage ? "exclamationmark.triangle" : "photo")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(hasImage ? "Image file not found" : "No OG image")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 92)
                    .background(.quaternary.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
                }
            }
            .allowsHitTesting(false)

            if hasImage {
                Text(ogImagePath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .allowsHitTesting(false)
            }
        }
    }

    private var hasImage: Bool {
        store.currentDocument?.frontmatter.ogImage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var imageURL: URL? {
        store.resolvedAssetImageURL(store.currentDocument?.frontmatter.ogImage)
    }

    private var nsImage: NSImage? {
        guard let imageURL else { return nil }
        return NSImage(contentsOf: imageURL)
    }

    private var imageLabel: String {
        imageURL?.lastPathComponent ?? "OG image"
    }

    private var ogImagePath: String {
        store.currentDocument?.frontmatter.ogImage ?? ""
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic, .webP]
        panel.message = "Choose an image to copy into src/assets/images and use as ogImage."

        if panel.runModal() == .OK, let url = panel.url {
            store.setOGImage(from: url)
        }
    }
}
