import AppKit
import SwiftUI

struct AboutPagePreferencesView: View {
    @ObservedObject var store: BlogStore
    @State private var draft = ""
    @State private var lastLoaded = ""
    @State private var frontmatter = ""
    @State private var message = ""

    private var isDirty: Bool {
        draft != lastLoaded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("About Page")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("src/pages/about.md")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                Button {
                    reload()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }

                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!isDirty)
            }

            TextEditor(text: $draft)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator, lineWidth: 1)
                }

            HStack {
                if isDirty {
                    Label("Unsaved", systemImage: "circle.fill")
                        .foregroundStyle(.orange)
                }

                Text(message)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    store.openWebsite()
                } label: {
                    Label("Open Website", systemImage: "safari")
                }
            }
            .font(.caption)
        }
        .onAppear {
            if draft.isEmpty {
                reload()
            }
        }
    }

    private func reload() {
        do {
            let page = try store.readAboutPage()
            draft = page.body
            lastLoaded = page.body
            frontmatter = page.frontmatter
            message = "Loaded \(store.aboutPageURL.path)"
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() {
        do {
            try store.writeAboutPage(SiteMarkdownPage(frontmatter: frontmatter, body: draft))
            lastLoaded = draft
            message = "Saved \(store.aboutPageURL.path)"
        } catch {
            message = error.localizedDescription
        }
    }
}
