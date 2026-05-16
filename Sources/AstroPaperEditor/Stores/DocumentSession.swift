import Foundation

@MainActor
final class DocumentSession {
    private let editorSession = EditorSession()
    private var savedDocumentSnapshot: BlogDocument?
    private var bodyDirtyRecomputeTask: Task<Void, Never>?

    var topLine: Int {
        editorSession.topLine
    }

    func setBodyProvider(_ provider: (() -> String?)?) {
        editorSession.setBodyProvider(provider)
    }

    func setTopLineProvider(_ provider: (() -> Int?)?) {
        editorSession.setTopLineProvider(provider)
    }

    func updateTopLine(_ line: Int) {
        editorSession.updateTopLine(line)
    }

    func captureTopLine() {
        editorSession.captureTopLine()
    }

    func open(_ document: BlogDocument) {
        savedDocumentSnapshot = document
        cancelBodyDirtyRecompute()
        editorSession.reset()
    }

    func close() {
        savedDocumentSnapshot = nil
        cancelBodyDirtyRecompute()
        editorSession.reset()
    }

    func markSaved(_ document: BlogDocument) {
        savedDocumentSnapshot = document
        cancelBodyDirtyRecompute()
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

    func isDirty(currentDocument: BlogDocument?) -> Bool {
        guard let savedDocumentSnapshot else {
            return currentDocument != nil
        }
        return comparableDocument(currentDocument) != savedDocumentSnapshot
    }

    func discardEditorChanges(markClean: Bool) -> BlogDocument? {
        editorSession.discardBodyProvider()
        guard markClean else { return nil }
        cancelBodyDirtyRecompute()
        return savedDocumentSnapshot
    }

    func updateSavedDocumentLocation(to newURL: URL, relativePath: String) {
        savedDocumentSnapshot?.fileURL = newURL
        savedDocumentSnapshot?.relativePath = relativePath
    }

    @discardableResult
    func flushEditorBody(to document: inout BlogDocument?) -> Bool {
        guard let body = editorSession.currentBody(), document?.body != body else {
            return false
        }
        document?.body = body
        return true
    }

    private func scheduleBodyDirtyRecompute(
        currentDocument: @escaping @MainActor () -> BlogDocument?,
        setDirty: @escaping @MainActor (Bool) -> Void
    ) {
        bodyDirtyRecomputeTask?.cancel()
        bodyDirtyRecomputeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, let self else { return }
            setDirty(self.isDirty(currentDocument: currentDocument()))
        }
    }

    private func cancelBodyDirtyRecompute() {
        bodyDirtyRecomputeTask?.cancel()
        bodyDirtyRecomputeTask = nil
    }

    private func comparableDocument(_ document: BlogDocument?) -> BlogDocument? {
        guard var document else { return nil }
        if let body = editorSession.currentBody() {
            document.body = body
        }
        return document
    }
}
