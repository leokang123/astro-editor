import SwiftUI

struct AboutPagePreferencesView: View {
    @ObservedObject var store: BlogStore
    @State private var draft = AboutPageDraft()
    @State private var savedDraft = AboutPageDraft()
    @State private var message = ""

    private var isDirty: Bool {
        draft != savedDraft
    }

    private var profileImageSource: String? {
        draft.profileImageSource
    }

    private var profileImageURL: URL? {
        guard let source = profileImageSource else { return nil }
        if source.hasPrefix(ImageService.assetImagePrefix) {
            return store.resolvedAssetImageURL(source)
        }
        if source.hasPrefix("/") {
            return store.resolvedPublicURL(source)
        }
        return nil
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
                .disabled(!store.hasProject)

                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!store.hasProject || !isDirty)
            }

            if !store.hasProject {
                ProjectRequiredPlaceholder()
            } else {
                AboutProfilePhotoSection(
                    profileImageSource: profileImageSource,
                    profileImageURL: profileImageURL,
                    onReplace: replaceProfileImage,
                    onInvalidImage: {
                        message = "Choose a PNG, JPEG, GIF, or WebP image."
                    }
                )

                TextEditor(text: $draft.body)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 1)
                    }
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
                .disabled(!store.hasProject)
            }
            .font(.caption)
        }
        .onAppear {
            if store.hasProject, draft.body.isEmpty, draft.frontmatter.isEmpty {
                reload()
            }
        }
        .onChange(of: store.hasProject) { hasProject in
            if hasProject, draft.body.isEmpty, draft.frontmatter.isEmpty {
                reload()
            }
        }
    }

    private func reload() {
        guard store.hasProject else { return }
        do {
            let page = try store.readAboutPage()
            let loadedDraft = AboutPageDraft(page: page)
            draft = loadedDraft
            savedDraft = loadedDraft
            message = "Loaded \(store.aboutPageURL.path)"
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() {
        guard store.hasProject else { return }
        do {
            try store.writeAboutPage(draft.page)
            savedDraft = draft
            message = "Saved \(store.aboutPageURL.path)"
        } catch {
            message = error.localizedDescription
        }
    }

    private func replaceProfileImage(with sourceURL: URL) {
        guard store.hasProject else { return }
        do {
            let publicPath = try store.copyAboutProfileImage(from: sourceURL)
            draft.replaceProfileImage(with: publicPath, defaultAlt: "Profile photo")
            message = "Profile photo copied to public\(publicPath). Save About page to keep the new reference."
        } catch {
            message = error.localizedDescription
        }
    }
}
