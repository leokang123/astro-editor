import SwiftUI

struct PostLinkSheet: View {
    let loadDocuments: () throws -> [PostLinkDocument]
    let onSelect: (PostLinkDocument) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var documents: [PostLinkDocument] = []
    @State private var query = ""
    @State private var errorMessage: String?
    @FocusState private var searchIsFocused: Bool

    private var matches: [PostLinkDocument] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return documents.filter {
            search.isEmpty || $0.title.localizedStandardContains(search)
                || $0.relativePath.localizedStandardContains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Insert Post Link")
                .font(.title2)
                .fontWeight(.semibold)
            TextField("Search by title or filename", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchIsFocused)
                .onSubmit {
                    if let document = matches.first { onSelect(document) }
                }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if matches.isEmpty {
                Text(documents.isEmpty ? "No other posts to link to." : "No matching posts.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(matches) { document in
                    Button {
                        onSelect(document)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(document.title)
                                .lineLimit(1)
                            Text(document.relativePath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Select a post to insert its link.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 560, height: 400)
        .onAppear {
            do {
                documents = try loadDocuments()
            } catch {
                errorMessage = error.localizedDescription
            }
            searchIsFocused = true
        }
    }
}
