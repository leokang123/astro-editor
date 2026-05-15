import SwiftUI

struct ContentView: View {
    @ObservedObject var store: BlogStore
    @State private var activeSheet: ActiveSheet?
    @SceneStorage("showSidebar") private var showSidebar = true
    @SceneStorage("showInspector") private var showInspector = true

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                if showSidebar {
                    SidebarView(store: store, activeSheet: $activeSheet)
                        .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
                }

                EditorView(store: store)
                    .frame(minWidth: 420)

                if showInspector {
                    InspectorView(store: store)
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 420)
                }
            }

            Divider()
            StatusBar(store: store)
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
                    store.chooseProjectFolder()
                } label: {
                    Label("Project", systemImage: "folder.badge.gearshape")
                }

                Button {
                    store.rescan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }

                Divider()

                Button {
                    store.saveCurrentDocument()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(!store.canSave)

                Button {
                    activeSheet = .commitPush
                } label: {
                    Label(store.isGitOperationRunning ? "Pushing" : "Commit & Push", systemImage: "paperplane")
                }
                .disabled(!store.canCommitAndPush)

                Button {
                    store.openWebsite()
                } label: {
                    Label("Open Website", systemImage: "safari")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newCategory:
                NewCategorySheet(store: store, activeSheet: $activeSheet)
            case .newDocument:
                NewDocumentSheet(store: store, activeSheet: $activeSheet)
            case .move:
                MoveSheet(store: store, activeSheet: $activeSheet)
            case .commitPush:
                CommitPushSheet(store: store, activeSheet: $activeSheet)
            }
        }
        .alert(item: $store.message) { message in
            Alert(title: Text("AstroPaper Editor"), message: Text(message.text), dismissButton: .default(Text("OK")))
        }
    }
}

private struct StatusBar: View {
    @ObservedObject var store: BlogStore

    var body: some View {
        HStack(spacing: 12) {
            Text(store.projectRoot.path)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if store.isDirty {
                Label("Unsaved", systemImage: "circle.fill")
                    .foregroundStyle(.orange)
            }

            Text(store.statusText)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }
}

enum ActiveSheet: String, Identifiable {
    case newCategory
    case newDocument
    case move
    case commitPush

    var id: String { rawValue }
}
