import SwiftUI

struct SidebarView: View {
    let tree: [BlogNode]
    let selectionID: String?
    let hasProject: Bool
    var onSelectNode: (String?) -> Void
    var onNewCategory: (String?) -> Void
    var onNewDocument: (String?) -> Void
    var onRenameSelected: () -> Void
    var onRenameNode: (String) -> Void
    var onMoveSelected: () -> Void
    var onMoveNode: (String) -> Void
    var onDeleteSelected: () -> Void
    var onDeleteNode: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(selection: selectionBinding) {
                Label("All Posts", systemImage: "folder")
                    .tag(BlogNodeID.root)
                    .help("Top level of src/data/blog")
                    .foregroundStyle(hasProject ? .primary : .secondary)
                    .disabled(!hasProject)
                    .contextMenu {
                        Button("New Category") { onNewCategory(nil) }
                            .disabled(!hasProject)
                        Button("New Document") { onNewDocument(nil) }
                            .disabled(!hasProject)
                    }

                Divider()

                OutlineGroup(tree, children: \.outlineChildren) { node in
                    Label(node.name, systemImage: node.systemImage)
                        .tag(node.id)
                        .contextMenu {
                            Button("New Category") { onNewCategory(node.id) }
                            Button("New Document") { onNewDocument(node.id) }
                            Divider()
                            Button("Rename") { onRenameNode(node.id) }
                            Button("Move") { onMoveNode(node.id) }
                            Divider()
                            Button("Delete", role: .destructive) { onDeleteNode(node.id) }
                        }
                }
            }
            .listStyle(.sidebar)
            .contextMenu {
                Button("New Category") { onNewCategory(nil) }
                    .disabled(!hasProject)
                Button("New Document") { onNewDocument(nil) }
                    .disabled(!hasProject)
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    onNewCategory(selectionID)
                } label: {
                    Label("Category", systemImage: "folder.badge.plus")
                }
                .disabled(!hasProject)

                Button {
                    onNewDocument(selectionID)
                } label: {
                    Label("Document", systemImage: "doc.badge.plus")
                }
                .disabled(!hasProject)

                Spacer()

                Menu {
                    Button("Rename") { onRenameSelected() }
                    Button("Move") { onMoveSelected() }
                    Button("Delete", role: .destructive) { onDeleteSelected() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(!canUseSelectedNodeActions)
            }
            .labelStyle(.iconOnly)
            .padding(8)
        }
    }

    private var canUseSelectedNodeActions: Bool {
        hasProject && selectionID != nil && selectionID != BlogNodeID.root
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { selectionID },
            set: { onSelectNode($0) }
        )
    }
}
