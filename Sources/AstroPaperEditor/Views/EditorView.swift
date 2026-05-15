import SwiftUI

struct EditorView: View {
    @ObservedObject var store: BlogStore

    var body: some View {
        VStack(spacing: 0) {
            if let document = store.currentDocument {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text(document.relativePath)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            store.toggleEditorMode()
                        } label: {
                            Label(store.editorMode == .edit ? "Preview" : "Edit", systemImage: store.editorMode == .edit ? "doc.richtext" : "pencil")
                        }
                        .keyboardShortcut("e", modifiers: .command)
                        .help("Toggle Edit and Preview (Command+E)")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.bar)

                    switch store.editorMode {
                    case .edit:
                        MarkdownTextView(
                            text: Binding(
                                get: { store.currentDocument?.body ?? "" },
                                set: { store.updateBody($0) }
                            ),
                            onInsertImages: { images in
                                store.insertImages(images)
                            },
                            onTogglePreview: store.toggleEditorMode
                        )
                    case .preview:
                        MarkdownPreviewView(document: document, projectRoot: store.projectRoot)
                    }
                }
            } else {
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
            }
        }
    }
}
