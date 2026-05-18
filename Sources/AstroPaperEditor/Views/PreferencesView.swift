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

            AssetImagePreferencesView(store: store)
                .tabItem {
                    Label("Assets", systemImage: "photo.stack")
                }

            GitPreferencesView(
                gitController: store.gitController,
                hasProject: store.hasProject,
                projectRoot: store.projectRoot,
                onRefreshGitStatus: store.refreshGitStatus,
                onConfigureGit: store.configureGit
            )
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

struct ProjectRequiredPlaceholder: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("Open a project")
                .font(.headline)
            Text("Choose a project before using these settings.")
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
