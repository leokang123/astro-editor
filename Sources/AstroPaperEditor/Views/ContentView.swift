import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: BlogStore
    @ObservedObject private var gitController: GitController
    @SceneStorage("showSidebar") private var showSidebar = true
    @SceneStorage("showInspector") private var showInspector = true
    @AppStorage(EditorContentWidth.storageKey) private var editorContentWidthValue = EditorContentWidth.wide.rawValue
    @State private var isLiveResizing = false
    @State private var splitPanelWidths = SplitPanelWidths()
    @State private var restoreSplitPanelWidths = false

    init(store: BlogStore) {
        self.store = store
        self._gitController = ObservedObject(wrappedValue: store.gitController)
    }

    var body: some View {
        ZStack {
            WindowChromeConfigurator()
                .frame(width: 0, height: 0)

            WindowLiveResizeDetector(
                isLiveResizing: $isLiveResizing,
                showSidebar: showSidebar,
                showInspector: showInspector,
                onWillStart: { widths in
                    if let widths {
                        splitPanelWidths = widths
                    }
                    store.prepareForLiveResize()
                },
                onDidEnd: {
                    restoreSplitPanelWidths = true
                }
            )
            .frame(width: 0, height: 0)

            if isLiveResizing {
                ResizePlaceholderView(
                    showSidebar: showSidebar,
                    showInspector: showInspector,
                    panelWidths: splitPanelWidths
                )
            } else {
                mainContent
            }
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
        VStack(spacing: 0) {
            HSplitView {
                if showSidebar {
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
                    .frame(
                        minWidth: sidebarFrame.min,
                        idealWidth: sidebarFrame.ideal,
                        maxWidth: sidebarFrame.max
                    )
                }

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
                .frame(minWidth: 420)

                if showInspector {
                    InspectorView(
                        document: store.currentDocument,
                        onUpdateFrontmatter: store.updateFrontmatter,
                        onFrontmatterChange: store.markFrontmatterChanged,
                        onRegisterFrontmatterProvider: store.setFrontmatterProvider,
                        onSetOGImage: store.setOGImage,
                        onClearOGImage: store.clearOGImage,
                        onResolveAssetImageURL: store.resolvedAssetImageURL
                    )
                    .frame(
                        minWidth: inspectorFrame.min,
                        idealWidth: inspectorFrame.ideal,
                        maxWidth: inspectorFrame.max
                    )
                }
            }
            .onAppear {
                guard restoreSplitPanelWidths else { return }
                DispatchQueue.main.async {
                    restoreSplitPanelWidths = false
                }
            }

            Divider()
            StatusBar(
                projectName: store.hasProject ? store.projectRoot.lastPathComponent : "No project selected",
                projectRootPath: store.projectRoot.displayPath,
                isDirty: store.isDirty,
                modeText: store.currentDocument == nil ? nil : (store.editorMode == .edit ? "Markdown" : "Preview"),
                statusText: store.statusText
            )
        }
    }

    private var editorContentWidth: EditorContentWidth {
        EditorContentWidth(rawValue: editorContentWidthValue) ?? .wide
    }

    private var sidebarFrame: PanelFrame {
        panelFrame(
            restoredWidth: restoreSplitPanelWidths ? splitPanelWidths.sidebar : nil,
            minimum: 240,
            ideal: 280,
            maximum: 360
        )
    }

    private var inspectorFrame: PanelFrame {
        panelFrame(
            restoredWidth: restoreSplitPanelWidths ? splitPanelWidths.inspector : nil,
            minimum: 280,
            ideal: 320,
            maximum: 420
        )
    }

    private func panelFrame(restoredWidth: CGFloat?, minimum: CGFloat, ideal: CGFloat, maximum: CGFloat) -> PanelFrame {
        guard let restoredWidth else {
            return PanelFrame(min: minimum, ideal: ideal, max: maximum)
        }
        let width = min(max(restoredWidth, minimum), maximum)
        return PanelFrame(min: width, ideal: width, max: width)
    }
}

private struct SplitPanelWidths: Equatable {
    var sidebar: CGFloat?
    var inspector: CGFloat?
}

private struct PanelFrame {
    let min: CGFloat
    let ideal: CGFloat
    let max: CGFloat
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

private extension NSView {
    func largestVerticalSplitView() -> NSSplitView? {
        var best: NSSplitView?
        collectLargestVerticalSplitView(into: &best)
        return best
    }

    private func collectLargestVerticalSplitView(into best: inout NSSplitView?) {
        if let splitView = self as? NSSplitView,
           splitView.isVertical,
           splitView.arrangedSubviews.count >= 2,
           splitView.bounds.width > (best?.bounds.width ?? 0) {
            best = splitView
        }

        for subview in subviews {
            subview.collectLargestVerticalSplitView(into: &best)
        }
    }
}

private struct WindowLiveResizeDetector: NSViewRepresentable {
    @Binding var isLiveResizing: Bool
    let showSidebar: Bool
    let showInspector: Bool
    var onWillStart: (SplitPanelWidths?) -> Void
    var onDidEnd: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isLiveResizing: $isLiveResizing, onWillStart: onWillStart, onDidEnd: onDidEnd)
    }

    func makeNSView(context: Context) -> LiveResizeDetectorView {
        let view = LiveResizeDetectorView()
        view.showSidebar = showSidebar
        view.showInspector = showInspector
        view.onWillStart = context.coordinator.start
        view.onDidEnd = context.coordinator.end
        return view
    }

    func updateNSView(_ nsView: LiveResizeDetectorView, context: Context) {
        context.coordinator.isLiveResizing = $isLiveResizing
        context.coordinator.onWillStart = onWillStart
        context.coordinator.onDidEnd = onDidEnd
        nsView.showSidebar = showSidebar
        nsView.showInspector = showInspector
        nsView.onWillStart = context.coordinator.start
        nsView.onDidEnd = context.coordinator.end
    }

    final class Coordinator {
        var isLiveResizing: Binding<Bool>
        var onWillStart: (SplitPanelWidths?) -> Void
        var onDidEnd: () -> Void

        init(
            isLiveResizing: Binding<Bool>,
            onWillStart: @escaping (SplitPanelWidths?) -> Void,
            onDidEnd: @escaping () -> Void
        ) {
            self.isLiveResizing = isLiveResizing
            self.onWillStart = onWillStart
            self.onDidEnd = onDidEnd
        }

        func start(widths: SplitPanelWidths?) {
            guard !isLiveResizing.wrappedValue else { return }
            onWillStart(widths)
            isLiveResizing.wrappedValue = true
        }

        func end() {
            guard isLiveResizing.wrappedValue else { return }
            onDidEnd()
            isLiveResizing.wrappedValue = false
        }
    }
}

private final class LiveResizeDetectorView: NSView {
    var showSidebar = true
    var showInspector = true
    var onWillStart: ((SplitPanelWidths?) -> Void)?
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
            center.addObserver(forName: NSWindow.willStartLiveResizeNotification, object: window, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.onWillStart?(self.captureSplitPanelWidths())
            },
            center.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: window, queue: .main) { [weak self] _ in
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

    private func captureSplitPanelWidths() -> SplitPanelWidths? {
        guard let splitView = window?.contentView?.largestVerticalSplitView() else { return nil }
        let subviews = splitView.arrangedSubviews
        guard subviews.count >= 2 else { return nil }

        return SplitPanelWidths(
            sidebar: showSidebar ? subviews.first?.frame.width : nil,
            inspector: showInspector ? subviews.last?.frame.width : nil
        )
    }
}

private struct ResizePlaceholderView: NSViewRepresentable {
    let showSidebar: Bool
    let showInspector: Bool
    let panelWidths: SplitPanelWidths

    func makeNSView(context: Context) -> ResizePlaceholderDrawingView {
        let view = ResizePlaceholderDrawingView()
        view.showSidebar = showSidebar
        view.showInspector = showInspector
        view.panelWidths = panelWidths
        return view
    }

    func updateNSView(_ nsView: ResizePlaceholderDrawingView, context: Context) {
        nsView.showSidebar = showSidebar
        nsView.showInspector = showInspector
        nsView.panelWidths = panelWidths
    }
}

private final class ResizePlaceholderDrawingView: NSView {
    var showSidebar = true {
        didSet {
            guard oldValue != showSidebar else { return }
            needsDisplay = true
        }
    }
    var panelWidths = SplitPanelWidths() {
        didSet {
            needsDisplay = true
        }
    }

    var showInspector = true {
        didSet {
            guard oldValue != showInspector else { return }
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = bounds
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()

        let sidebarWidth = showSidebar ? min(max(panelWidths.sidebar ?? bounds.width * 0.24, 240), 360) : 0
        let inspectorWidth = showInspector ? min(max(panelWidths.inspector ?? bounds.width * 0.24, 280), 420) : 0
        let statusHeight: CGFloat = 29
        let headerHeight: CGFloat = 41
        let dividerColor = NSColor.separatorColor
        let panelColor = NSColor.controlBackgroundColor
        let editorColor = NSColor.textBackgroundColor
        let softLine = NSColor.secondaryLabelColor.withAlphaComponent(0.16)
        let strongLine = NSColor.secondaryLabelColor.withAlphaComponent(0.23)

        let contentHeight = max(bounds.height - statusHeight, 0)
        let editorX = sidebarWidth + (showSidebar ? 1 : 0)
        let editorWidth = max(bounds.width - editorX - inspectorWidth - (showInspector ? 1 : 0), 0)
        let inspectorX = editorX + editorWidth + (showInspector ? 1 : 0)

        if showSidebar {
            fill(NSRect(x: 0, y: 0, width: sidebarWidth, height: contentHeight), with: panelColor)
            fill(NSRect(x: sidebarWidth, y: 0, width: 1, height: contentHeight), with: dividerColor)
            drawColumn(in: NSRect(x: 0, y: 0, width: sidebarWidth, height: contentHeight), lineCount: 11, softLine: softLine, strongLine: strongLine)
        }

        fill(NSRect(x: editorX, y: 0, width: editorWidth, height: contentHeight), with: editorColor)
        fill(NSRect(x: editorX, y: 0, width: editorWidth, height: headerHeight), with: panelColor)
        drawBar(in: NSRect(x: editorX + 14, y: 15, width: min(editorWidth * 0.36, 220), height: 10), color: strongLine)
        drawBar(in: NSRect(x: max(editorX + editorWidth - 92, editorX + 14), y: 11, width: min(72, max(editorWidth - 28, 0)), height: 18), color: softLine)
        drawEditorLines(in: NSRect(x: editorX, y: headerHeight, width: editorWidth, height: max(contentHeight - headerHeight, 0)), softLine: softLine, strongLine: strongLine)

        if showInspector {
            fill(NSRect(x: inspectorX - 1, y: 0, width: 1, height: contentHeight), with: dividerColor)
            fill(NSRect(x: inspectorX, y: 0, width: inspectorWidth, height: contentHeight), with: panelColor)
            drawColumn(in: NSRect(x: inspectorX, y: 0, width: inspectorWidth, height: contentHeight), lineCount: 8, softLine: softLine, strongLine: strongLine)
        }

        fill(NSRect(x: 0, y: contentHeight, width: bounds.width, height: 1), with: dividerColor)
        fill(NSRect(x: 0, y: contentHeight + 1, width: bounds.width, height: max(statusHeight - 1, 0)), with: panelColor)
        drawBar(in: NSRect(x: 10, y: contentHeight + 11, width: 140, height: 7), color: softLine)
        drawBar(in: NSRect(x: 164, y: contentHeight + 11, width: min(220, max(bounds.width - 270, 0)), height: 7), color: softLine)
        drawBar(in: NSRect(x: max(bounds.width - 92, 10), y: contentHeight + 11, width: min(80, max(bounds.width - 20, 0)), height: 7), color: softLine)
    }

    private func drawColumn(in rect: NSRect, lineCount: Int, softLine: NSColor, strongLine: NSColor) {
        drawBar(in: NSRect(x: rect.minX + 16, y: rect.minY + 22, width: rect.width * 0.42, height: 10), color: strongLine)

        for index in 0..<lineCount {
            let widthRatio: CGFloat = index.isMultiple(of: 4) ? 0.54 : 0.74
            drawBar(
                in: NSRect(
                    x: rect.minX + 16,
                    y: rect.minY + 56 + CGFloat(index) * 20,
                    width: rect.width * widthRatio,
                    height: 7
                ),
                color: index.isMultiple(of: 3) ? strongLine : softLine
            )
        }
    }

    private func drawEditorLines(in rect: NSRect, softLine: NSColor, strongLine: NSColor) {
        let maxLineWidth = min(rect.width - 56, 760)
        guard maxLineWidth > 0 else { return }
        let startX = rect.minX + max((rect.width - maxLineWidth) / 2, 28)

        for index in 0..<14 {
            let width = index.isMultiple(of: 4) ? min(520, maxLineWidth * 0.70) : maxLineWidth
            drawBar(
                in: NSRect(
                    x: startX,
                    y: rect.minY + 28 + CGFloat(index) * 23,
                    width: width,
                    height: 8
                ),
                color: index.isMultiple(of: 5) ? strongLine : softLine
            )
        }
    }

    private func drawBar(in rect: NSRect, color: NSColor) {
        guard rect.width > 0, rect.height > 0 else { return }
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
    }

    private func fill(_ rect: NSRect, with color: NSColor) {
        guard rect.width > 0, rect.height > 0 else { return }
        color.setFill()
        rect.fill()
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
