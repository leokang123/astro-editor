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

            SocialLinksPreferencesView(store: store)
                .tabItem {
                    Label("Social", systemImage: "link")
                }

            GitPreferencesView(store: store)
                .tabItem {
                    Label("Git", systemImage: "arrow.up.circle")
                }

            DeveloperPreferencesView(store: store)
                .tabItem {
                    Label("Developer", systemImage: "hammer")
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

                    GridRow {
                        Text("User settings")
                            .foregroundStyle(.secondary)
                        Text(store.userSettingsURL.path)
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
                    Text("src/user-settings.ts")
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
                    store.openWebsite()
                } label: {
                    Label("Open Website", systemImage: "safari")
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
            message = "Loaded src/user-settings.ts"
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() {
        guard let settings else { return }
        do {
            try store.writeHomeSettings(settings)
            lastLoaded = settings
            message = "Saved src/user-settings.ts"
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct SocialLinksPreferencesView: View {
    @ObservedObject var store: BlogStore
    @State private var settings: HomeSettings?
    @State private var lastLoaded: HomeSettings?
    @State private var message = ""

    private var isDirty: Bool {
        settings != lastLoaded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Social Links")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("src/user-settings.ts USER_SOCIALS")
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

            if let socials = settings?.socials, !socials.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("활성화")
                            .frame(width: 86, alignment: .leading)
                        Text("서비스")
                            .frame(width: 118, alignment: .leading)
                        Text("URL")
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Divider()

                    ForEach(socials.indices, id: \.self) { index in
                        socialRow(index: index, social: socials[index])
                    }
                }
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("No social links found")
                        .font(.headline)
                    Text("Check src/user-settings.ts USER_SOCIALS.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()

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
            if settings == nil {
                reload()
            }
        }
    }

    private func socialRow(index: Int, social: SocialLinkSetting) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Toggle(isOn: Binding(
                    get: { settings?.socials[index].isEnabled ?? false },
                    set: { value in
                        updateSettings { $0.socials[index].isEnabled = value }
                    }
                )) {
                    Text("활성화")
                }
                .toggleStyle(.checkbox)
                .frame(width: 86, alignment: .leading)

                Label(social.name, systemImage: iconName(for: social.name))
                    .frame(width: 118, alignment: .leading)

                TextField("URL", text: Binding(
                    get: { settings?.socials[index].href ?? "" },
                    set: { value in
                        updateSettings { $0.socials[index].href = value }
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }

            Text(help(for: social.name))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 228)
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
            message = "Loaded src/user-settings.ts"
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() {
        guard let settings else { return }
        do {
            try store.writeSocialSettings(settings)
            lastLoaded = settings
            message = "Saved social links"
        } catch {
            message = error.localizedDescription
        }
    }

    private func iconName(for name: String) -> String {
        switch name {
        case "GitHub":
            return "chevron.left.forwardslash.chevron.right"
        case "X":
            return "xmark"
        case "LinkedIn":
            return "person.crop.square"
        case "Mail":
            return "envelope"
        default:
            return "link"
        }
    }

    private func help(for name: String) -> String {
        switch name {
        case "GitHub":
            return "GitHub 프로필 또는 저장소 주소"
        case "X":
            return "X/Twitter 프로필 주소"
        case "LinkedIn":
            return "LinkedIn 프로필 주소"
        case "Mail":
            return "메일 링크입니다. mailto:name@example.com 형식 권장"
        default:
            return "홈 화면 소셜 아이콘 링크"
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

private struct GitPreferencesView: View {
    @ObservedObject var store: BlogStore
    @State private var remoteURL = ""
    @State private var branch = "main"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Git")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Configure the repository used by Commit & Push.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.refreshGitStatus()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isGitOperationRunning)
            }

            GroupBox("Status") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Project")
                            .foregroundStyle(.secondary)
                        Text(store.gitStatus.projectRootPath.isEmpty ? store.projectRoot.path : store.gitStatus.projectRootPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("Git")
                            .foregroundStyle(.secondary)
                        Text(store.gitStatus.gitExecutablePath.isEmpty ? "-" : store.gitStatus.gitExecutablePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("Repository")
                            .foregroundStyle(.secondary)
                        Text(store.gitStatus.isRepository ? "Initialized" : "Not initialized")
                    }

                    GridRow {
                        Text("Branch")
                            .foregroundStyle(.secondary)
                        Text(store.gitStatus.branch.isEmpty ? "-" : store.gitStatus.branch)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("Remote")
                            .foregroundStyle(.secondary)
                        Text(store.gitStatus.remoteURL.isEmpty ? "Not configured" : store.gitStatus.remoteURL)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("Changes")
                            .foregroundStyle(.secondary)
                        Text(changesText)
                    }

                    GridRow {
                        Text("Details")
                            .foregroundStyle(.secondary)
                        Text(store.gitStatus.summary)
                            .lineLimit(6)
                            .textSelection(.enabled)
                    }
                }
                .padding(8)
            }

            GroupBox("Remote") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Remote URL")
                            .foregroundStyle(.secondary)
                        TextField("https://github.com/user/repo.git", text: $remoteURL)
                            .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text("Branch")
                            .foregroundStyle(.secondary)
                        TextField("main", text: $branch)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(8)
            }

            HStack {
                Button {
                    loadCurrentStatusIntoFields()
                } label: {
                    Label("Use Current", systemImage: "arrow.down.doc")
                }

                Spacer()

                Button {
                    store.configureGit(remoteURL: remoteURL, branch: branch)
                } label: {
                    Label(store.gitStatus.isRepository ? "Update Remote" : "Initialize Git", systemImage: "gearshape")
                }
                .disabled(store.isGitOperationRunning || remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || branch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !store.gitLog.isEmpty {
                ScrollView {
                    Text(store.gitLog)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: .infinity)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            } else {
                Spacer()
            }
        }
        .onAppear {
            store.refreshGitStatus()
            loadCurrentStatusIntoFields()
        }
        .onChange(of: store.gitStatus) { status in
            if !status.remoteURL.isEmpty {
                remoteURL = status.remoteURL
            }
            if !status.branch.isEmpty {
                branch = status.branch
            }
        }
    }

    private func loadCurrentStatusIntoFields() {
        if !store.gitStatus.remoteURL.isEmpty {
            remoteURL = store.gitStatus.remoteURL
        }
        if !store.gitStatus.branch.isEmpty {
            branch = store.gitStatus.branch
        }
    }

    private var changesText: String {
        guard store.gitStatus.isRepository else { return "Unavailable" }
        return store.gitStatus.hasChanges ? "Changed files found" : "Working tree clean"
    }
}

private struct DeveloperPreferencesView: View {
    @ObservedObject var store: BlogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Developer")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Manual local build tools for development checks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.runBuild()
                } label: {
                    Label(store.isBuilding ? "Building" : "Docker Build", systemImage: "hammer")
                }
                .disabled(store.isBuilding)

                Button {
                    store.openWebsite()
                } label: {
                    Label("Open Website", systemImage: "safari")
                }
            }

            GroupBox("Docker Compose") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Runs in the selected blog project root:")
                        .foregroundStyle(.secondary)
                    Text("docker compose up --build -d")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Text(store.projectRoot.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            if store.buildLog.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "hammer")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("No Docker build log yet")
                        .font(.headline)
                    Text("Run Docker Build when you want to test the local container.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(store.buildLog)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
