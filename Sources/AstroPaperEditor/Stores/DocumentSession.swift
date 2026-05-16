import Foundation

typealias FrontmatterDraftApplier = (inout Frontmatter) -> Void
typealias FrontmatterDraftProvider = () -> FrontmatterDraftApplier?

@MainActor
final class DocumentSession {
    private let editorSession = EditorSession()
    private var savedDocumentSnapshot: BlogDocument?
    private var bodyDirtyRecomputeTask: Task<Void, Never>?
    private var frontmatterProvider: FrontmatterDraftProvider?

    var topLine: Int {
        editorSession.topLine
    }

    func setBodyProvider(_ provider: (() -> String?)?) {
        editorSession.setBodyProvider(provider)
    }

    func setTopLineProvider(_ provider: (() -> Int?)?) {
        editorSession.setTopLineProvider(provider)
    }

    func setFrontmatterProvider(_ provider: FrontmatterDraftProvider?) {
        frontmatterProvider = provider
    }

    func updateTopLine(_ line: Int) {
        editorSession.updateTopLine(line)
    }

    func captureTopLine() {
        editorSession.captureTopLine()
    }

    func open(_ document: BlogDocument) {
        savedDocumentSnapshot = document
        cancelDirtyRecomputes()
        editorSession.reset()
        frontmatterProvider = nil
    }

    func close() {
        savedDocumentSnapshot = nil
        cancelDirtyRecomputes()
        editorSession.reset()
        frontmatterProvider = nil
    }

    func markSaved(_ document: BlogDocument) {
        savedDocumentSnapshot = document
        cancelDirtyRecomputes()
    }

    func markBodyChanged(
        currentDocument: @escaping @MainActor () -> BlogDocument?,
        isDirty: Bool,
        setDirty: @escaping @MainActor (Bool) -> Void
    ) {
        guard currentDocument() != nil else { return }
        if !isDirty {
            setDirty(true)
        }
        scheduleBodyDirtyRecompute(currentDocument: currentDocument, setDirty: setDirty)
    }

    func markFrontmatterChanged(
        currentDocument: @escaping @MainActor () -> BlogDocument?,
        isDirty: Bool,
        setDirty: @escaping @MainActor (Bool) -> Void
    ) {
        guard currentDocument() != nil else { return }
        if !isDirty {
            setDirty(true)
        }
    }

    func isDirty(currentDocument: BlogDocument?) -> Bool {
        guard let savedDocumentSnapshot else {
            return currentDocument != nil
        }
        return comparableDocument(currentDocument) != savedDocumentSnapshot
    }

    func discardEditorChanges(markClean: Bool) -> BlogDocument? {
        editorSession.discardBodyProvider()
        guard markClean else { return nil }
        cancelDirtyRecomputes()
        return savedDocumentSnapshot
    }

    func updateSavedDocumentLocation(to newURL: URL, relativePath: String) {
        savedDocumentSnapshot?.fileURL = newURL
        savedDocumentSnapshot?.relativePath = relativePath
    }

    @discardableResult
    func flushDrafts(to document: inout BlogDocument?) -> Bool {
        var didChange = false
        if let body = editorSession.currentBody(), document?.body != body {
            document?.body = body
            didChange = true
        }
        return flushFrontmatter(to: &document) || didChange
    }

    @discardableResult
    func flushFrontmatter(to document: inout BlogDocument?) -> Bool {
        guard let applyDraft = frontmatterProvider?(),
              var frontmatter = document?.frontmatter else {
            return false
        }
        let originalFrontmatter = frontmatter
        applyDraft(&frontmatter)
        guard frontmatter != originalFrontmatter else { return false }
        document?.frontmatter = frontmatter
        return true
    }

    private func scheduleBodyDirtyRecompute(
        currentDocument: @escaping @MainActor () -> BlogDocument?,
        setDirty: @escaping @MainActor (Bool) -> Void
    ) {
        bodyDirtyRecomputeTask?.cancel()
        bodyDirtyRecomputeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: DebounceTiming.documentEditNanoseconds)
            guard !Task.isCancelled, let self else { return }
            setDirty(self.isDirty(currentDocument: currentDocument()))
        }
    }

    private func cancelBodyDirtyRecompute() {
        bodyDirtyRecomputeTask?.cancel()
        bodyDirtyRecomputeTask = nil
    }

    private func cancelDirtyRecomputes() {
        cancelBodyDirtyRecompute()
    }

    private func comparableDocument(_ document: BlogDocument?) -> BlogDocument? {
        guard var document else { return nil }
        if let body = editorSession.currentBody() {
            document.body = body
        }
        if let applyDraft = frontmatterProvider?() {
            applyDraft(&document.frontmatter)
        }
        return document
    }
}
