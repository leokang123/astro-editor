import SwiftUI

struct EditorView: View {
    @State private var previewReadyDocumentID: String?
    @State private var editorReadyDocumentID: String?

    let document: BlogDocument?
    let hasProject: Bool
    let editorMode: EditorMode
    let previewDocumentID: String?
    let editorSourcePosition: Double
    let projectRoot: URL
    var onOpenProject: () -> Void
    var onCloseUnavailableDocument: () -> Void
    var onTogglePreview: () -> Void
    var onTextChange: () -> Void
    var onRegisterBodyProvider: (((() -> String?)?) -> Void)
    var onRegisterSourcePositionProvider: (((() -> Double?)?) -> Void)
    var onInsertImages: ([PastedImage]) -> String
    var onSourcePositionChange: (Double) -> Void
    let contentMaxWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            if let document {
                let documentID = document.fileURL.path
                let shouldMountPreview = editorMode == .preview || previewDocumentID == documentID
                let previewIsReady = previewReadyDocumentID == documentID
                let editorIsReady = editorReadyDocumentID == documentID
                let shouldShowPreview = previewIsReady && (editorMode == .preview || !editorIsReady)
                let shouldShowEditor = !shouldShowPreview
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text(document.relativePath)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if !hasProject {
                            Button {
                                onCloseUnavailableDocument()
                            } label: {
                                Label("Close", systemImage: "xmark.circle")
                            }
                            .help("Discard this unavailable document and return to the project picker")
                        }
                        Button {
                            onTogglePreview()
                        } label: {
                            Label(editorMode == .edit ? "Preview" : "Edit", systemImage: editorMode == .edit ? "doc.richtext" : "pencil")
                        }
                        .keyboardShortcut("e", modifiers: .command)
                        .help("Toggle Edit and Preview (Command+E)")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.bar)

                    ZStack {
                        Color(nsColor: .textBackgroundColor)

                        ZStack {
                            if shouldMountPreview {
                                MarkdownPreviewView(
                                    document: document,
                                    projectRoot: projectRoot,
                                    sourcePosition: editorSourcePosition,
                                    isActive: editorMode == .preview,
                                    onSourcePositionChange: { position in
                                        onSourcePositionChange(position)
                                    },
                                    onPreviewReady: {
                                        guard editorMode == .preview else { return }
                                        previewReadyDocumentID = documentID
                                    }
                                )
                                .opacity(shouldShowPreview ? 1 : 0)
                                .allowsHitTesting(shouldShowPreview)
                                .accessibilityHidden(editorMode != .preview)
                            }

                            MarkdownTextView(
                                documentID: document.fileURL.path,
                                text: document.body,
                                targetSourcePosition: editorSourcePosition,
                                isActive: editorMode == .edit,
                                onTextChange: {
                                    onTextChange()
                                },
                                onRegisterBodyProvider: { provider in
                                    onRegisterBodyProvider(provider)
                                },
                                onRegisterSourcePositionProvider: { provider in
                                    onRegisterSourcePositionProvider(provider)
                                },
                                onInsertImages: { images in
                                    onInsertImages(images)
                                },
                                onTogglePreview: {
                                    onTogglePreview()
                                },
                                onEditorReady: {
                                    guard editorMode == .edit else { return }
                                    editorReadyDocumentID = documentID
                                    previewReadyDocumentID = nil
                                }
                            )
                            .opacity(shouldShowEditor ? 1 : 0)
                            .allowsHitTesting(editorMode == .edit && shouldShowEditor)
                            .accessibilityHidden(editorMode != .edit)
                        }
                        .frame(maxWidth: contentMaxWidth)
                    }
                }
                .onChange(of: documentID) { _ in
                    previewReadyDocumentID = nil
                    editorReadyDocumentID = nil
                }
                .onChange(of: editorMode) { mode in
                    if mode == .preview {
                        previewReadyDocumentID = nil
                    } else {
                        editorReadyDocumentID = nil
                    }
                }
            } else if hasProject {
                VStack(spacing: 12) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Select a Markdown document")
                        .font(.title3)
                    Text("Documents are read only when opened.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Open a project")
                        .font(.title3)
                    Text("Open an existing AstroPaper project, or start a new one from an empty folder.")
                        .foregroundStyle(.secondary)
                    Button("Open Project...") {
                        onOpenProject()
                    }
                    .controlSize(.large)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
