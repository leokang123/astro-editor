import AppKit
import Combine
import Foundation

@MainActor
final class BlogStore: ObservableObject {
    private static let initialProjectState = BlogStore.savedProjectState()

    @Published var projectRoot = BlogStore.initialProjectState.projectRoot
    @Published private(set) var hasProject = BlogStore.initialProjectState.hasProject
    @Published var tree: [BlogNode] = []
    @Published var selectionID: String?
    @Published var currentDocument: BlogDocument?
    @Published var isDirty = false
    @Published var statusText = "Ready"
    @Published var buildLog = ""
    @Published var isBuilding = false
    @Published var isStoppingPreview = false
    @Published var assetCleanupMessage = ""
    @Published var isAssetScanRunning = false
    @Published var isAssetOptimizeRunning = false
    @Published var message: AppMessage?
    @Published var editorMode: EditorMode = .edit
    @Published private(set) var previewDocumentID: String?
    @Published var activeSheet: ActiveSheet?
    @Published var creationParentID: String?
    @Published var actionNodeID: String?
    @Published var sidebarSortOption = BlogStore.savedSidebarSortOption() {
        didSet {
            guard oldValue != sidebarSortOption else { return }
            saveSidebarSortOption(sidebarSortOption)
            if hasProject {
                rescan()
            }
        }
    }

    let gitController = GitController()

    private let fileService = BlogFileService()
    private let templateService = AstroPaperTemplateService()
    private let gitService = GitService()
    private let imageService = ImageService()
    private let buildService = BuildService()
    private let sitePageService = SitePageService()
    private let siteSettingsService = SiteSettingsService()
    private let maxBuildLogLength = 20_000
    private let documentSession = DocumentSession()
    private var scanTask: Task<Void, Never>?
    private var buildTask: Task<Void, Never>?
    private static let lastProjectRootKey = "lastProjectRoot"
    private static let sidebarSortOptionKey = "sidebarSortOption"

    var editorSourcePosition: Double {
        documentSession.sourcePosition
    }

    var blogRoot: URL {
        fileService.blogRoot(for: projectRoot)
    }

    var aboutPageURL: URL {
        sitePageService.aboutURL(for: projectRoot)
    }

    var configURL: URL {
        siteSettingsService.configURL(for: projectRoot)
    }

    var userSettingsURL: URL {
        siteSettingsService.userSettingsURL(for: projectRoot)
    }

    var faviconURL: URL {
        projectRoot
            .appendingPathComponent("public", isDirectory: true)
            .appendingPathComponent("favicon.svg")
    }

    var defaultOGImageURL: URL {
        projectRoot
            .appendingPathComponent("public", isDirectory: true)
            .appendingPathComponent("astropaper-og.jpg")
    }

    var canSave: Bool {
        hasProject && currentDocument != nil && isDirty
    }

    var canTogglePreview: Bool {
        currentDocument != nil
    }

    var canCommitAndPush: Bool {
        hasProject && gitController.canRunOperation
    }

    var selectedNode: BlogNode? {
        guard let selectionID else { return nil }
        return node(withID: selectionID)
    }

    var actionNode: BlogNode? {
        guard let actionNodeID else { return nil }
        return node(withID: actionNodeID)
    }

    var categoryDestinations: [CategoryDestination] {
        var destinations = [
            CategoryDestination(id: BlogNodeID.root, title: "All Posts", url: blogRoot)
        ]
        appendCategories(from: tree, into: &destinations)
        return destinations
    }

    func loadDefaultProjectIfAvailable() {
        guard tree.isEmpty, hasProject else { return }
        rescan()
    }

    func chooseProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = projectRoot
        panel.message = "Choose the folder for your AstroPaper site."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard fileService.validateProjectRoot(url) else {
            offerProjectCreationIfPossible(at: url)
            return
        }

        if confirmDiscardOrSaveChanges() {
            resetProjectRuntimeState()
            projectRoot = url
            hasProject = true
            saveProjectRoot(url)
            closeCurrentDocument()
            selectionID = nil
            rescan()
        }
    }

    private func offerProjectCreationIfPossible(at url: URL) {
        do {
            guard try templateService.isEmptyProjectDestination(url) else {
                message = AppMessage(text: "The selected folder is not an AstroPaper project, and it is not empty. Choose an existing project, or select an empty folder to create a new one.")
                return
            }
        } catch {
            message = AppMessage(text: error.localizedDescription)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Start AstroPaper project?"
        alert.informativeText = "The selected folder is empty. Create a new project from the bundled template, or clone an existing Git repository into this folder."
        alert.addButton(withTitle: "Create Project")
        alert.addButton(withTitle: "Clone Repository")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response != .alertThirdButtonReturn else { return }
        if response == .alertSecondButtonReturn {
            promptCloneRepository(into: url)
            return
        }

        guard confirmDiscardOrSaveChanges() else { return }

        do {
            try templateService.createProject(at: url)
            resetProjectRuntimeState()
            projectRoot = url
            hasProject = true
            saveProjectRoot(url)
            closeCurrentDocument()
            selectionID = nil
            statusText = "Created AstroPaper project"
            rescan(selectingRelativePath: "examples/welcome.md", editorMode: .preview)
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    private func promptCloneRepository(into url: URL) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Clone Git repository"
        alert.informativeText = "Enter the repository URL to clone into the empty selected folder."
        alert.addButton(withTitle: "Clone")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
        textField.placeholderString = "https://github.com/user/repo.git"
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let remoteURL = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remoteURL.isEmpty else {
            message = AppMessage(text: "Remote URL is required.")
            return
        }
        guard confirmDiscardOrSaveChanges() else { return }

        cloneRepository(remoteURL: remoteURL, into: url)
    }

    private func cloneRepository(remoteURL: String, into url: URL) {
        let service = gitService
        statusText = "Cloning Git repository..."

        Task {
            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try service.clone(remoteURL: remoteURL, into: url)
                }.value

                guard fileService.validateProjectRoot(url) else {
                    statusText = "Clone finished, but project is invalid"
                    message = AppMessage(text: "The repository was cloned, but it does not look like an AstroPaper project with src/data/blog.")
                    return
                }

                resetProjectRuntimeState()
                projectRoot = url
                hasProject = true
                saveProjectRoot(url)
                closeCurrentDocument()
                selectionID = nil
                statusText = "Cloned Git repository"
                rescan()
                gitController.refreshStatus(at: url)
            } catch {
                statusText = "Clone failed"
                message = AppMessage(text: error.localizedDescription)
            }
        }
    }

    func rescan(selectingRelativePath selectedRelativePath: String? = nil, editorMode selectedEditorMode: EditorMode? = nil) {
        guard fileService.validateProjectRoot(projectRoot) else {
            handleUnavailableProject()
            return
        }

        let root = projectRoot
        let service = fileService
        let sortOption = sidebarSortOption
        scanTask?.cancel()
        statusText = "Scanning posts..."

        scanTask = Task {
            do {
                let scannedTree = try await Task.detached(priority: .userInitiated) {
                    try service.scan(projectRoot: root, sortOption: sortOption)
                }.value
                guard !Task.isCancelled, projectRoot == root else { return }
                tree = scannedTree
                statusText = "Scanned posts"
                if let selectedRelativePath,
                   let node = scannedTree.firstNode(where: { $0.kind == .document && $0.relativePath == selectedRelativePath }) {
                    selectionID = node.id
                    try openDocument(node)
                    if let selectedEditorMode {
                        editorMode = selectedEditorMode
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, projectRoot == root else { return }
                tree = []
                message = AppMessage(text: error.localizedDescription)
            }
        }
    }

    func selectNode(id: String?) {
        guard hasProject else { return }
        guard selectionID != id else { return }
        guard confirmDiscardOrSaveChanges() else { return }
        hideEditorFindInterface()
        selectionID = id

        guard let id, let node = node(withID: id), node.kind == .document else {
            closeCurrentDocument()
            return
        }

        do {
            try openDocument(node)
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func markBodyChanged() {
        documentSession.markBodyChanged(
            currentDocument: { [weak self] in self?.currentDocument },
            isDirty: isDirty,
            setDirty: { [weak self] value in self?.isDirty = value }
        )
    }

    func setEditorBodyProvider(_ provider: (() -> String?)?) {
        documentSession.setBodyProvider(provider)
    }

    func setEditorSourcePositionProvider(_ provider: (() -> Double?)?) {
        documentSession.setSourcePositionProvider(provider)
    }

    func prepareForLiveResize() {
        guard currentDocument != nil else { return }
        captureEditorSourcePosition()
        flushSessionDraftsToCurrentDocument()
        previewDocumentID = nil
        if editorMode == .preview {
            editorMode = .edit
        }
    }

    func setFrontmatterProvider(_ provider: FrontmatterDraftProvider?) {
        documentSession.setFrontmatterProvider(provider)
    }

    func updateEditorSourcePosition(_ position: Double) {
        guard abs(editorSourcePosition - position) >= 0.0001 else { return }
        documentSession.updateSourcePosition(position)
    }

    func markFrontmatterChanged() {
        documentSession.markFrontmatterChanged(
            currentDocument: { [weak self] in self?.currentDocument },
            isDirty: isDirty,
            setDirty: { [weak self] value in self?.isDirty = value }
        )
    }

    func updateFrontmatter(_ edit: (inout Frontmatter) -> Void) {
        guard var document = currentDocument else { return }
        let originalFrontmatter = document.frontmatter
        edit(&document.frontmatter)
        if document.frontmatter != originalFrontmatter {
            currentDocument = document
        }
        recomputeDirtyState()
    }

    func saveCurrentDocument() {
        guard hasProject else {
            statusText = "Open a project first"
            return
        }
        flushSessionDraftsToCurrentDocument()
        guard var document = currentDocument else { return }
        document.frontmatter.modDatetime = DateFormatting.astropaperTimestamp.string(from: Date())
        do {
            try fileService.writeDocument(document)
            currentDocument = document
            documentSession.markSaved(document)
            isDirty = false
            statusText = "Saved \(document.relativePath)"
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func toggleEditorMode() {
        guard canTogglePreview else { return }
        previewDocumentID = currentDocument?.fileURL.path
        if editorMode == .edit {
            hideEditorFindInterface()
            captureEditorSourcePosition()
            flushSessionDraftsToCurrentDocument()
        }
        editorMode = editorMode == .edit ? .preview : .edit
    }

    @discardableResult
    func showEditorFindInterface() -> Bool {
        guard currentDocument != nil else { return false }
        if editorMode == .preview {
            toggleEditorMode()
            DispatchQueue.main.async {
                _ = EditorCommandDispatcher.performTextFinderAction(.showFindInterface)
            }
            return true
        }
        return EditorCommandDispatcher.performTextFinderAction(.showFindInterface)
    }

    private func hideEditorFindInterface() {
        _ = EditorCommandDispatcher.performTextFinderAction(.hideFindInterface, focusTextView: false)
    }

    func requestNewCategory(parentID: String? = nil) {
        guard hasProject else { return }
        creationParentID = parentID
        activeSheet = .newCategory
    }

    func requestNewDocument(parentID: String? = nil) {
        guard hasProject else { return }
        creationParentID = parentID
        activeSheet = .newDocument
    }

    func createCategory(named name: String, parentID: String?) {
        guard hasProject else { return }
        do {
            let parent = categoryURL(for: parentID)
            let url = try fileService.createCategory(named: name, under: parent)
            rescan()
            selectionID = BlogNodeID.make(kind: .category, relativePath: BlogFileService.relativePath(from: blogRoot, to: url))
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func createDocument(
        title: String,
        description: String,
        tagsText: String,
        order: String?,
        featured: Bool,
        ogImageSourceURL: URL?,
        parentID: String?
    ) {
        guard hasProject else { return }
        guard confirmDiscardOrSaveChanges() else { return }
        do {
            let parent = categoryURL(for: parentID)
            let ogImage = try ogImageSourceURL.map {
                try imageService.copyToAssets(from: $0, inProjectRoot: projectRoot, suggestedName: "\(title)-og")
            }
            let url = try fileService.createDocument(
                title: title,
                description: description,
                tags: tagsText.trimmingForTags,
                order: order,
                featured: featured ? true : nil,
                ogImage: ogImage,
                under: parent
            )
            let relativePath = BlogFileService.relativePath(from: blogRoot, to: url)
            selectionID = BlogNodeID.make(kind: .document, relativePath: relativePath)
            try openDocument(at: url, relativePath: relativePath)
            rescan()
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func creationLocationText(parentID: String?) -> String {
        let parent = categoryURL(for: parentID)
        let relative = BlogFileService.relativePath(from: blogRoot, to: parent)
        return relative.isEmpty ? "All Posts" : relative
    }

    func promptRenameSelected() {
        guard hasProject else { return }
        guard let selectionID else { return }
        promptRenameNode(id: selectionID)
    }

    func promptRenameNode(id: String) {
        guard hasProject else { return }
        guard let node = node(withID: id) else { return }
        guard confirmDiscardOrSaveChanges() else { return }
        let alert = NSAlert()
        alert.messageText = node.kind == .document ? "Rename Document" : "Rename Category"
        alert.informativeText = "The file name will be changed. The post title is not changed automatically."
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
            updateCurrentDocumentLocation(matching: node.url, to: newURL, relativePath: relativePath, kind: node.kind)
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func requestMoveSelected() {
        guard hasProject else { return }
        guard let selectionID else { return }
        requestMoveNode(id: selectionID)
    }

    func requestMoveNode(id: String) {
        guard hasProject else { return }
        actionNodeID = id
        activeSheet = .move
    }

    func moveActionNode(to destinationID: String) {
        guard hasProject else { return }
        guard let actionNodeID else { return }
        moveNode(id: actionNodeID, to: destinationID)
    }

    func moveNode(id: String, to destinationID: String) {
        guard hasProject else { return }
        guard let node = node(withID: id) else { return }
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
            updateCurrentDocumentLocation(matching: node.url, to: newURL, relativePath: relativePath, kind: node.kind)
            actionNodeID = nil
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func deleteSelected() {
        guard hasProject else { return }
        guard let selectionID else { return }
        deleteNode(id: selectionID)
    }

    func deleteNode(id: String) {
        guard hasProject else { return }
        guard let node = node(withID: id) else { return }
        let containsCurrentDocument = nodeContainsCurrentDocument(node)
        if containsCurrentDocument {
            recomputeDirtyState()
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Move to Trash?"
        if containsCurrentDocument && isDirty {
            alert.informativeText = "\(node.name) will be moved to the macOS Trash. Unsaved changes in the open document will be discarded."
        } else {
            alert.informativeText = "\(node.name) will be moved to the macOS Trash."
        }
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try fileService.trash(node: node)
            if containsCurrentDocument {
                closeCurrentDocument()
            }
            if nodeContainsSelection(node) {
                selectionID = nil
            }
            rescan()
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    private func nodeContainsCurrentDocument(_ node: BlogNode) -> Bool {
        guard let documentURL = currentDocument?.fileURL.standardizedFileURL else { return false }
        let nodeURL = node.url.standardizedFileURL
        switch node.kind {
        case .document:
            return documentURL == nodeURL
        case .category:
            return documentURL.path.hasPrefix(nodeURL.path + "/")
        }
    }

    private func nodeContainsSelection(_ node: BlogNode) -> Bool {
        guard let selectedNode else { return false }
        let selectedURL = selectedNode.url.standardizedFileURL
        let nodeURL = node.url.standardizedFileURL
        switch node.kind {
        case .document:
            return selectedURL == nodeURL
        case .category:
            return selectedURL.path.hasPrefix(nodeURL.path + "/")
        }
    }

    func insertImages(_ images: [PastedImage]) -> String {
        guard currentDocument != nil else { return "" }
        do {
            let saved = try imageService.save(images: images, inProjectRoot: projectRoot)
            if currentDocument?.frontmatter.ogImage == nil, let firstAssetPath = saved.assetPaths.first {
                currentDocument?.frontmatter.ogImage = firstAssetPath
                recomputeDirtyState()
            }
            return saved.markdown
        } catch {
            message = AppMessage(text: error.localizedDescription)
            return ""
        }
    }

    func setOGImage(from sourceURL: URL) {
        guard var document = currentDocument else { return }
        do {
            let title = document.frontmatter.title
            document.frontmatter.ogImage = try imageService.copyToAssets(
                from: sourceURL,
                inProjectRoot: projectRoot,
                suggestedName: "\(title)-og"
            )
            currentDocument = document
            recomputeDirtyState()
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func clearOGImage() {
        guard var document = currentDocument, document.frontmatter.ogImage != nil else { return }
        document.frontmatter.ogImage = nil
        currentDocument = document
        recomputeDirtyState()
    }

    func resolvedAssetImageURL(_ assetPath: String?) -> URL? {
        guard let assetPath else { return nil }
        let trimmed = assetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(ImageService.assetImagePrefix) else { return nil }
        let filename = String(trimmed.dropFirst(ImageService.assetImagePrefix.count))
        guard !filename.isEmpty else { return nil }
        return projectRoot
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("images", isDirectory: true)
            .appendingPathComponent(filename)
    }

    func resolvedPublicURL(_ publicPath: String?) -> URL? {
        guard let publicPath else { return nil }
        let trimmed = publicPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }
        let relativePath = String(trimmed.dropFirst())
        guard !relativePath.isEmpty, !relativePath.contains("..") else { return nil }
        return projectRoot
            .appendingPathComponent("public", isDirectory: true)
            .appendingPathComponent(relativePath)
    }

    func copyAboutProfileImage(from sourceURL: URL) throws -> String {
        try imageService.copyAboutProfileImage(from: sourceURL, inProjectRoot: projectRoot)
    }

    func replaceFavicon(from sourceURL: URL) throws {
        try imageService.replacePublicFile(named: "favicon.svg", from: sourceURL, inProjectRoot: projectRoot)
    }

    func replaceDefaultOGImage(from sourceURL: URL) throws {
        try imageService.replacePublicFile(named: "astropaper-og.jpg", from: sourceURL, inProjectRoot: projectRoot)
    }

    func stageTemporaryFile(from sourceURL: URL, filename: String) throws -> URL {
        try imageService.stageTemporaryFile(from: sourceURL, filename: filename)
    }

    func runBuild() {
        guard hasProject else {
            statusText = "Open a project first"
            return
        }
        guard !isBuilding else { return }
        isBuilding = true
        buildLog = ""
        statusText = "Building with Docker..."
        var pendingOutput = ""
        var lastFlush = Date.distantPast

        buildTask = Task {
            do {
                let status = try await buildService.runDockerCompose(at: projectRoot) { [weak self] text in
                    guard let self else { return }
                    pendingOutput += text
                    let now = Date()
                    guard now.timeIntervalSince(lastFlush) > 0.2 || pendingOutput.count > 4_000 else { return }
                    appendBuildLog(pendingOutput)
                    pendingOutput = ""
                    lastFlush = now
                }
                if !pendingOutput.isEmpty {
                    appendBuildLog(pendingOutput)
                }
                let wasCancelled = Task.isCancelled
                isBuilding = false
                buildTask = nil
                statusText = wasCancelled ? "Docker build cancelled" : (status == 0 ? "Docker build finished" : "Docker build exited with \(status)")
            } catch {
                if !pendingOutput.isEmpty {
                    appendBuildLog(pendingOutput)
                }
                let wasCancelled = Task.isCancelled
                isBuilding = false
                buildTask = nil
                if wasCancelled {
                    statusText = "Docker build cancelled"
                } else {
                    message = AppMessage(text: error.localizedDescription)
                }
            }
        }
    }

    func cancelBuild() {
        guard isBuilding else { return }
        buildTask?.cancel()
        buildService.cancelCurrentOperation()
        statusText = "Cancelling Docker build..."
        appendBuildLog("\nCancelling Docker build...\n")
    }

    func stopDockerPreview() {
        guard hasProject else {
            statusText = "Open a project first"
            return
        }
        guard !isStoppingPreview else { return }
        isStoppingPreview = true
        statusText = "Stopping Docker preview..."

        Task {
            do {
                let status = try await buildService.stopDockerCompose(at: projectRoot) { [weak self] text in
                    self?.appendBuildLog(text)
                }
                isStoppingPreview = false
                statusText = status == 0 ? "Docker preview stopped" : "Docker stop exited with \(status)"
            } catch {
                isStoppingPreview = false
                message = AppMessage(text: error.localizedDescription)
            }
        }
    }

    private func appendBuildLog(_ text: String) {
        buildLog += text
        if buildLog.count > maxBuildLogLength {
            buildLog = "… showing last \(maxBuildLogLength / 1_000)KB of Docker output …\n" + String(buildLog.suffix(maxBuildLogLength))
        }
    }

    func refreshGitStatus() {
        guard hasProject else { return }
        gitController.refreshStatus(at: projectRoot)
    }

    func configureGit(remoteURL: String, branch: String) {
        guard hasProject else { return }
        gitController.configure(
            at: projectRoot,
            remoteURL: remoteURL,
            branch: branch,
            onStatusText: { [weak self] text in self?.statusText = text },
            onError: { [weak self] text in self?.message = AppMessage(text: text) }
        )
    }

    func commitAndPush(message commitMessage: String) {
        guard hasProject else { return }
        guard gitController.canRunOperation else { return }
        guard confirmDiscardOrSaveChanges() else { return }

        gitController.commitAndPush(
            at: projectRoot,
            message: commitMessage,
            onStatusText: { [weak self] text in self?.statusText = text },
            onError: { [weak self] text in self?.message = AppMessage(text: text) }
        )
    }

    func openWebsite() {
        guard hasProject else {
            statusText = "Open a project first"
            return
        }
        do {
            let rawWebsite = try siteSettingsService.readHomeSettings(projectRoot: projectRoot).website
            let website = rawWebsite.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !website.isEmpty else {
                message = AppMessage(text: "Website URL is empty in site settings.")
                return
            }

            let normalizedWebsite = website.contains("://") ? website : "https://\(website)"
            guard let url = URL(string: normalizedWebsite) else {
                message = AppMessage(text: "Website URL is invalid: \(website)")
                return
            }

            buildService.openURL(url)
            statusText = "Opened \(normalizedWebsite)"
        } catch {
            message = AppMessage(text: error.localizedDescription)
        }
    }

    func openLocalhost() {
        guard hasProject else {
            statusText = "Open a project first"
            return
        }
        buildService.openURL(BuildService.localPreviewURL)
        statusText = "Opened \(BuildService.localPreviewURL.absoluteString)"
    }

    func closeUnavailableProjectDocument() {
        guard !hasProject else { return }
        closeCurrentDocument()
        editorMode = .edit
        statusText = "No project selected"
    }

    private static func savedProjectState() -> ProjectState {
        guard let path = UserDefaults.standard.string(forKey: lastProjectRootKey) else {
            return ProjectState(projectRoot: BlogFileService.defaultProjectRoot, hasProject: false)
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        guard BlogFileService().validateProjectRoot(url) else {
            UserDefaults.standard.removeObject(forKey: lastProjectRootKey)
            return ProjectState(projectRoot: BlogFileService.defaultProjectRoot, hasProject: false)
        }
        return ProjectState(projectRoot: url, hasProject: true)
    }

    private static func savedSidebarSortOption() -> SidebarSortOption {
        guard let rawValue = UserDefaults.standard.string(forKey: sidebarSortOptionKey),
              let option = SidebarSortOption(rawValue: rawValue) else {
            return .fileName
        }
        return option
    }

    private func saveProjectRoot(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: Self.lastProjectRootKey)
    }

    private func saveSidebarSortOption(_ option: SidebarSortOption) {
        UserDefaults.standard.set(option.rawValue, forKey: Self.sidebarSortOptionKey)
    }

    private func clearSavedProjectRoot() {
        UserDefaults.standard.removeObject(forKey: Self.lastProjectRootKey)
    }

    private func handleUnavailableProject() {
        scanTask?.cancel()
        recomputeDirtyState()

        guard isDirty else {
            enterNoProjectState(closeDocument: true)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Project is no longer available"
        alert.informativeText = "The current document has unsaved changes. Keep it open so you can copy the content, or discard it and return to the project picker."
        alert.addButton(withTitle: "Keep Editing")
        alert.addButton(withTitle: "Discard and Close")

        if alert.runModal() == .alertFirstButtonReturn {
            enterNoProjectState(closeDocument: false)
            message = AppMessage(text: "The project is no longer available. The current document is still open, but it cannot be saved until you open a project.")
        } else {
            enterNoProjectState(closeDocument: true)
        }
    }

    private func enterNoProjectState(closeDocument: Bool) {
        hasProject = false
        clearSavedProjectRoot()
        tree = []
        selectionID = nil
        creationParentID = nil
        actionNodeID = nil
        activeSheet = nil
        resetProjectRuntimeState()
        if closeDocument {
            closeCurrentDocument()
            editorMode = .edit
        }
        statusText = "Project is no longer available"
    }

    private func resetProjectRuntimeState() {
        buildLog = ""
        assetCleanupMessage = ""
        gitController.resetProjectState()
    }

    func previewUnusedAssetImages() async -> AssetImageCleanupPreview? {
        guard hasProject else { return nil }
        guard !isAssetScanRunning, !isAssetOptimizeRunning else { return nil }
        isAssetScanRunning = true
        assetCleanupMessage = "Scanning assets/images..."
        let root = projectRoot

        do {
            let preview = try await Task.detached(priority: .utility) {
                try AssetImageCleanupService().preview(projectRoot: root)
            }.value
            assetCleanupMessage = "\(preview.unusedCount) unused of \(preview.allImageCount) images"
            isAssetScanRunning = false
            return preview
        } catch {
            assetCleanupMessage = error.localizedDescription
            isAssetScanRunning = false
            message = AppMessage(text: error.localizedDescription)
            return nil
        }
    }

    func moveAssetImagesToTrash(_ imageURLs: [URL]) async -> AssetImageCleanupResult? {
        guard hasProject else { return nil }
        guard !isAssetScanRunning, !isAssetOptimizeRunning else { return nil }
        guard !imageURLs.isEmpty else { return AssetImageCleanupResult(trashedImages: []) }
        isAssetOptimizeRunning = true
        assetCleanupMessage = "Moving \(imageURLs.count) unused images to Trash..."

        do {
            let result = try await Task.detached(priority: .utility) {
                try AssetImageCleanupService().moveImagesToTrash(imageURLs)
            }.value
            assetCleanupMessage = "Moved \(result.trashedImages.count) unused images to Trash"
            statusText = assetCleanupMessage
            isAssetOptimizeRunning = false
            return result
        } catch {
            assetCleanupMessage = error.localizedDescription
            isAssetOptimizeRunning = false
            message = AppMessage(text: error.localizedDescription)
            return nil
        }
    }

    func readAboutPage() throws -> SiteMarkdownPage {
        try sitePageService.readAbout(projectRoot: projectRoot)
    }

    func writeAboutPage(_ page: SiteMarkdownPage) throws {
        try sitePageService.writeAbout(page, projectRoot: projectRoot)
        statusText = "Saved About page"
    }

    func readHomeSettings() throws -> HomeSettings {
        try siteSettingsService.readHomeSettings(projectRoot: projectRoot)
    }

    func writeHomeSettings(_ settings: HomeSettings) throws {
        try siteSettingsService.writeHomeSettings(settings, projectRoot: projectRoot)
        statusText = "Saved site settings"
    }

    func writeSocialSettings(_ settings: HomeSettings) throws {
        try siteSettingsService.writeSocialSettings(settings, projectRoot: projectRoot)
        statusText = "Saved social links"
    }

    func featuredDocuments() throws -> [FeaturedDocument] {
        try documentNodes(from: tree).compactMap { node in
            let frontmatter = try fileService.readFrontmatter(at: node.url)
            guard frontmatter.featured == true else { return nil }
            return FeaturedDocument(
                id: node.id,
                title: frontmatter.title,
                relativePath: node.relativePath,
                url: node.url
            )
        }
    }

    func confirmTermination() -> NSApplication.TerminateReply {
        recomputeDirtyState()
        guard isDirty else { return .terminateNow }
        let alert = unsavedChangesAlert()
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            saveCurrentDocument()
            return isDirty ? .terminateCancel : .terminateNow
        case .alertSecondButtonReturn:
            discardEditorChanges(markClean: false)
            return .terminateNow
        default:
            return .terminateCancel
        }
    }

    private func confirmDiscardOrSaveChanges() -> Bool {
        recomputeDirtyState()
        guard isDirty else { return true }
        let response = unsavedChangesAlert().runModal()
        switch response {
        case .alertFirstButtonReturn:
            saveCurrentDocument()
            return !isDirty
        case .alertSecondButtonReturn:
            discardEditorChanges(markClean: true)
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

    private func openDocument(_ node: BlogNode) throws {
        try openDocument(at: node.url, relativePath: node.relativePath)
    }

    private func openDocument(at url: URL, relativePath: String) throws {
        let document = try fileService.readDocument(at: url, blogRoot: blogRoot)
        currentDocument = document
        documentSession.open(document)
        isDirty = false
        statusText = "Opened \(relativePath)"
    }

    private func closeCurrentDocument() {
        currentDocument = nil
        previewDocumentID = nil
        documentSession.close()
        isDirty = false
    }

    private func discardEditorChanges(markClean: Bool) {
        if let restoredDocument = documentSession.discardEditorChanges(markClean: markClean) {
            currentDocument = restoredDocument
            isDirty = false
        }
    }

    private func updateCurrentDocumentLocation(
        matching oldURL: URL,
        to newURL: URL,
        relativePath: String,
        kind: BlogNodeKind
    ) {
        guard kind == .document, currentDocument?.fileURL == oldURL else { return }
        currentDocument?.fileURL = newURL
        currentDocument?.relativePath = relativePath
        documentSession.updateSavedDocumentLocation(to: newURL, relativePath: relativePath)
    }

    private func flushSessionDraftsToCurrentDocument() {
        if documentSession.flushDrafts(to: &currentDocument) {
            recomputeDirtyState()
        }
    }

    private func recomputeDirtyState() {
        isDirty = documentSession.isDirty(currentDocument: currentDocument)
    }

    private func captureEditorSourcePosition() {
        documentSession.captureSourcePosition()
    }

    private func appendCategories(from nodes: [BlogNode], into destinations: inout [CategoryDestination]) {
        for node in nodes where node.kind == .category {
            let title = node.relativePath.isEmpty ? node.name : node.relativePath
            destinations.append(CategoryDestination(id: node.id, title: title, url: node.url))
            appendCategories(from: node.children, into: &destinations)
        }
    }

    private func documentNodes(from nodes: [BlogNode]) -> [BlogNode] {
        nodes.flatMap { node -> [BlogNode] in
            switch node.kind {
            case .document:
                return [node]
            case .category:
                return documentNodes(from: node.children)
            }
        }
    }
}

struct AppMessage: Identifiable {
    let id = UUID()
    var text: String
}

private struct ProjectState {
    let projectRoot: URL
    let hasProject: Bool
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
