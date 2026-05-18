import AppKit
import SwiftUI

struct SocialLinksPreferencesView: View {
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
                    Text("src/user-settings.json USER_SOCIALS")
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
                    Text("Check src/user-settings.json USER_SOCIALS.")
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
        guard store.hasProject else { return }
        do {
            let loaded = try store.readHomeSettings()
            settings = loaded
            lastLoaded = loaded
            message = "Loaded src/user-settings.json"
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() {
        guard store.hasProject else { return }
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
