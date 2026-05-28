import AppKit
import SwiftUI

private enum EditorPaneTab: String {
    case editor
    case preview
    case hidden
}

private struct EditorPaneContainer: NSViewRepresentable {
    let visiblePane: EditorPaneTab
    let editorContent: AnyView
    let previewContent: AnyView

    init(
        visiblePane: EditorPaneTab,
        @ViewBuilder editor: () -> some View,
        @ViewBuilder preview: () -> some View
    ) {
        self.visiblePane = visiblePane
        self.editorContent = AnyView(editor())
        self.previewContent = AnyView(preview())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> EditorPaneContainerView {
        let container = EditorPaneContainerView()
        let editorHost = NSHostingView(rootView: editorContent)
        let previewHost = NSHostingView(rootView: previewContent)
        container.editorHost = editorHost
        container.previewHost = previewHost
        context.coordinator.editorHost = editorHost
        context.coordinator.previewHost = previewHost
        container.visiblePane = visiblePane
        return container
    }

    func updateNSView(_ container: EditorPaneContainerView, context: Context) {
        context.coordinator.editorHost?.rootView = editorContent
        context.coordinator.previewHost?.rootView = previewContent
        container.visiblePane = visiblePane
    }

    final class Coordinator {
        var editorHost: NSHostingView<AnyView>?
        var previewHost: NSHostingView<AnyView>?
    }
}

private final class EditorPaneContainerView: NSView {
    var visiblePane: EditorPaneTab = .editor {
        didSet {
            needsLayout = true
        }
    }

    var editorHost: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let editorHost {
                addSubview(editorHost)
                needsLayout = true
            }
        }
    }

    var previewHost: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let previewHost {
                addSubview(previewHost)
                needsLayout = true
            }
        }
    }

    override var isFlipped: Bool {
        true
    }

    override func layout() {
        super.layout()
        let visibleFrame = bounds
        let stagedFrame = bounds.offsetBy(dx: -bounds.width - 10_000, dy: 0)
        editorHost?.frame = visiblePane == .editor ? visibleFrame : stagedFrame
        previewHost?.frame = visiblePane == .preview ? visibleFrame : stagedFrame
    }
}

struct EditorView: View {
    @State private var previewReadyDocumentID: String?
    @FocusState private var findFieldIsFocused: Bool
    @FocusState private var replaceFieldIsFocused: Bool

    let document: BlogDocument?
    let hasProject: Bool
    let editorMode: EditorMode
    let previewDocumentID: String?
    let editorSourcePosition: Double
    let projectRoot: URL
    @Binding var isFindVisible: Bool
    @Binding var isReplaceVisible: Bool
    @Binding var findQuery: String
    let findDirection: Int
    let findGeneration: Int
    let findFocusGeneration: Int
    @Binding var replaceText: String
    let replaceGeneration: Int
    let replaceAllGeneration: Int
    let findCurrentMatch: Int
    let findTotalMatches: Int
    let findReplacementCount: Int?
    var onOpenProject: () -> Void
    var onCloseUnavailableDocument: () -> Void
    var onTogglePreview: () -> Void
    var onTextChange: () -> Void
    var onRegisterBodyProvider: (((() -> String?)?) -> Void)
    var onRegisterSourcePositionProvider: (((() -> Double?)?) -> Void)
    var onInsertImages: ([PastedImage]) -> String
    var onSourcePositionChange: (Double) -> Void
    var onFindRequested: () -> Bool
    var onFindNext: () -> Bool
    var onFindPrevious: () -> Bool
    var onReplaceCurrent: () -> Bool
    var onReplaceAll: () -> Bool
    var onFindStatusChange: (Int, Int, Int?) -> Void
    var onCloseFind: () -> Void
    let contentMaxWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            if let document {
                let documentID = document.fileURL.path
                let shouldMountPreview = editorMode == .preview || previewDocumentID == documentID
                let previewIsReady = previewReadyDocumentID == documentID
                let isPreviewDocumentSwitch = editorMode == .preview && previewDocumentID != documentID
                let visiblePane: EditorPaneTab = editorMode == .edit
                    ? .editor
                    : (previewIsReady ? .preview : (isPreviewDocumentSwitch ? .hidden : .editor))
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

                    if isFindVisible {
                        findBar
                    }

                    ZStack {
                        Color(nsColor: .textBackgroundColor)

                        EditorPaneContainer(visiblePane: visiblePane) {
                            CodeMirrorTextView(
                                documentID: document.fileURL.path,
                                text: document.body,
                                targetSourcePosition: editorSourcePosition,
                                isActive: editorMode == .edit,
                                findQuery: findQuery,
                                findDirection: findDirection,
                                findGeneration: findGeneration,
                                replaceText: replaceText,
                                replaceGeneration: replaceGeneration,
                                replaceAllGeneration: replaceAllGeneration,
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
                                onFindRequested: {
                                    _ = onFindRequested()
                                },
                                onFindStatusChange: { current, total, replacementCount in
                                    onFindStatusChange(current, total, replacementCount)
                                },
                                onEditorReady: {
                                    guard editorMode == .edit else { return }
                                    previewReadyDocumentID = nil
                                }
                            )
                        } preview: {
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
                                .accessibilityHidden(editorMode != .preview)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(maxWidth: contentMaxWidth)
                    }
                }
                .onChange(of: documentID) { _ in
                    previewReadyDocumentID = nil
                }
                .onChange(of: editorMode) { mode in
                    if mode == .preview {
                        previewReadyDocumentID = nil
                    }
                }
                .onChange(of: isFindVisible) { isVisible in
                    if isVisible {
                        focusFindField()
                    }
                }
                .onChange(of: findFocusGeneration) { _ in
                    focusFindField()
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

    private var findBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    isReplaceVisible.toggle()
                } label: {
                    Image(systemName: isReplaceVisible ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.borderless)
                .help(isReplaceVisible ? "Hide Replace" : "Show Replace")
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Find", text: $findQuery)
                    .textFieldStyle(.roundedBorder)
                    .focused($findFieldIsFocused)
                    .onSubmit {
                        _ = onFindNext()
                    }
                Text(findStatusText)
                    .font(.caption)
                    .foregroundStyle(findTotalMatches == 0 && !findQuery.isEmpty ? .red : .secondary)
                    .frame(minWidth: 72, alignment: .trailing)
                Button {
                    _ = onFindPrevious()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .help("Find Previous")
                Button {
                    _ = onFindNext()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .help("Find Next")
                Button {
                    onCloseFind()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Close Find")
            }
            if isReplaceVisible {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                    TextField("Replace", text: $replaceText)
                        .textFieldStyle(.roundedBorder)
                        .focused($replaceFieldIsFocused)
                        .onSubmit {
                            _ = onReplaceCurrent()
                        }
                    Button("Replace") {
                        commitFindFields {
                            _ = onReplaceCurrent()
                        }
                    }
                    Button("All") {
                        commitFindFields {
                            _ = onReplaceAll()
                        }
                    }
                    if let findReplacementCount {
                        Text("\(findReplacementCount) replaced")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.bar)
        .onExitCommand {
            onCloseFind()
        }
    }

    private func focusFindField() {
        guard isFindVisible else { return }
        DispatchQueue.main.async {
            findFieldIsFocused = true
        }
    }

    private func commitFindFields(_ action: @escaping () -> Void) {
        findFieldIsFocused = false
        replaceFieldIsFocused = false
        DispatchQueue.main.async {
            action()
        }
    }

    private var findStatusText: String {
        guard !findQuery.isEmpty else { return "" }
        guard findTotalMatches > 0 else { return "No results" }
        return "\(findCurrentMatch) of \(findTotalMatches)"
    }
}
