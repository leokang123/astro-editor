import AppKit
import SwiftUI

struct SocialLinksPreferencesView: View {
    @ObservedObject var store: BlogStore
    @ObservedObject var closeState: SettingsCloseState
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
                    Text("Site social links")
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
            } else if let socials = settings?.socials, !socials.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("Enabled")
                            .frame(width: 86, alignment: .leading)
                        Text("Service")
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
                    Text("No social links are configured for this site.")
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
                .disabled(!store.hasProject)
            }
            .font(.caption)
        }
        .onAppear {
            closeState.register(
                id: "social",
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
            reset()
            if store.hasProject {
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
                    Text("Enabled")
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
        guard store.hasProject else { return }
        do {
            let loaded = try store.readHomeSettings()
            settings = loaded
            lastLoaded = loaded
            message = "Loaded social links"
        } catch {
            message = error.localizedDescription
        }
    }

    private func reset() {
        settings = nil
        lastLoaded = nil
        message = ""
    }

    @discardableResult
    private func save() -> Bool {
        guard store.hasProject else { return false }
        guard let settings else { return false }
        do {
            try store.writeSocialSettings(settings)
            lastLoaded = settings
            message = "Saved social links"
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    private func discard() {
        settings = lastLoaded
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
            return "GitHub profile or repository URL"
        case "X":
            return "X/Twitter profile URL"
        case "LinkedIn":
            return "LinkedIn profile URL"
        case "Mail":
            return "Mail link. mailto:name@example.com is recommended"
        default:
            return "Home page social icon URL"
        }
    }
}
