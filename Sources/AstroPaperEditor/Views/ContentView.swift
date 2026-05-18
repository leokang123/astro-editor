import SwiftUI

struct ContentView: View {
    @ObservedObject var store: BlogStore
    @ObservedObject private var gitController: GitController
    @SceneStorage("showSidebar") private var showSidebar = true
    @SceneStorage("showInspector") private var showInspector = true

    init(store: BlogStore) {
        self.store = store
        self._gitController = ObservedObject(wrappedValue: store.gitController)
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                if showSidebar {
                    SidebarView(
                        tree: store.tree,
                        selectionID: store.selectionID,
                        selectedNode: store.selectedNode,
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
                        .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
                }

                EditorView(
                    document: store.currentDocument,
                    hasProject: store.hasProject,
                    editorMode: store.editorMode,
                    editorTopLine: store.editorTopLine,
                    projectRoot: store.projectRoot,
                    onOpenProject: store.chooseProjectFolder,
                    onTogglePreview: store.toggleEditorMode,
                    onTextChange: store.markBodyChanged,
                    onRegisterBodyProvider: store.setEditorBodyProvider,
                    onRegisterTopLineProvider: store.setEditorTopLineProvider,
                    onInsertImages: store.insertImages,
                    onSourceLineChange: store.updateEditorTopLine
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
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 420)
                }
            }

            Divider()
            StatusBar(
                projectName: store.hasProject ? store.projectRoot.lastPathComponent : "No project selected",
                projectRootPath: store.projectRoot.path,
                isDirty: store.isDirty,
                statusText: store.statusText
            )
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
}

private struct StatusBar: View {
    let projectName: String
    let projectRootPath: String
    let isDirty: Bool
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
