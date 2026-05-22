import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct HomeSettingsPreferencesView: View {
    @ObservedObject var store: BlogStore
    @ObservedObject var siteImageDraft: SiteImageDraft
    @ObservedObject var closeState: SettingsCloseState
    @State private var settings: HomeSettings?
    @State private var lastLoaded: HomeSettings?
    @State private var descriptionDraft = ""
    @State private var message = ""

    private var isDirty: Bool {
        settings != lastLoaded || siteImageDraft.hasUnsaved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Home")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Site settings")
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
                .disabled(!store.hasProject || !isDirty || settings == nil)
            }

            if !store.hasProject {
                ProjectRequiredPlaceholder()
            } else if settings == nil {
                VStack(spacing: 10) {
                    Image(systemName: "house")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("Home settings not loaded")
                        .font(.headline)
                    Text(message)
                        .foregroundStyle(.secondary)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        siteSection
                        heroSection
                        readMoreSection
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                id: "home",
                hasUnsaved: { isDirty },
                save: { save() },
                discard: discard
            )
            if store.hasProject, settings == nil {
                reload()
            }
        }
        .onChange(of: store.hasProject) { hasProject in
            if hasProject, settings == nil {
                reload()
            }
        }
        .onChange(of: store.projectRoot) { _ in
            siteImageDraft.clear()
            reset()
            if store.hasProject {
                reload()
            }
        }
    }

    private var siteSection: some View {
        GroupBox("Website Info") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Basic information used across the whole site, plus how many posts are shown in each list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    textFieldRow("Site title", \.siteTitle)
                    textFieldRow("Description", \.siteDescription)
                    textFieldRow("Author", \.author)
                    textFieldRow("Website", \.website)
                    textFieldRow("Profile", \.profile)
                    textFieldRow("Posts on home", \.postPerIndex)
                    textFieldRow("Posts per page", \.postPerPage)
                }

                Divider()

                siteImagesSection
            }
            .padding(8)
        }
    }

    private var siteImagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PublicSiteImageRow(
                title: "Favicon",
                url: siteImageDraft.faviconURL ?? store.faviconURL,
                isUnsaved: siteImageDraft.faviconURL != nil,
                systemImage: "star.square",
                replaceTitle: "Replace SVG",
                onReplace: chooseFavicon
            )

            Divider()

            PublicSiteImageRow(
                title: "Default OG image",
                url: siteImageDraft.defaultOGImageURL ?? store.defaultOGImageURL,
                isUnsaved: siteImageDraft.defaultOGImageURL != nil,
                systemImage: "rectangle.on.rectangle",
                replaceTitle: "Replace JPEG",
                onReplace: chooseDefaultOGImage
            )
        }
    }

    private var heroSection: some View {
        GroupBox("Home Page Header") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Text shown at the top of the home page before the post list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    textFieldRow("Header title", \.homeTitle)
                    textFieldRow("Social label", \.socialLabel)
                    textFieldRow("All posts", \.allPostsText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Header description")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: Binding(
                        get: { descriptionDraft },
                        set: { value in
                            descriptionDraft = value
                            updateSettings { $0.homeDescription = value.components(separatedBy: "\n") }
                        }
                    ))
                    .font(.body)
                    .frame(minHeight: 86)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 1)
                    }
                }
            }
            .padding(8)
        }
    }

    private var readMoreSection: some View {
        GroupBox("Read More Link") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                textFieldRow("Text", \.readMoreText)
                textFieldRow("Link text", \.readMoreLinkText)
                textFieldRow("URL", \.readMoreHref)
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func textFieldRow(_ title: String, _ keyPath: WritableKeyPath<HomeSettings, String>) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            TextField(title, text: Binding(
                get: { settings?[keyPath: keyPath] ?? "" },
                set: { value in
                    updateSettings { $0[keyPath: keyPath] = value }
                }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private func updateSettings(_ edit: (inout HomeSettings) -> Void) {
        guard var updated = settings else { return }
        edit(&updated)
        settings = updated
    }

    private func reload() {
        guard store.hasProject else { return }
        do {
            siteImageDraft.clear()
            let loaded = try store.readHomeSettings()
            settings = loaded
            lastLoaded = loaded
            descriptionDraft = loaded.homeDescription.joined(separator: "\n")
            message = "Loaded site settings"
        } catch {
            message = error.localizedDescription
        }
    }

    private func reset() {
        settings = nil
        lastLoaded = nil
        descriptionDraft = ""
        message = ""
    }

    @discardableResult
    private func save() -> Bool {
        guard store.hasProject else { return false }
        guard let settings else { return false }
        do {
            if settings != lastLoaded {
                try store.writeHomeSettings(settings)
                lastLoaded = settings
            }
            if siteImageDraft.hasUnsaved {
                try siteImageDraft.save(to: store)
            }
            message = "Saved site settings"
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    private func discard() {
        settings = lastLoaded
        descriptionDraft = lastLoaded?.homeDescription.joined(separator: "\n") ?? ""
        siteImageDraft.clear()
    }

    private func chooseFavicon() {
        chooseSiteImage(
            filename: "favicon.svg",
            allowedContentTypes: UTType(filenameExtension: "svg").map { [$0] } ?? [],
            panelMessage: "Choose an SVG file to replace public/favicon.svg.",
            successMessage: "Favicon selected. Save to update public/favicon.svg."
        ) { stagedURL in
            siteImageDraft.replaceFavicon(with: stagedURL)
        }
    }

    private func chooseDefaultOGImage() {
        chooseSiteImage(
            filename: "astropaper-og.jpg",
            allowedContentTypes: [.jpeg],
            panelMessage: "Choose a JPEG file to replace public/astropaper-og.jpg.",
            successMessage: "Default OG image selected. Save to update public/astropaper-og.jpg."
        ) { stagedURL in
            siteImageDraft.replaceDefaultOGImage(with: stagedURL)
        }
    }

    private func chooseSiteImage(
        filename: String,
        allowedContentTypes: [UTType],
        panelMessage: String,
        successMessage: String,
        onStage: (URL) -> Void
    ) {
        guard store.hasProject else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if !allowedContentTypes.isEmpty {
            panel.allowedContentTypes = allowedContentTypes
        }
        panel.message = panelMessage

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let stagedURL = try store.stageTemporaryFile(from: url, filename: filename)
            onStage(stagedURL)
            message = successMessage
        } catch {
            message = error.localizedDescription
        }
    }
}

@MainActor
final class SiteImageDraft: ObservableObject {
    @Published var faviconURL: URL?
    @Published var defaultOGImageURL: URL?

    var hasUnsaved: Bool {
        faviconURL != nil || defaultOGImageURL != nil
    }

    func replaceFavicon(with url: URL) {
        clearFavicon()
        faviconURL = url
    }

    func replaceDefaultOGImage(with url: URL) {
        clearDefaultOGImage()
        defaultOGImageURL = url
    }

    func save(to store: BlogStore) throws {
        if let faviconURL {
            try store.replaceFavicon(from: faviconURL)
        }
        if let defaultOGImageURL {
            try store.replaceDefaultOGImage(from: defaultOGImageURL)
        }
        clear()
    }

    func clear() {
        clearFavicon()
        clearDefaultOGImage()
    }

    private func clearFavicon() {
        if let faviconURL {
            try? FileManager.default.removeItem(at: faviconURL)
        }
        faviconURL = nil
    }

    private func clearDefaultOGImage() {
        if let defaultOGImageURL {
            try? FileManager.default.removeItem(at: defaultOGImageURL)
        }
        defaultOGImageURL = nil
    }
}

private struct PublicSiteImageRow: View {
    let title: String
    let url: URL
    let isUnsaved: Bool
    let systemImage: String
    let replaceTitle: String
    let onReplace: () -> Void

    private var image: NSImage? {
        ImageCache.image(at: url)
    }

    private var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    var body: some View {
        HStack(spacing: 12) {
            preview

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.callout)
                    if isUnsaved {
                        Text("Unsaved")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if !exists {
                        Text("Missing")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text(url.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()

            Button {
                onReplace()
            } label: {
                Label(replaceTitle, systemImage: "photo.badge.arrow.down")
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Label("Reveal", systemImage: "folder")
            }
            .disabled(!exists)
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 48, height: 48)
    }
}
