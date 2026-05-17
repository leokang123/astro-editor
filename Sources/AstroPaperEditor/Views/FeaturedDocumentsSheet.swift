import SwiftUI

struct FeaturedDocumentsSheet: View {
    @ObservedObject var store: BlogStore
    @Binding var activeSheet: ActiveSheet?
    @State private var documents: [FeaturedDocument] = []
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Featured Documents")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(documents.count) featured posts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            if documents.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "star")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Featured Documents")
                        .font(.headline)
                    Text(message.isEmpty ? "No documents in the current tree have featured: true." : message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 220)
            } else {
                List(documents) { document in
                    Button {
                        activeSheet = nil
                        store.selectNode(id: document.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(document.title)
                                    .lineLimit(1)
                                Text(document.relativePath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 280)
            }

            HStack {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button("Done") {
                    activeSheet = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 360)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        do {
            documents = try store.featuredDocuments()
            message = "Scanned current document tree"
        } catch {
            documents = []
            message = error.localizedDescription
        }
    }
}
