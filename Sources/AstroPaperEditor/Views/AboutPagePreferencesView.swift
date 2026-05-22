import SwiftUI

struct AboutPagePreferencesView: View {
    @ObservedObject var store: BlogStore
    @ObservedObject var closeState: SettingsCloseState
    @State private var draft = AboutPageDraft()
    @State private var savedDraft = AboutPageDraft()
    @State private var unsavedProfileImageURL: URL?
    @State private var message = ""

    private var isDirty: Bool {
        draft != savedDraft || unsavedProfileImageURL != nil
    }

    private var profileImageSource: String? {
        if let unsavedProfileImageURL {
            return unsavedProfileImageURL.lastPathComponent
        }
        return draft.profileImageSource
    }

    private var profileImageURL: URL? {
        if let unsavedProfileImageURL {
            return unsavedProfileImageURL
        }
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
                    Text("About page content")
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
                    _ = save()
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
            closeState.register(
                id: "about",
                hasUnsaved: { isDirty },
                save: { save() },
                discard: discard
            )
            if store.hasProject, draft.body.isEmpty, draft.frontmatter.isEmpty {
                reload()
            }
        }
        .onChange(of: store.hasProject) { hasProject in
            if hasProject, draft.body.isEmpty, draft.frontmatter.isEmpty {
                reload()
            }
        }
        .onChange(of: store.projectRoot) { _ in
            reset()
            if store.hasProject {
                reload()
            }
        }
    }

    private func reload() {
        guard store.hasProject else { return }
        do {
            clearUnsavedProfileImage()
            let page = try store.readAboutPage()
            let loadedDraft = AboutPageDraft(page: page)
            draft = loadedDraft
            savedDraft = loadedDraft
            message = "Loaded About page"
        } catch {
            message = error.localizedDescription
        }
    }

    private func reset() {
        clearUnsavedProfileImage()
        draft = AboutPageDraft()
        savedDraft = AboutPageDraft()
        message = ""
    }

    @discardableResult
    private func save() -> Bool {
        guard store.hasProject else { return false }
        do {
            var pageDraft = draft
            if let unsavedProfileImageURL {
                let publicPath = try store.copyAboutProfileImage(from: unsavedProfileImageURL)
                pageDraft.replaceProfileImage(with: publicPath, defaultAlt: "Profile photo")
            }
            try store.writeAboutPage(pageDraft.page)
            draft = pageDraft
            savedDraft = pageDraft
            clearUnsavedProfileImage()
            message = "Saved About page"
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    private func replaceProfileImage(with sourceURL: URL) {
        guard store.hasProject else { return }
        do {
            let fileExtension = sourceURL.pathExtension.lowercased().isEmpty ? "png" : sourceURL.pathExtension.lowercased()
            let stagedURL = try store.stageTemporaryFile(from: sourceURL, filename: "about-profile.\(fileExtension)")
            clearUnsavedProfileImage()
            unsavedProfileImageURL = stagedURL
            message = "Profile photo selected. Save About page to apply it."
        } catch {
            message = error.localizedDescription
        }
    }

    private func discard() {
        draft = savedDraft
        clearUnsavedProfileImage()
    }

    private func clearUnsavedProfileImage() {
        if let unsavedProfileImageURL {
            try? FileManager.default.removeItem(at: unsavedProfileImageURL)
        }
        unsavedProfileImageURL = nil
    }
}
