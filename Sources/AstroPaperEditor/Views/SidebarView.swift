import SwiftUI

struct SidebarView: View {
    let tree: [BlogNode]
    let selectionID: String?
    let selectedNode: BlogNode?
    @Binding var activeSheet: ActiveSheet?
    var onSelectNode: (String?) -> Void
    var onRenameSelected: () -> Void
    var onDeleteSelected: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(selection: selectionBinding) {
                Label("src/data/blog", systemImage: "folder")
                    .tag(BlogNodeID.root)
                    .contextMenu {
                        Button("New Category") { activeSheet = .newCategory }
                        Button("New Document") { activeSheet = .newDocument }
                    }

                Divider()

                OutlineGroup(tree, children: \.outlineChildren) { node in
                    Label(node.name, systemImage: node.systemImage)
                        .tag(node.id)
                        .contextMenu {
                            Button("New Category") { activeSheet = .newCategory }
                            Button("New Document") { activeSheet = .newDocument }
                            Divider()
                            Button("Rename") { onRenameSelected() }
                            Button("Move") { activeSheet = .move }
                            Divider()
                            Button("Delete", role: .destructive) { onDeleteSelected() }
                        }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 8) {
                Button {
                    activeSheet = .newCategory
                } label: {
                    Label("Category", systemImage: "folder.badge.plus")
                }

                Button {
                    activeSheet = .newDocument
                } label: {
                    Label("Document", systemImage: "doc.badge.plus")
                }

                Spacer()

                Menu {
                    Button("Rename") { onRenameSelected() }
                    Button("Move") { activeSheet = .move }
                    Button("Delete", role: .destructive) { onDeleteSelected() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(selectedNode == nil || selectionID == BlogNodeID.root)
            }
            .labelStyle(.iconOnly)
            .padding(8)
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { selectionID },
            set: { onSelectNode($0) }
        )
    }
}
