import AppKit
import SwiftUI

@main
struct AstroPaperEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = BlogStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 1080, minHeight: 680)
                .onAppear {
                    appDelegate.store = store
                    store.loadDefaultProjectIfAvailable()
                }
        }
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    Task { @MainActor in
                        store.saveCurrentDocument()
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!store.canSave)
            }

            CommandGroup(after: .saveItem) {
                Button(store.editorMode == .edit ? "Preview" : "Edit") {
                    store.toggleEditorMode()
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(!store.canTogglePreview)
            }
        }

        Settings {
            PreferencesView(store: store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: BlogStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        return store.confirmTermination()
    }
}
