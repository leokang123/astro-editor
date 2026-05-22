import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var store: BlogStore
    @StateObject private var siteImageDraft = SiteImageDraft()
    @StateObject private var closeState = SettingsCloseState()

    var body: some View {
        TabView {
            ProjectPreferencesView(store: store)
                .tabItem {
                    Label("Project", systemImage: "folder")
                }

            AboutPagePreferencesView(store: store, closeState: closeState)
                .tabItem {
                    Label("About", systemImage: "person.text.rectangle")
                }

            HomeSettingsPreferencesView(store: store, siteImageDraft: siteImageDraft, closeState: closeState)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            SocialLinksPreferencesView(store: store, closeState: closeState)
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
        .background(SettingsCloseGuard {
            confirmUnsavedSettings()
        })
    }

    private func confirmUnsavedSettings() -> Bool {
        guard closeState.hasUnsaved else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Save unsaved settings?"
        alert.informativeText = "One or more settings tabs have unsaved changes."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return closeState.saveAll()
        case .alertSecondButtonReturn:
            closeState.discardAll()
            return true
        default:
            return false
        }
    }
}

@MainActor
final class SettingsCloseState: ObservableObject {
    private var items: [String: SettingsCloseItem] = [:]

    var hasUnsaved: Bool {
        items.values.contains { $0.hasUnsaved() }
    }

    func register(
        id: String,
        hasUnsaved: @escaping () -> Bool,
        save: @escaping () -> Bool,
        discard: @escaping () -> Void
    ) {
        items[id] = SettingsCloseItem(
            hasUnsaved: hasUnsaved,
            save: save,
            discard: discard
        )
    }

    func saveAll() -> Bool {
        for item in unsavedItems {
            guard item.save() else { return false }
        }
        return true
    }

    func discardAll() {
        for item in unsavedItems {
            item.discard()
        }
    }

    private var unsavedItems: [SettingsCloseItem] {
        items.values
            .filter { $0.hasUnsaved() }
    }
}

private struct SettingsCloseItem {
    var hasUnsaved: () -> Bool
    var save: () -> Bool
    var discard: () -> Void
}

private struct SettingsCloseGuard: NSViewRepresentable {
    let shouldClose: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(shouldClose: shouldClose)
    }

    func makeNSView(context: Context) -> CloseGuardView {
        let view = CloseGuardView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: CloseGuardView, context: Context) {
        context.coordinator.shouldClose = shouldClose
        nsView.coordinator = context.coordinator
        nsView.attachIfPossible()
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var shouldClose: () -> Bool

        init(shouldClose: @escaping () -> Bool) {
            self.shouldClose = shouldClose
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            shouldClose()
        }
    }

    final class CloseGuardView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            attachIfPossible()
        }

        func attachIfPossible() {
            guard let window, let coordinator else { return }
            window.delegate = coordinator
        }
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
