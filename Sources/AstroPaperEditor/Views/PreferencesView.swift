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
