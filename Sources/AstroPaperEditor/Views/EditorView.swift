import SwiftUI

struct EditorView: View {
    let document: BlogDocument?
    let hasProject: Bool
    let editorMode: EditorMode
    let editorTopLine: Int
    let projectRoot: URL
    var onOpenProject: () -> Void
    var onCloseUnavailableDocument: () -> Void
    var onTogglePreview: () -> Void
    var onTextChange: () -> Void
    var onRegisterBodyProvider: (((() -> String?)?) -> Void)
    var onRegisterTopLineProvider: (((() -> Int?)?) -> Void)
    var onInsertImages: ([PastedImage]) -> String
    var onSourceLineChange: (Int) -> Void
    let contentMaxWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            if let document {
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
                            MarkdownPreviewView(
                                document: document,
                                projectRoot: projectRoot,
                                sourceLine: editorTopLine,
                                onSourceLineChange: { line in
                                    onSourceLineChange(line)
                                }
                            )
                            .opacity(editorMode == .preview ? 1 : 0)
                            .allowsHitTesting(editorMode == .preview)
                            .accessibilityHidden(editorMode != .preview)

                            MarkdownTextView(
                                documentID: document.fileURL.path,
                                text: document.body,
                                targetLine: editorTopLine,
                                isActive: editorMode == .edit,
                                onTextChange: {
                                    onTextChange()
                                },
                                onRegisterBodyProvider: { provider in
                                    onRegisterBodyProvider(provider)
                                },
                                onRegisterTopLineProvider: { provider in
                                    onRegisterTopLineProvider(provider)
                                },
                                onInsertImages: { images in
                                    onInsertImages(images)
                                },
                                onTogglePreview: onTogglePreview
                            )
                            .opacity(editorMode == .edit ? 1 : 0)
                            .allowsHitTesting(editorMode == .edit)
                            .accessibilityHidden(editorMode != .edit)
                        }
                        .frame(maxWidth: contentMaxWidth)
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
