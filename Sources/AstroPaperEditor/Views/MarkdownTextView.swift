import AppKit
import SwiftUI

struct MarkdownTextView: NSViewRepresentable {
    let documentID: String
    let text: String
    let targetLine: Int
    var onTextChange: () -> Void
    var onRegisterBodyProvider: (((() -> String?)?) -> Void)
    var onRegisterTopLineProvider: (((() -> Int?)?) -> Void)
    var onInsertImages: ([PastedImage]) -> String
    var onTogglePreview: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            documentID: documentID,
            onTextChange: onTextChange,
            onRegisterBodyProvider: onRegisterBodyProvider,
            onRegisterTopLineProvider: onRegisterTopLineProvider,
            onInsertImages: onInsertImages,
            onTogglePreview: onTogglePreview
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = PasteAwareTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.string = text
        textView.delegate = context.coordinator
        textView.pasteCoordinator = context.coordinator
        textView.registerForDraggedTypes([.fileURL, .tiff, .png])

        scrollView.documentView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.textView = textView
        context.coordinator.documentID = documentID
        context.coordinator.registerBodyProvider()
        context.coordinator.registerTopLineProvider()
        context.coordinator.restoreSourceLine(targetLine)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if context.coordinator.documentID != documentID {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selectedRange.location, text.count), length: 0))
            context.coordinator.documentID = documentID
            context.coordinator.registerBodyProvider()
            context.coordinator.registerTopLineProvider()
            context.coordinator.restoreSourceLine(targetLine)
        }
        context.coordinator.onTextChange = onTextChange
        context.coordinator.onRegisterBodyProvider = onRegisterBodyProvider
        context.coordinator.onRegisterTopLineProvider = onRegisterTopLineProvider
        context.coordinator.onInsertImages = onInsertImages
        context.coordinator.onTogglePreview = onTogglePreview
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.onRegisterBodyProvider(nil)
        coordinator.onRegisterTopLineProvider(nil)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var documentID: String
        var onTextChange: () -> Void
        var onRegisterBodyProvider: (((() -> String?)?) -> Void)
        var onRegisterTopLineProvider: (((() -> Int?)?) -> Void)
        var onInsertImages: ([PastedImage]) -> String
        var onTogglePreview: (() -> Void)?
        weak var scrollView: NSScrollView?
        weak var textView: NSTextView?

        init(
            documentID: String,
            onTextChange: @escaping () -> Void,
            onRegisterBodyProvider: @escaping (((() -> String?)?) -> Void),
            onRegisterTopLineProvider: @escaping (((() -> Int?)?) -> Void),
            onInsertImages: @escaping ([PastedImage]) -> String,
            onTogglePreview: (() -> Void)?
        ) {
            self.documentID = documentID
            self.onTextChange = onTextChange
            self.onRegisterBodyProvider = onRegisterBodyProvider
            self.onRegisterTopLineProvider = onRegisterTopLineProvider
            self.onInsertImages = onInsertImages
            self.onTogglePreview = onTogglePreview
        }

        func textDidChange(_ notification: Notification) {
            onTextChange()
        }

        func insertImages(from pasteboard: NSPasteboard) -> Bool {
            let images = PasteboardImageReader.images(from: pasteboard)
            guard !images.isEmpty else { return false }
            let markdown = onInsertImages(images)
            guard !markdown.isEmpty, let textView else { return true }
            textView.insertText(markdown, replacementRange: textView.selectedRange())
            onTextChange()
            return true
        }

        func togglePreview() {
            onTogglePreview?()
        }

        func registerBodyProvider() {
            onRegisterBodyProvider { [weak textView] in
                textView?.string
            }
        }

        func registerTopLineProvider() {
            onRegisterTopLineProvider { [weak scrollView, weak textView] in
                guard let scrollView, let textView else { return nil }
                return textView.sourceLine(at: scrollView.contentView.bounds.origin)
            }
        }

        func restoreSourceLine(_ line: Int) {
            DispatchQueue.main.async { [weak scrollView, weak textView] in
                guard let scrollView, let textView else { return }
                let point = textView.pointForSourceLine(line)
                scrollView.contentView.scroll(to: point)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
    }
}

private extension NSTextView {
    func sourceLine(at point: NSPoint) -> Int? {
        guard let layoutManager, let textContainer else { return nil }
        let containerPoint = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let prefix = (string as NSString).substring(to: min(characterIndex, string.count))
        return prefix.reduce(1) { count, character in
            character == "\n" ? count + 1 : count
        }
    }

    func pointForSourceLine(_ line: Int) -> NSPoint {
        guard let layoutManager else { return .zero }
        let targetLine = max(line, 1)
        var currentLine = 1
        var characterIndex = 0

        for character in string {
            if currentLine >= targetLine {
                break
            }
            characterIndex += 1
            if character == "\n" {
                currentLine += 1
            }
        }

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: min(characterIndex, string.count))
        let rect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        return NSPoint(x: 0, y: max(rect.minY + textContainerOrigin.y, 0))
    }
}

final class PasteAwareTextView: NSTextView {
    weak var pasteCoordinator: MarkdownTextView.Coordinator?

    override func paste(_ sender: Any?) {
        if pasteCoordinator?.insertImages(from: .general) == true {
            return
        }
        super.paste(sender)
    }

    override func keyDown(with event: NSEvent) {
        if isCommandE(event) {
            pasteCoordinator?.togglePreview()
            return
        }
        if performFindShortcut(event) {
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isCommandE(event) {
            pasteCoordinator?.togglePreview()
            return true
        }
        if performFindShortcut(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func isCommandE(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags == .command && event.charactersIgnoringModifiers?.lowercased() == "e"
    }

    private func performFindShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased()

        if flags == .command, key == "f" {
            performTextFinderAction(.showFindInterface)
            return true
        }

        if flags == .command, key == "g" {
            performTextFinderAction(.nextMatch)
            return true
        }

        if flags == [.command, .shift], key == "g" {
            performTextFinderAction(.previousMatch)
            return true
        }

        return false
    }

    private func performTextFinderAction(_ action: NSTextFinder.Action) {
        let sender = NSMenuItem()
        sender.tag = action.rawValue
        performTextFinderAction(sender)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        PasteboardImageReader.images(from: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        pasteCoordinator?.insertImages(from: sender.draggingPasteboard) == true
    }
}

enum PasteboardImageReader {
    static func images(from pasteboard: NSPasteboard) -> [PastedImage] {
        var images: [PastedImage] = []

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls where isImageFile(url) {
                if let data = try? Data(contentsOf: url) {
                    images.append(PastedImage(data: data, fileExtension: normalizedExtension(url.pathExtension)))
                }
            }
        }

        if !images.isEmpty {
            return images
        }

        if let png = pasteboard.data(forType: .png) {
            return [PastedImage(data: png, fileExtension: "png")]
        }

        if let tiff = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiff),
           let png = image.pngData {
            return [PastedImage(data: png, fileExtension: "png")]
        }

        if let nsImages = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = nsImages.first,
           let png = image.pngData {
            return [PastedImage(data: png, fileExtension: "png")]
        }

        return []
    }

    private static func isImageFile(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "gif", "tiff", "heic"].contains(url.pathExtension.lowercased())
    }

    private static func normalizedExtension(_ value: String) -> String {
        let lowercased = value.lowercased()
        return lowercased.isEmpty ? "png" : lowercased
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
