import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var store: BlogStore

    var body: some View {
        TabView {
            ProjectPreferencesView(store: store)
                .tabItem {
                    Label("Project", systemImage: "folder")
                }

            AboutPagePreferencesView(store: store)
                .tabItem {
                    Label("About", systemImage: "person.text.rectangle")
                }

            HomeSettingsPreferencesView(store: store)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
        }
        .padding(20)
        .frame(width: 760, height: 560)
    }
}

private struct ProjectPreferencesView: View {
    @ObservedObject var store: BlogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Project")
                .font(.title2)
                .fontWeight(.semibold)

            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                    GridRow {
                        Text("Root")
                            .foregroundStyle(.secondary)
                        Text(store.projectRoot.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("Blog")
                            .foregroundStyle(.secondary)
                        Text(store.blogRoot.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("About")
                            .foregroundStyle(.secondary)
                        Text(store.aboutPageURL.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("Config")
                            .foregroundStyle(.secondary)
                        Text(store.configURL.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                }
                .padding(10)
            }

            HStack {
                Button {
                    store.chooseProjectFolder()
                } label: {
                    Label("Choose Project Folder", systemImage: "folder.badge.gearshape")
                }

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([store.projectRoot])
                } label: {
                    Label("Show in Finder", systemImage: "finder")
                }
            }

            Spacer()
        }
    }
}

private struct HomeSettingsPreferencesView: View {
    @ObservedObject var store: BlogStore
    @State private var settings: HomeSettings?
    @State private var lastLoaded: HomeSettings?
    @State private var descriptionDraft = ""
    @State private var message = ""

    private var isDirty: Bool {
        settings != lastLoaded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Home")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("src/config.ts")
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
                .disabled(!isDirty || settings == nil)
            }

            if settings == nil {
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
                    store.openLocalhost()
                } label: {
                    Label("Open Localhost", systemImage: "safari")
                }
            }
            .font(.caption)
        }
        .onAppear {
            if settings == nil {
                reload()
            }
        }
    }

    private var siteSection: some View {
        GroupBox("Site") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                textFieldRow("Site title", \.siteTitle)
                textFieldRow("Description", \.siteDescription)
                textFieldRow("Author", \.author)
                textFieldRow("Website", \.website)
                textFieldRow("Profile", \.profile)
                textFieldRow("Posts on home", \.postPerIndex)
            }
            .padding(8)
        }
    }

    private var heroSection: some View {
        GroupBox("Home Hero") {
            VStack(alignment: .leading, spacing: 10) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    textFieldRow("Hero title", \.homeTitle)
                    textFieldRow("Social label", \.socialLabel)
                    textFieldRow("All posts", \.allPostsText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Hero description")
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
        do {
            let loaded = try store.readHomeSettings()
            settings = loaded
            lastLoaded = loaded
            descriptionDraft = loaded.homeDescription.joined(separator: "\n")
            message = "Loaded src/config.ts"
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() {
        guard let settings else { return }
        do {
            try store.writeHomeSettings(settings)
            lastLoaded = settings
            message = "Saved src/config.ts"
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct AboutPagePreferencesView: View {
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
                    store.openLocalhost()
                } label: {
                    Label("Open Localhost", systemImage: "safari")
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
