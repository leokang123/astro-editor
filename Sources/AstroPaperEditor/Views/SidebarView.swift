import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: BlogStore
    @Binding var activeSheet: ActiveSheet?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: selectionBinding) {
                OutlineGroup(store.tree, children: \.outlineChildren) { node in
                    Label(node.name, systemImage: node.systemImage)
                        .tag(node.id)
                        .contextMenu {
                            Button("New Category") { activeSheet = .newCategory }
                            Button("New Document") { activeSheet = .newDocument }
                            Divider()
                            Button("Rename") { store.promptRenameSelected() }
                            Button("Move") { activeSheet = .move }
                            Divider()
                            Button("Delete", role: .destructive) { store.deleteSelected() }
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
                    Button("Rename") { store.promptRenameSelected() }
                    Button("Move") { activeSheet = .move }
                    Button("Delete", role: .destructive) { store.deleteSelected() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(store.selectedNode == nil)
            }
            .labelStyle(.iconOnly)
            .padding(8)
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { store.selectionID },
            set: { store.selectNode(id: $0) }
        )
    }
}
