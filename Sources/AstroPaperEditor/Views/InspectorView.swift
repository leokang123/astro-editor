import SwiftUI

struct InspectorView: View {
    @ObservedObject var store: BlogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Frontmatter", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
            }
            .padding(14)
            .background(.bar)

            if let document = store.currentDocument {
                Form {
                    TextField("Title", text: frontmatterBinding(\.title))
                    TextField("Description", text: frontmatterBinding(\.description), axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Published", text: frontmatterBinding(\.pubDatetime))
                    TextField("Modified", text: frontmatterBinding(\.modDatetime))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Tags")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("comma or line")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        TextEditor(text: Binding(
                            get: { store.currentDocument?.frontmatter.tags.joined(separator: "\n") ?? "" },
                            set: { value in
                                store.updateFrontmatter { $0.tags = value.trimmingForTags }
                            }
                        ))
                        .font(.body)
                        .frame(minHeight: 92)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.separator, lineWidth: 1)
                        }
                    }

                    if !document.frontmatter.extraLines.isEmpty {
                        Section("Preserved Extra Fields") {
                            Text(document.frontmatter.extraLines.joined(separator: "\n"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .formStyle(.grouped)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No document selected")
                        .font(.headline)
                    Text("Create or open a document to edit AstroPaper frontmatter.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                Spacer()
            }
        }
    }

    private func frontmatterBinding(_ keyPath: WritableKeyPath<Frontmatter, String>) -> Binding<String> {
        Binding(
            get: { store.currentDocument?.frontmatter[keyPath: keyPath] ?? "" },
            set: { value in
                store.updateFrontmatter { $0[keyPath: keyPath] = value }
            }
        )
    }
}
