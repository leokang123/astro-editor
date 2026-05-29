import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: BlogStore
    @ObservedObject private var gitController: GitController
    @SceneStorage("showSidebar") private var showSidebar = true
    @SceneStorage("showInspector") private var showInspector = true
    @AppStorage(EditorContentWidth.storageKey) private var editorContentWidthValue = EditorContentWidth.wide.rawValue
    @State private var isLiveResizing = false

    init(store: BlogStore) {
        self.store = store
        self._gitController = ObservedObject(wrappedValue: store.gitController)
    }

    var body: some View {
        ZStack {
            WindowChromeConfigurator()
                .frame(width: 0, height: 0)

            LiveResizeStateObserver(isLiveResizing: $isLiveResizing)
                .frame(width: 0, height: 0)

            mainContent
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showSidebar.toggle()
                } label: {
                    Label(showSidebar ? "Hide Sidebar" : "Show Sidebar", systemImage: "sidebar.left")
                }
                .help(showSidebar ? "Hide sidebar" : "Show sidebar")

                Button {
                    showInspector.toggle()
                } label: {
                    Label(showInspector ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.right")
                }
                .help(showInspector ? "Hide inspector" : "Show inspector")

                Divider()

                Button {
                    store.activeSheet = .featuredDocuments
                } label: {
                    Label("Featured", systemImage: "star.fill")
                }
                .disabled(!store.hasProject)

                Divider()

                Button {
                    store.chooseProjectFolder()
                } label: {
                    Label("Project", systemImage: "folder.badge.gearshape")
                }

                Button {
                    store.rescan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(!store.hasProject)

                Divider()

                Button {
                    store.saveCurrentDocument()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(!store.canSave)

                Button {
                    store.activeSheet = .commitPush
                } label: {
                    Label(gitController.isOperationRunning ? "Pushing" : "Commit & Push", systemImage: "paperplane")
                }
                .disabled(!store.canCommitAndPush)

                Button {
                    store.openWebsite()
                } label: {
                    Label("Open Website", systemImage: "safari")
                }
                .disabled(!store.hasProject)
            }
        }
        .sheet(item: $store.activeSheet) { sheet in
            switch sheet {
            case .newCategory:
                NewCategorySheet(store: store, activeSheet: $store.activeSheet)
            case .newDocument:
                NewDocumentSheet(store: store, activeSheet: $store.activeSheet)
            case .move:
                MoveSheet(store: store, activeSheet: $store.activeSheet)
            case .commitPush:
                CommitPushSheet(
                    gitController: gitController,
                    activeSheet: $store.activeSheet,
                    onRefreshGitStatus: store.refreshGitStatus,
                    onCommitAndPush: store.commitAndPush
                )
            case .featuredDocuments:
                FeaturedDocumentsSheet(store: store, activeSheet: $store.activeSheet)
            }
        }
        .alert(item: $store.message) { message in
            Alert(title: Text("AstroPaper Editor"), message: Text(message.text), dismissButton: .default(Text("OK")))
        }
    }

    private var mainContent: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                fixedPaneLayout(topInset: proxy.safeAreaInsets.top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                StatusBar(
                    projectName: store.hasProject ? store.projectRoot.lastPathComponent : "No project selected",
                    projectRootPath: store.projectRoot.displayPath,
                    isDirty: store.isDirty,
                    modeText: store.currentDocument == nil ? nil : (store.editorMode == .edit ? "Markdown" : "Preview"),
                    statusText: store.statusText
                )
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private func fixedPaneLayout(topInset: CGFloat) -> some View {
        HStack(spacing: 0) {
            if showSidebar {
                panel(background: AnyShapeStyle(.bar), topInset: topInset) {
                    sidebarPanel
                }
                .frame(width: PanelMetrics.sidebarWidth)

                paneDivider
            }

            editorAndInspector(topInset: topInset)
        }
    }

    private func editorAndInspector(topInset: CGFloat) -> some View {
        ZStack {
            if isLiveResizing {
                Color.clear
            }

            HStack(spacing: 0) {
                panel(background: PanelColors.contentBackground, topInset: topInset) {
                    EditorView(
                        document: store.currentDocument,
                        hasProject: store.hasProject,
                        editorMode: store.editorMode,
                        previewDocumentID: store.previewDocumentID,
                        editorSourcePosition: store.editorSourcePosition,
                        projectRoot: store.projectRoot,
                        isFindVisible: $store.isEditorFindVisible,
                        isReplaceVisible: $store.isEditorReplaceVisible,
                        findQuery: $store.editorFindQuery,
                        findDirection: store.editorFindDirection,
                        findGeneration: store.editorFindGeneration,
                        findFocusGeneration: store.editorFindFocusGeneration,
                        replaceText: $store.editorReplaceText,
                        replaceGeneration: store.editorReplaceGeneration,
                        replaceAllGeneration: store.editorReplaceAllGeneration,
                        findCurrentMatch: store.editorFindCurrentMatch,
                        findTotalMatches: store.editorFindTotalMatches,
                        findReplacementCount: store.editorFindReplacementCount,
                        onOpenProject: store.chooseProjectFolder,
                        onCloseUnavailableDocument: store.closeUnavailableProjectDocument,
                        onTogglePreview: store.toggleEditorMode,
                        onTextChange: store.markBodyChanged,
                        onRegisterBodyProvider: store.setEditorBodyProvider,
                        onRegisterSourcePositionProvider: store.setEditorSourcePositionProvider,
                        onInsertImages: store.insertImages,
                        onSourcePositionChange: store.updateEditorSourcePosition,
                        onFindRequested: store.showEditorFindInterface,
                        onFindNext: store.findNextInEditor,
                        onFindPrevious: store.findPreviousInEditor,
                        onReplaceCurrent: store.replaceCurrentInEditor,
                        onReplaceAll: store.replaceAllInEditor,
                        onFindStatusChange: store.updateEditorFindStatus,
                        onCloseFind: store.hideEditorFindInterface,
                        contentMaxWidth: editorContentWidth.maxWidth
                    )
                }
                .frame(minWidth: 420, maxWidth: .infinity)
                .allowsHitTesting(!isLiveResizing)

                if showInspector {
                    paneDivider

                    panel(background: PanelColors.contentBackground, topInset: topInset) {
                        InspectorView(
                            document: store.currentDocument,
                            onUpdateFrontmatter: store.updateFrontmatter,
                            onFrontmatterChange: store.markFrontmatterChanged,
                            onRegisterFrontmatterProvider: store.setFrontmatterProvider,
                            onSetOGImage: store.setOGImage,
                            onClearOGImage: store.clearOGImage,
                            onResolveAssetImageURL: store.resolvedAssetImageURL
                        )
                    }
                    .frame(width: PanelMetrics.inspectorWidth)
                    .allowsHitTesting(!isLiveResizing)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func panel<Content: View>(
        background: AnyShapeStyle,
        topInset: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(background)

            content()
                .padding(.top, topInset)
        }
        .clipped()
    }

    private var paneDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: PanelMetrics.dividerWidth)
            .allowsHitTesting(false)
    }

    private var sidebarPanel: some View {
        SidebarView(
            tree: store.tree,
            selectionID: store.selectionID,
            hasProject: store.hasProject,
            onSelectNode: store.selectNode,
            onNewCategory: store.requestNewCategory,
            onNewDocument: store.requestNewDocument,
            onRenameSelected: store.promptRenameSelected,
            onRenameNode: store.promptRenameNode,
            onMoveSelected: store.requestMoveSelected,
            onMoveNode: store.requestMoveNode,
            onDeleteSelected: store.deleteSelected,
            onDeleteNode: store.deleteNode
        )
    }

    private var editorContentWidth: EditorContentWidth {
        EditorContentWidth(rawValue: editorContentWidthValue) ?? .wide
    }

}

private enum PanelMetrics {
    static let sidebarWidth: CGFloat = 280
    static let inspectorWidth: CGFloat = 320
    static let dividerWidth: CGFloat = 1
}

private enum PanelColors {
    static let contentBackground = AnyShapeStyle(Color(nsColor: .underPageBackgroundColor))
}

private struct LiveResizeStateObserver: NSViewRepresentable {
    @Binding var isLiveResizing: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLiveResizing: $isLiveResizing)
    }

    func makeNSView(context: Context) -> LiveResizeStateView {
        let view = LiveResizeStateView()
        view.onWillStart = context.coordinator.start
        view.onDidEnd = context.coordinator.end
        return view
    }

    func updateNSView(_ nsView: LiveResizeStateView, context: Context) {
        context.coordinator.isLiveResizing = $isLiveResizing
        nsView.onWillStart = context.coordinator.start
        nsView.onDidEnd = context.coordinator.end
    }

    final class Coordinator {
        var isLiveResizing: Binding<Bool>

        init(isLiveResizing: Binding<Bool>) {
            self.isLiveResizing = isLiveResizing
        }

        func start() {
            guard !isLiveResizing.wrappedValue else { return }
            isLiveResizing.wrappedValue = true
        }

        func end() {
            guard isLiveResizing.wrappedValue else { return }
            isLiveResizing.wrappedValue = false
        }
    }
}

private final class LiveResizeStateView: NSView {
    var onWillStart: (() -> Void)?
    var onDidEnd: (() -> Void)?

    private weak var observedWindow: NSWindow?
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observeCurrentWindow()
    }

    deinit {
        removeObservers()
    }

    private func observeCurrentWindow() {
        guard window !== observedWindow else { return }
        removeObservers()
        observedWindow = window

        guard let window else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: NSWindow.willStartLiveResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onWillStart?()
            },
            center.addObserver(
                forName: NSWindow.didEndLiveResizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onDidEnd?()
            }
        ]
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers = []
        observedWindow = nil
    }
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowChromeConfigurationView {
        WindowChromeConfigurationView()
    }

    func updateNSView(_ nsView: WindowChromeConfigurationView, context: Context) {
        nsView.configureWindowChrome()
    }
}

private final class WindowChromeConfigurationView: NSView {
    private var pendingAttempts = 0

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindowChrome()
    }

    func configureWindowChrome() {
        pendingAttempts = 8
        applyWindowChromeConfiguration()
        scheduleWindowChromeConfiguration()
    }

    private func applyWindowChromeConfiguration() {
        window?.styleMask.insert(.fullSizeContentView)
        window?.titlebarAppearsTransparent = true
        window?.toolbar?.showsBaselineSeparator = false
        window?.titlebarSeparatorStyle = .none
    }

    private func scheduleWindowChromeConfiguration() {
        guard pendingAttempts > 0 else { return }
        pendingAttempts -= 1
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyWindowChromeConfiguration()
            self.scheduleWindowChromeConfiguration()
        }
    }
}

private struct StatusBar: View {
    let projectName: String
    let projectRootPath: String
    let isDirty: Bool
    let modeText: String?
    let statusText: String

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(projectName)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(projectRootPath)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isDirty {
                Label("Unsaved", systemImage: "circle.fill")
                    .foregroundStyle(.orange)
            }

            if let modeText {
                Text(modeText)
                    .foregroundStyle(.secondary)
            }

            Text(statusText)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }
}
