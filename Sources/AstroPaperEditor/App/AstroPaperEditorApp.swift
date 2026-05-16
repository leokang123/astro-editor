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

            CommandGroup(after: .textEditing) {
                Button("Find") {
                    _ = EditorCommandDispatcher.performTextFinderAction(.showFindInterface)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    _ = EditorCommandDispatcher.performTextFinderAction(.nextMatch)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    _ = EditorCommandDispatcher.performTextFinderAction(.previousMatch)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }

        Settings {
            PreferencesView(store: store)
        }
    }
}

private enum EditorCommandDispatcher {
    static func performFindShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard flags.contains(.command),
              !flags.contains(.option),
              !flags.contains(.control),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }

        switch (key, flags.contains(.shift)) {
        case ("f", false):
            return performTextFinderAction(.showFindInterface)
        case ("g", false):
            return performTextFinderAction(.nextMatch)
        case ("g", true):
            return performTextFinderAction(.previousMatch)
        default:
            return false
        }
    }

    static func performTextFinderAction(_ action: NSTextFinder.Action) -> Bool {
        guard let textView = NSApp.keyWindow?.contentView?.firstDescendant(ofType: PasteAwareTextView.self) else {
            return false
        }

        let sender = NSMenuItem()
        sender.tag = action.rawValue
        textView.window?.makeFirstResponder(textView)
        textView.performTextFinderAction(sender)
        return true
    }
}

private extension NSView {
    func firstDescendant<ViewType: NSView>(ofType type: ViewType.Type) -> ViewType? {
        if let matchingView = self as? ViewType {
            return matchingView
        }

        for subview in subviews {
            if let matchingView = subview.firstDescendant(ofType: type) {
                return matchingView
            }
        }

        return nil
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: BlogStore?
    private var keyDownMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            EditorCommandDispatcher.performFindShortcut(event) ? nil : event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        return store.confirmTermination()
    }
}
