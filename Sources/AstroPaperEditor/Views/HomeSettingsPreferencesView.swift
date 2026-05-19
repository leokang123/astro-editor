import AppKit
import SwiftUI

struct HomeSettingsPreferencesView: View {
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
                    Text("src/user-settings.json")
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
            if store.hasProject, settings == nil {
                reload()
            }
        }
        .onChange(of: store.hasProject) { hasProject in
            if hasProject, settings == nil {
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
            }
            .padding(8)
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
            let loaded = try store.readHomeSettings()
            settings = loaded
            lastLoaded = loaded
            descriptionDraft = loaded.homeDescription.joined(separator: "\n")
            message = "Loaded src/user-settings.json"
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() {
        guard store.hasProject else { return }
        guard let settings else { return }
        do {
            try store.writeHomeSettings(settings)
            lastLoaded = settings
            message = "Saved src/user-settings.json"
        } catch {
            message = error.localizedDescription
        }
    }
}
