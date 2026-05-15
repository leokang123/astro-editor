import AppKit
import Combine
import Foundation

@MainActor
final class BlogStore: ObservableObject {
    @Published var projectRoot = BlogFileService.defaultProjectRoot
    @Published var tree: [BlogNode] = []
    @Published var selectionID: String?
    @Published var currentDocument: BlogDocument?
    @Published var isDirty = false
    @Published var statusText = "Ready"
    @Published var buildLog = ""
    @Published var isBuilding = false
    @Published var message: AppMessage?
    @Published var editorMode: EditorMode = .edit

    private let fileService = BlogFileService()
    private let imageService = ImageService()
    private let buildService = BuildService()
    private let sitePageService = SitePageService()
    private let siteSettingsService = SiteSettingsService()

    var blogRoot: URL {
        fileService.blogRoot(for: projectRoot)
    }

    var aboutPageURL: URL {
        sitePageService.aboutURL(for: projectRoot)
    }

    var configURL: URL {
        siteSettingsService.configURL(for: projectRoot)
    }

    var canSave: Bool {
        currentDocument != nil && isDirty
    }

    var canTogglePreview: Bool {
        currentDocument != nil
    }

    var selectedNode: BlogNode? {
        guard let selectionID else { return nil }
        return node(withID: selectionID)
    }

    var categoryDestinations: [CategoryDestination] {
        var destinations = [
            CategoryDestination(id: BlogNodeID.root, title: "src/data/blog", url: blogRoot, relativePath: "")
        ]
        appendCategories(from: tree, into: &destinations, prefix: "")
        return destinations
    }

    func loadDefaultProjectIfAvailable() {
        guard tree.isEmpty, fileService.validateProjectRoot(projectRoot) else { return }
        rescan()
    }

    func chooseProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = projectRoot
        panel.message = "Choose the AstroPaper project root that contains src/data/blog."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard fileService.validateProjectRoot(url) else {
            message = AppMessage(text: "The selected folder does not contain src/data/blog.")
            return
        }

        if confirmDiscardOrSaveChanges() {
            projectRoot = url
            currentDocument = nil
            selectionID = nil
            rescan()
        }
    }

    func rescan() {
        do {
            tree = try fileService.scan(projectRoot: projectRoot)
            statusText = "Scanned \(blogRoot.path)"
        } catch {
            tree = []
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func selectNode(id: String?) {
        guard selectionID != id else { return }
        guard confirmDiscardOrSaveChanges() else { return }
        selectionID = id

        guard let id, let node = node(withID: id), node.kind == .document else {
            currentDocument = nil
            isDirty = false
            return
        }

        do {
            currentDocument = try fileService.readDocument(at: node.url, blogRoot: blogRoot)
            isDirty = false
            statusText = "Opened \(node.relativePath)"
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func updateBody(_ body: String) {
        guard currentDocument != nil else { return }
        currentDocument?.body = body
        isDirty = true
    }

    func updateFrontmatter(_ edit: (inout Frontmatter) -> Void) {
        guard currentDocument != nil else { return }
        edit(&currentDocument!.frontmatter)
        isDirty = true
    }

    func saveCurrentDocument() {
        guard var document = currentDocument else { return }
        document.frontmatter.modDatetime = DateFormatting.astropaperTimestamp.string(from: Date())
        do {
            try fileService.writeDocument(document)
            currentDocument = document
            isDirty = false
            statusText = "Saved \(document.relativePath)"
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func toggleEditorMode() {
        guard canTogglePreview else { return }
        editorMode = editorMode == .edit ? .preview : .edit
    }

    func createCategory(named name: String, parentID: String?) {
        do {
            let parent = categoryURL(for: parentID)
            let url = try fileService.createCategory(named: name, under: parent)
            rescan()
            if !isDirty {
                selectionID = BlogNodeID.make(kind: .category, relativePath: BlogFileService.relativePath(from: blogRoot, to: url))
            }
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func createDocument(title: String, description: String, tagsText: String, parentID: String?) {
        guard confirmDiscardOrSaveChanges() else { return }
        do {
            let parent = categoryURL(for: parentID)
            let url = try fileService.createDocument(
                title: title,
                description: description,
                tags: tagsText.trimmingForTags,
                under: parent
            )
            rescan()
            let id = BlogNodeID.make(kind: .document, relativePath: BlogFileService.relativePath(from: blogRoot, to: url))
            selectNode(id: id)
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func promptRenameSelected() {
        guard let node = selectedNode else { return }
        guard confirmDiscardOrSaveChanges() else { return }
        let alert = NSAlert()
        alert.messageText = node.kind == .document ? "Rename Document" : "Rename Category"
        alert.informativeText = "The filesystem name will be changed. Frontmatter title is not changed automatically."
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = node.kind == .document ? node.url.deletingPathExtension().lastPathComponent : node.name
        alert.accessoryView = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            let newURL = try fileService.rename(node: node, to: field.stringValue)
            rescan()
            let relativePath = BlogFileService.relativePath(from: blogRoot, to: newURL)
            selectionID = BlogNodeID.make(kind: node.kind, relativePath: relativePath)
            if node.kind == .document, currentDocument?.fileURL == node.url {
                currentDocument?.fileURL = newURL
                currentDocument?.relativePath = relativePath
            }
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func moveSelected(to destinationID: String) {
        guard let node = selectedNode else { return }
        guard confirmDiscardOrSaveChanges() else { return }
        guard let destination = categoryDestinations.first(where: { $0.id == destinationID }) else { return }

        if node.kind == .category {
            let sourcePath = node.url.standardizedFileURL.path
            let destinationPath = destination.url.standardizedFileURL.path
            guard !destinationPath.hasPrefix(sourcePath + "/") && sourcePath != destinationPath else {
                message = AppMessage(text: BlogFileError.invalidMove.localizedDescription)
                return
            }
        }

        do {
            let newURL = try fileService.move(node: node, to: destination.url)
            rescan()
            let relativePath = BlogFileService.relativePath(from: blogRoot, to: newURL)
            selectionID = BlogNodeID.make(kind: node.kind, relativePath: relativePath)
            if node.kind == .document, currentDocument?.fileURL == node.url {
                currentDocument?.fileURL = newURL
                currentDocument?.relativePath = relativePath
            }
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func deleteSelected() {
        guard let node = selectedNode else { return }
        guard confirmDiscardOrSaveChanges() else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Move to Trash?"
        alert.informativeText = "\(node.name) will be moved to the macOS Trash."
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try fileService.trash(node: node)
            if currentDocument?.fileURL == node.url {
                currentDocument = nil
                isDirty = false
            }
            selectionID = nil
            rescan()
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func insertImages(_ images: [PastedImage]) -> String {
        guard currentDocument != nil else { return "" }
        do {
            return try imageService.save(images: images, inProjectRoot: projectRoot)
        } catch {
            message = AppMessage(text: error.localizedDescription)
            return ""
        }
    }

    func runBuild() {
        guard !isBuilding else { return }
        isBuilding = true
        buildLog = ""
        statusText = "Building with Docker..."

        Task {
            do {
                let status = try await buildService.runDockerCompose(at: projectRoot) { [weak self] text in
                    self?.buildLog += text
                }
                isBuilding = false
                statusText = status == 0 ? "Docker build finished" : "Docker build exited with \(status)"
            } catch {
                isBuilding = false
                message = AppMessage(text: error.localizedDescription)
            }
        }
    }

    func openLocalhost() {
        buildService.openLocalhost()
    }

    func readAboutPage() throws -> SiteMarkdownPage {
        try sitePageService.readAbout(projectRoot: projectRoot)
    }

    func writeAboutPage(_ page: SiteMarkdownPage) throws {
        try sitePageService.writeAbout(page, projectRoot: projectRoot)
        statusText = "Saved src/pages/about.md"
    }

    func readHomeSettings() throws -> HomeSettings {
        try siteSettingsService.readHomeSettings(projectRoot: projectRoot)
    }

    func writeHomeSettings(_ settings: HomeSettings) throws {
        try siteSettingsService.writeHomeSettings(settings, projectRoot: projectRoot)
        statusText = "Saved src/config.ts"
    }

    func confirmTermination() -> NSApplication.TerminateReply {
        guard isDirty else { return .terminateNow }
        let alert = unsavedChangesAlert()
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            saveCurrentDocument()
            return isDirty ? .terminateCancel : .terminateNow
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }

    private func confirmDiscardOrSaveChanges() -> Bool {
        guard isDirty else { return true }
        let response = unsavedChangesAlert().runModal()
        switch response {
        case .alertFirstButtonReturn:
            saveCurrentDocument()
            return !isDirty
        case .alertSecondButtonReturn:
            isDirty = false
            return true
        default:
            return false
        }
    }

    private func unsavedChangesAlert() -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Save changes?"
        alert.informativeText = "This document has unsaved edits."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        return alert
    }

    private func categoryURL(for id: String?) -> URL {
        if let id, let node = node(withID: id) {
            switch node.kind {
            case .category:
                return node.url
            case .document:
                return node.url.deletingLastPathComponent()
            }
        }
        return blogRoot
    }

    private func node(withID id: String) -> BlogNode? {
        tree.firstNode { $0.id == id }
    }

    private func appendCategories(from nodes: [BlogNode], into destinations: inout [CategoryDestination], prefix: String) {
        for node in nodes where node.kind == .category {
            let title = node.relativePath.isEmpty ? node.name : node.relativePath
            destinations.append(CategoryDestination(id: node.id, title: title, url: node.url, relativePath: node.relativePath))
            appendCategories(from: node.children, into: &destinations, prefix: node.relativePath)
        }
    }
}

struct AppMessage: Identifiable {
    let id = UUID()
    var text: String
}

private extension Array where Element == BlogNode {
    func firstNode(where predicate: (BlogNode) -> Bool) -> BlogNode? {
        for node in self {
            if predicate(node) { return node }
            if let child = node.children.firstNode(where: predicate) {
                return child
            }
        }
        return nil
    }
}
