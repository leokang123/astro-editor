import SwiftUI

struct NewDocumentSheet: View {
    @ObservedObject var store: BlogStore
    @Binding var activeSheet: ActiveSheet?
    @State private var title = ""
    @State private var description = ""
    @State private var tags = "일반"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Document")
                .font(.title2)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("일반, 알고리즘", text: $tags)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Location: \(locationText)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Spacer()
                Button("Cancel") { activeSheet = nil }
                Button("Create") {
                    store.createDocument(
                        title: title,
                        description: description,
                        tagsText: tags,
                        parentID: store.selectionID
                    )
                    activeSheet = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 460)
    }

    private var locationText: String {
        guard let selected = store.selectedNode else { return "src/data/blog" }
        if selected.kind == .category { return selected.relativePath }
        let parent = selected.url.deletingLastPathComponent()
        let relative = BlogFileService.relativePath(from: store.blogRoot, to: parent)
        return relative.isEmpty ? "src/data/blog" : relative
    }
}
