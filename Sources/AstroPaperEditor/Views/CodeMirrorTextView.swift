import AppKit
import SwiftUI
import WebKit

struct CodeMirrorTextView: NSViewRepresentable {
    let documentID: String
    let text: String
    let targetSourcePosition: Double
    let isActive: Bool
    let findQuery: String
    let findDirection: Int
    let findGeneration: Int
    let replaceText: String
    let replaceGeneration: Int
    let replaceAllGeneration: Int
    var onTextChange: () -> Void
    var onRegisterBodyProvider: (((() -> String?)?) -> Void)
    var onRegisterSourcePositionProvider: (((() -> Double?)?) -> Void)
    var onInsertImages: ([PastedImage]) -> String
    var onTogglePreview: (() -> Void)?
    var onFindRequested: (() -> Void)?
    var onFindStatusChange: ((Int, Int, Int?) -> Void)?
    var onEditorReady: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            documentID: documentID,
            text: text,
            sourcePosition: targetSourcePosition,
            onTextChange: onTextChange,
            onRegisterBodyProvider: onRegisterBodyProvider,
            onRegisterSourcePositionProvider: onRegisterSourcePositionProvider,
            onInsertImages: onInsertImages,
            onTogglePreview: onTogglePreview,
            onFindRequested: onFindRequested,
            onFindStatusChange: onFindStatusChange,
            onEditorReady: onEditorReady
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "editorReady")
        configuration.userContentController.add(context.coordinator, name: "textChanged")
        configuration.userContentController.add(context.coordinator, name: "sourcePosition")
        configuration.userContentController.add(context.coordinator, name: "togglePreview")
        configuration.userContentController.add(context.coordinator, name: "pasteImages")
        configuration.userContentController.add(context.coordinator, name: "findRequested")
        configuration.userContentController.add(context.coordinator, name: "findStatus")

        let webView = CodeMirrorWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        webView.editorCoordinator = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.registerProviders()
        context.coordinator.loadEditor(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onTextChange = onTextChange
        context.coordinator.onRegisterBodyProvider = onRegisterBodyProvider
        context.coordinator.onRegisterSourcePositionProvider = onRegisterSourcePositionProvider
        context.coordinator.onInsertImages = onInsertImages
        context.coordinator.onTogglePreview = onTogglePreview
        context.coordinator.onFindRequested = onFindRequested
        context.coordinator.onFindStatusChange = onFindStatusChange
        context.coordinator.onEditorReady = onEditorReady
        context.coordinator.update(
            documentID: documentID,
            text: text,
            sourcePosition: targetSourcePosition,
            isActive: isActive,
            findQuery: findQuery,
            findDirection: findDirection,
            findGeneration: findGeneration,
            replaceText: replaceText,
            replaceGeneration: replaceGeneration,
            replaceAllGeneration: replaceAllGeneration
        )
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.onRegisterBodyProvider(nil)
        coordinator.onRegisterSourcePositionProvider(nil)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "editorReady")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "textChanged")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "sourcePosition")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "togglePreview")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "pasteImages")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "findRequested")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "findStatus")
        (webView as? CodeMirrorWebView)?.editorCoordinator = nil
        webView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var documentID: String
        var cachedText: String
        var cachedSourcePosition: Double
        var onTextChange: () -> Void
        var onRegisterBodyProvider: (((() -> String?)?) -> Void)
        var onRegisterSourcePositionProvider: (((() -> Double?)?) -> Void)
        var onInsertImages: ([PastedImage]) -> String
        var onTogglePreview: (() -> Void)?
        var onFindRequested: (() -> Void)?
        var onFindStatusChange: ((Int, Int, Int?) -> Void)?
        var onEditorReady: () -> Void
        weak var webView: WKWebView?

        private var isLoaded = false
        private var isActive = true
        private var didSendDocument = false
        private var lastSwiftText: String
        private var lastFindQuery = ""
        private var lastFindGeneration = 0
        private var lastReplaceGeneration = 0
        private var lastReplaceAllGeneration = 0
        private var pendingDocument: DocumentPayload?

        init(
            documentID: String,
            text: String,
            sourcePosition: Double,
            onTextChange: @escaping () -> Void,
            onRegisterBodyProvider: @escaping (((() -> String?)?) -> Void),
            onRegisterSourcePositionProvider: @escaping (((() -> Double?)?) -> Void),
            onInsertImages: @escaping ([PastedImage]) -> String,
            onTogglePreview: (() -> Void)?,
            onFindRequested: (() -> Void)?,
            onFindStatusChange: ((Int, Int, Int?) -> Void)?,
            onEditorReady: @escaping () -> Void
        ) {
            self.documentID = documentID
            self.cachedText = text
            self.cachedSourcePosition = sourcePosition
            self.lastSwiftText = text
            self.onTextChange = onTextChange
            self.onRegisterBodyProvider = onRegisterBodyProvider
            self.onRegisterSourcePositionProvider = onRegisterSourcePositionProvider
            self.onInsertImages = onInsertImages
            self.onTogglePreview = onTogglePreview
            self.onFindRequested = onFindRequested
            self.onFindStatusChange = onFindStatusChange
            self.onEditorReady = onEditorReady
            self.isActive = true
        }

        func registerProviders() {
            onRegisterBodyProvider { [weak self] in
                self?.cachedText
            }
            onRegisterSourcePositionProvider { [weak self] in
                self?.cachedSourcePosition
            }
        }

        func loadEditor(in webView: WKWebView) {
            guard let htmlURL = codeMirrorResourceURL(file: "editor", extension: "html") else { return }
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }

        func update(
            documentID: String,
            text: String,
            sourcePosition: Double,
            isActive: Bool,
            findQuery: String,
            findDirection: Int,
            findGeneration: Int,
            replaceText: String,
            replaceGeneration: Int,
            replaceAllGeneration: Int
        ) {
            self.onRegisterBodyProvider { [weak self] in
                self?.cachedText
            }
            self.onRegisterSourcePositionProvider { [weak self] in
                self?.cachedSourcePosition
            }

            let changedDocument = self.documentID != documentID
            let changedActiveState = self.isActive != isActive
            let externalTextChanged = text != lastSwiftText && text != cachedText
            self.documentID = documentID
            self.isActive = isActive

            if changedDocument || externalTextChanged {
                cachedText = text
                lastSwiftText = text
            } else if text == cachedText {
                lastSwiftText = text
            }

            if !didSendDocument || changedDocument || externalTextChanged {
                didSendDocument = true
                sendDocument(DocumentPayload(documentID: documentID, text: cachedText, sourcePosition: sourcePosition, isActive: isActive))
            } else if changedActiveState {
                setActive(isActive)
                if isActive {
                    scrollToSourcePosition(sourcePosition)
                    DispatchQueue.main.async { [weak self] in
                        self?.onEditorReady()
                    }
                }
            }

            if lastFindQuery != findQuery {
                lastFindQuery = findQuery
                setFindQuery(findQuery)
            }
            if lastFindGeneration != findGeneration {
                lastFindGeneration = findGeneration
                find(findQuery: findQuery, direction: findDirection)
            }
            if lastReplaceGeneration != replaceGeneration {
                lastReplaceGeneration = replaceGeneration
                replaceCurrent(findQuery: findQuery, replacement: replaceText)
            }
            if lastReplaceAllGeneration != replaceAllGeneration {
                lastReplaceAllGeneration = replaceAllGeneration
                replaceAll(findQuery: findQuery, replacement: replaceText)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            if let pendingDocument {
                self.pendingDocument = nil
                sendDocument(pendingDocument)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "editorReady":
                onEditorReady()
            case "textChanged":
                let text: String?
                if let payload = message.body as? [String: Any] {
                    guard payload["documentID"] as? String == documentID else { return }
                    text = payload["text"] as? String
                } else {
                    text = message.body as? String
                }
                guard let text else { return }
                cachedText = text
                onTextChange()
            case "sourcePosition":
                if let position = message.body as? Double {
                    cachedSourcePosition = max(position, 1)
                } else if let number = message.body as? NSNumber {
                    cachedSourcePosition = max(number.doubleValue, 1)
                }
            case "togglePreview":
                onTogglePreview?()
            case "pasteImages":
                insertImages(from: .general)
            case "findRequested":
                onFindRequested?()
            case "findStatus":
                if let payload = message.body as? [String: Any] {
                    let current = (payload["current"] as? NSNumber)?.intValue ?? 0
                    let total = (payload["total"] as? NSNumber)?.intValue ?? 0
                    let replacementCount = payload["replacementCount"] as? NSNumber
                    onFindStatusChange?(current, total, replacementCount?.intValue)
                }
            default:
                break
            }
        }

        func insertImages(from pasteboard: NSPasteboard) {
            let images = PasteboardImageReader.images(from: pasteboard)
            guard !images.isEmpty else { return }
            let markdown = onInsertImages(images)
            guard !markdown.isEmpty else { return }
            evaluate("window.astroPaperEditor?.insertText(\(Self.jsonString(markdown)));")
        }

        private func sendDocument(_ payload: DocumentPayload) {
            guard isLoaded else {
                pendingDocument = payload
                return
            }
            evaluate("window.astroPaperEditor?.setDocument(\(Self.jsonObject(payload)));")
        }

        private func setActive(_ isActive: Bool) {
            guard isLoaded else { return }
            evaluate("window.astroPaperEditor?.setActive(\(isActive ? "true" : "false"));")
            if !isActive {
                clearFocus()
            }
        }

        private func scrollToSourcePosition(_ position: Double) {
            guard isLoaded else { return }
            evaluate("window.astroPaperEditor?.scrollToSourcePosition(\(position));")
        }

        private func setFindQuery(_ query: String) {
            guard isLoaded else { return }
            evaluate("window.astroPaperEditor?.setFindQuery(\(Self.jsonString(query)));")
        }

        private func find(findQuery: String, direction: Int) {
            guard isLoaded else { return }
            evaluate("window.astroPaperEditor?.find(\(Self.jsonString(findQuery)), \(direction < 0 ? "-1" : "1"));")
        }

        private func replaceCurrent(findQuery: String, replacement: String) {
            guard isLoaded else { return }
            evaluate("window.astroPaperEditor?.replaceCurrent(\(Self.jsonString(findQuery)), \(Self.jsonString(replacement)));")
        }

        private func replaceAll(findQuery: String, replacement: String) {
            guard isLoaded else { return }
            evaluate("window.astroPaperEditor?.replaceAll(\(Self.jsonString(findQuery)), \(Self.jsonString(replacement)));")
        }

        private func evaluate(_ script: String) {
            webView?.evaluateJavaScript(script)
        }

        private func clearFocus() {
            guard ownsFocus else { return }
            webView?.window?.makeFirstResponder(nil)
        }

        private var ownsFocus: Bool {
            guard let webView,
                  let firstResponder = webView.window?.firstResponder else {
                return false
            }
            if firstResponder === webView {
                return true
            }
            guard let firstResponderView = firstResponder as? NSView else {
                return false
            }
            return firstResponderView === webView || firstResponderView.isDescendant(of: webView)
        }

        private func codeMirrorResourceURL(file: String, extension fileExtension: String) -> URL? {
            if let bundledURL = Bundle.main.url(forResource: file, withExtension: fileExtension, subdirectory: "CodeMirror") {
                return bundledURL
            }
            let localURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources", isDirectory: true)
                .appendingPathComponent("CodeMirror", isDirectory: true)
                .appendingPathComponent("\(file).\(fileExtension)")
            return FileManager.default.fileExists(atPath: localURL.path) ? localURL : nil
        }

        private static func jsonObject<T: Encodable>(_ value: T) -> String {
            guard let data = try? JSONEncoder().encode(value),
                  let string = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return string
        }

        private static func jsonString(_ value: String) -> String {
            guard let data = try? JSONEncoder().encode(value),
                  let string = String(data: data, encoding: .utf8) else {
                return "\"\""
            }
            return string
        }
    }

    private struct DocumentPayload: Encodable {
        let documentID: String
        let text: String
        let sourcePosition: Double
        let isActive: Bool
    }
}

final class CodeMirrorWebView: WKWebView {
    weak var editorCoordinator: CodeMirrorTextView.Coordinator?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        PasteboardImageReader.images(from: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        editorCoordinator?.insertImages(from: sender.draggingPasteboard)
        return true
    }
}
