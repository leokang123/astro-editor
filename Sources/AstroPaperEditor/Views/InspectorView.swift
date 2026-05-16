import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct InspectorView: View {
    let document: BlogDocument?
    var onUpdateFrontmatter: ((inout Frontmatter) -> Void) -> Void
    var onFrontmatterChange: () -> Void
    var onRegisterFrontmatterProvider: ((FrontmatterDraftProvider?) -> Void)
    var onSetOGImage: (URL) -> Void
    var onClearOGImage: () -> Void
    var onResolveAssetImageURL: (String?) -> URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Frontmatter", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
            }
            .padding(14)
            .background(.bar)

            if let document {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        FrontmatterDraftEditor(
                            documentID: document.id,
                            frontmatter: document.frontmatter,
                            onDraftChange: onFrontmatterChange,
                            onRegisterProvider: onRegisterFrontmatterProvider,
                            onCommit: { draft in
                                onUpdateFrontmatter {
                                    $0.title = draft.title
                                    $0.order = draft.order
                                    $0.pubDatetime = draft.pubDatetime
                                    $0.modDatetime = draft.modDatetime
                                    $0.description = draft.description
                                    $0.featured = draft.featured
                                    $0.tags = draft.tags
                                }
                            }
                        )

                        InspectorCard {
                            OGImageInspector(
                                document: document,
                                onSetOGImage: onSetOGImage,
                                onClearOGImage: onClearOGImage,
                                onResolveAssetImageURL: onResolveAssetImageURL
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

private struct FrontmatterDraftEditor: View {
    let documentID: String
    let frontmatter: Frontmatter
    var onDraftChange: () -> Void
    var onRegisterProvider: ((FrontmatterDraftProvider?) -> Void)
    var onCommit: (Frontmatter) -> Void
    @State private var draft: Frontmatter
    @State private var tagsDraft: String
    @FocusState private var focusedField: FrontmatterFocusField?

    init(
        documentID: String,
        frontmatter: Frontmatter,
        onDraftChange: @escaping () -> Void,
        onRegisterProvider: @escaping ((FrontmatterDraftProvider?) -> Void),
        onCommit: @escaping (Frontmatter) -> Void
    ) {
        self.documentID = documentID
        self.frontmatter = frontmatter
        self.onDraftChange = onDraftChange
        self.onRegisterProvider = onRegisterProvider
        self.onCommit = onCommit
        _draft = State(initialValue: frontmatter)
        _tagsDraft = State(initialValue: frontmatter.tags.joined(separator: "\n"))
    }

    var body: some View {
        Group {
            InspectorCard {
                FieldRow("Title") {
                    TextField("Title", text: frontmatterBinding(\.title))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .title)
                }
                Divider()
                FieldRow("Order") {
                    TextField("Order", text: orderBinding)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .order)
                }
                Divider()
                FieldRow("Description", alignment: .top) {
                    TextField("Description", text: frontmatterBinding(\.description), axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .description)
                }
                Divider()
                Toggle("Featured", isOn: featuredBinding)
                Divider()
                FieldRow("Published") {
                    TextField("Published", text: frontmatterBinding(\.pubDatetime))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .published)
                }
                Divider()
                FieldRow("Modified") {
                    TextField("Modified", text: frontmatterBinding(\.modDatetime))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .modified)
                }
            }

            InspectorCard {
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
                        get: { tagsDraft },
                        set: { value in
                            guard tagsDraft != value else { return }
                            tagsDraft = value
                            handleDraftChange()
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
                    .focused($focusedField, equals: .tags)
                }
            }
        }
        .onAppear {
            registerProvider()
        }
        .onChange(of: documentID) { _ in
            resetDraft(to: frontmatter)
            registerProvider()
        }
        .onChange(of: frontmatter) { updatedFrontmatter in
            if focusedField == nil {
                resetDraft(to: updatedFrontmatter)
            } else {
                syncExternalFields(from: updatedFrontmatter)
            }
            registerProvider()
        }
        .onChange(of: focusedField) { focusedField in
            if focusedField == nil {
                commitDraft()
            }
        }
        .onDisappear {
            onRegisterProvider(nil)
        }
    }

    private var currentDraft: Frontmatter {
        var value = draft
        value.tags = tagsDraft.trimmingForTags
        return value
    }

    private var draftApplier: FrontmatterDraftApplier {
        let draft = currentDraft
        return { frontmatter in
            frontmatter.title = draft.title
            frontmatter.order = draft.order
            frontmatter.pubDatetime = draft.pubDatetime
            frontmatter.modDatetime = draft.modDatetime
            frontmatter.description = draft.description
            frontmatter.featured = draft.featured
            frontmatter.tags = draft.tags
        }
    }

    private func frontmatterBinding(_ keyPath: WritableKeyPath<Frontmatter, String>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { value in
                guard draft[keyPath: keyPath] != value else { return }
                draft[keyPath: keyPath] = value
                handleDraftChange()
            }
        )
    }

    private var orderBinding: Binding<String> {
        Binding(
            get: { draft.order ?? "" },
            set: { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                let order = trimmed.isEmpty ? nil : trimmed
                guard draft.order != order else { return }
                draft.order = order
                handleDraftChange()
            }
        )
    }

    private var featuredBinding: Binding<Bool> {
        Binding(
            get: { draft.featured == true },
            set: { value in
                let featured = value ? true : nil
                guard draft.featured != featured else { return }
                draft.featured = featured
                handleDraftChange()
                commitDraft()
            }
        )
    }

    private func handleDraftChange() {
        registerProvider()
        onDraftChange()
    }

    private func commitDraft() {
        registerProvider()
        onCommit(currentDraft)
    }

    private func resetDraft(to frontmatter: Frontmatter) {
        draft = frontmatter
        tagsDraft = frontmatter.tags.joined(separator: "\n")
    }

    private func syncExternalFields(from frontmatter: Frontmatter) {
        draft.extraLines = frontmatter.extraLines
    }

    private func registerProvider() {
        onRegisterProvider { draftApplier }
    }

    private enum FrontmatterFocusField: Hashable {
        case title
        case order
        case description
        case published
        case modified
        case tags
    }
}

private struct OGImageInspector: View {
    let document: BlogDocument
    var onSetOGImage: (URL) -> Void
    var onClearOGImage: () -> Void
    var onResolveAssetImageURL: (String?) -> URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("OG Image")
                Spacer()
                if hasImage {
                    Button("Clear") {
                        onClearOGImage()
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
        document.frontmatter.ogImage?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var imageURL: URL? {
        onResolveAssetImageURL(document.frontmatter.ogImage)
    }

    private var nsImage: NSImage? {
        guard let imageURL else { return nil }
        return NSImage(contentsOf: imageURL)
    }

    private var imageLabel: String {
        imageURL?.lastPathComponent ?? "OG image"
    }

    private var ogImagePath: String {
        document.frontmatter.ogImage ?? ""
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic, .webP]
        panel.message = "Choose an image to copy into src/assets/images and use as ogImage."

        if panel.runModal() == .OK, let url = panel.url {
            onSetOGImage(url)
        }
    }
}
