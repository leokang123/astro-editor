import AppKit
import SwiftUI

struct MarkdownTextView: NSViewRepresentable {
    let documentID: String
    let text: String
    let targetSourcePosition: Double
    let isActive: Bool
    var onTextChange: () -> Void
    var onRegisterBodyProvider: (((() -> String?)?) -> Void)
    var onRegisterSourcePositionProvider: (((() -> Double?)?) -> Void)
    var onInsertImages: ([PastedImage]) -> String
    var onTogglePreview: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            documentID: documentID,
            onTextChange: onTextChange,
            onRegisterBodyProvider: onRegisterBodyProvider,
            onRegisterSourcePositionProvider: onRegisterSourcePositionProvider,
            onInsertImages: onInsertImages,
            onTogglePreview: onTogglePreview
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = EditorScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.findBarPosition = .aboveContent
        scrollView.isEditorActive = isActive

        let textView = PasteAwareTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = isActive
        textView.isSelectable = isActive
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.drawsBackground = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.string = text
        textView.applyMarkdownEditorStyle()
        textView.delegate = context.coordinator
        textView.pasteCoordinator = context.coordinator
        textView.registerForDraggedTypes([.fileURL, .tiff, .png])

        scrollView.documentView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.textView = textView
        context.coordinator.documentID = documentID
        context.coordinator.isActive = isActive
        context.coordinator.registerBodyProvider()
        context.coordinator.registerSourcePositionProvider()
        textView.undoManager?.removeAllActions()
        context.coordinator.restoreSourcePosition(targetSourcePosition, for: documentID)
        context.coordinator.clearFocus(for: documentID)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if context.coordinator.isActive && !isActive {
            context.coordinator.rememberSelection()
        }
        textView.isEditable = isActive
        textView.isSelectable = isActive
        (nsView as? EditorScrollView)?.isEditorActive = isActive
        if !isActive, textView.window?.firstResponder === textView {
            textView.window?.makeFirstResponder(nil)
        }

        if context.coordinator.documentID != documentID {
            textView.undoManager?.removeAllActions()
            textView.string = text
            textView.applyMarkdownEditorStyle()
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.undoManager?.removeAllActions()
            context.coordinator.resetDocument(id: documentID)
            context.coordinator.isActive = isActive
            context.coordinator.registerBodyProvider()
            context.coordinator.registerSourcePositionProvider()
            context.coordinator.restoreSourcePosition(targetSourcePosition, for: documentID)
            context.coordinator.clearFocus(for: documentID)
        } else if !context.coordinator.isActive && isActive {
            context.coordinator.restoreSourcePosition(targetSourcePosition, for: documentID)
            context.coordinator.restoreSelectionAndFocus(for: documentID)
        }
        context.coordinator.isActive = isActive
        context.coordinator.onTextChange = onTextChange
        context.coordinator.onRegisterBodyProvider = onRegisterBodyProvider
        context.coordinator.onRegisterSourcePositionProvider = onRegisterSourcePositionProvider
        context.coordinator.onInsertImages = onInsertImages
        context.coordinator.onTogglePreview = onTogglePreview
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.onRegisterBodyProvider(nil)
        coordinator.onRegisterSourcePositionProvider(nil)
        guard let textView = nsView.documentView as? PasteAwareTextView else { return }
        if textView.window?.firstResponder === textView {
            textView.window?.makeFirstResponder(nil)
        }
        textView.undoManager?.removeAllActions()
        textView.delegate = nil
        textView.pasteCoordinator = nil
        nsView.documentView = nil
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var documentID: String
        var onTextChange: () -> Void
        var onRegisterBodyProvider: (((() -> String?)?) -> Void)
        var onRegisterSourcePositionProvider: (((() -> Double?)?) -> Void)
        var onInsertImages: ([PastedImage]) -> String
        var onTogglePreview: (() -> Void)?
        var isActive = true
        var savedSelectedRange: NSRange?
        private let lineIndexCache = SourceLineIndexCache()
        weak var scrollView: NSScrollView?
        weak var textView: NSTextView?

        init(
            documentID: String,
            onTextChange: @escaping () -> Void,
            onRegisterBodyProvider: @escaping (((() -> String?)?) -> Void),
            onRegisterSourcePositionProvider: @escaping (((() -> Double?)?) -> Void),
            onInsertImages: @escaping ([PastedImage]) -> String,
            onTogglePreview: (() -> Void)?
        ) {
            self.documentID = documentID
            self.onTextChange = onTextChange
            self.onRegisterBodyProvider = onRegisterBodyProvider
            self.onRegisterSourcePositionProvider = onRegisterSourcePositionProvider
            self.onInsertImages = onInsertImages
            self.onTogglePreview = onTogglePreview
        }

        func textDidChange(_ notification: Notification) {
            lineIndexCache.invalidate()
            textView?.needsDisplay = true
            onTextChange()
        }

        func insertImages(from pasteboard: NSPasteboard) -> Bool {
            let images = PasteboardImageReader.images(from: pasteboard)
            guard !images.isEmpty else { return false }
            let markdown = onInsertImages(images)
            guard !markdown.isEmpty, let textView else { return true }
            textView.insertText(markdown, replacementRange: textView.selectedRange())
            lineIndexCache.invalidate()
            onTextChange()
            return true
        }

        func togglePreview() {
            onTogglePreview?()
        }

        func rememberSelection() {
            savedSelectedRange = textView?.selectedRange()
        }

        func resetDocument(id: String) {
            documentID = id
            savedSelectedRange = nil
            lineIndexCache.invalidate()
        }

        func restoreSelectionAndFocus(for documentID: String) {
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView, self.documentID == documentID else { return }
                let textLength = (textView.string as NSString).length
                let savedRange = self.savedSelectedRange ?? textView.selectedRange()
                let location = min(savedRange.location, textLength)
                let length = min(savedRange.length, max(textLength - location, 0))

                textView.setSelectedRange(NSRange(location: location, length: length))
                textView.window?.makeFirstResponder(textView)
            }
        }

        func clearFocus(for documentID: String) {
            DispatchQueue.main.async { [weak self, weak textView] in
                guard let self, let textView, self.documentID == documentID else { return }
                guard textView.window?.firstResponder === textView else { return }
                textView.window?.makeFirstResponder(nil)
            }
        }

        func registerBodyProvider() {
            onRegisterBodyProvider { [weak textView] in
                textView?.string
            }
        }

        func registerSourcePositionProvider() {
            onRegisterSourcePositionProvider { [weak self, weak scrollView, weak textView] in
                guard let self, let scrollView, let textView else { return nil }
                return textView.sourcePosition(at: scrollView.contentView.bounds.origin, lineIndexCache: self.lineIndexCache)
            }
        }

        func restoreSourcePosition(_ position: Double, for documentID: String) {
            DispatchQueue.main.async { [weak self, weak scrollView, weak textView] in
                guard let self, let scrollView, let textView, self.documentID == documentID else { return }
                let point = textView.pointForSourcePosition(position, lineIndexCache: self.lineIndexCache)
                scrollView.contentView.scroll(to: point)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }
    }
}

final class EditorScrollView: NSScrollView {
    var isEditorActive = true

    override func scrollWheel(with event: NSEvent) {
        guard isEditorActive else { return }
        super.scrollWheel(with: event)
    }
}

private extension NSTextView {
    func applyMarkdownEditorStyle() {
        let editorFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2

        font = editorFont
        textContainerInset = NSSize(width: 22, height: 18)
        defaultParagraphStyle = paragraphStyle

        var attributes = typingAttributes
        attributes[.font] = editorFont
        attributes[.paragraphStyle] = paragraphStyle
        attributes[.foregroundColor] = NSColor.labelColor
        typingAttributes = attributes

        needsDisplay = true
    }

    func sourcePosition(at point: NSPoint, lineIndexCache: SourceLineIndexCache) -> Double? {
        guard let layoutManager, let textContainer else { return nil }
        let containerPoint = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let nsString = string as NSString
        let sourceLine = lineIndexCache.lineNumber(containing: characterIndex, in: nsString)
        let currentY = yPositionForSourceLine(sourceLine, lineIndexCache: lineIndexCache)
        let nextY = yPositionForSourceLine(sourceLine + 1, lineIndexCache: lineIndexCache)
        guard nextY > currentY else {
            return Double(sourceLine)
        }

        let progress = min(max((point.y - currentY) / (nextY - currentY), 0), 1)
        return Double(sourceLine) + Double(progress)
    }

    func pointForSourcePosition(_ position: Double, lineIndexCache: SourceLineIndexCache) -> NSPoint {
        let targetPosition = max(position, 1)
        let targetLine = max(Int(floor(targetPosition)), 1)
        let progress = CGFloat(targetPosition - Double(targetLine))
        let currentY = yPositionForSourceLine(targetLine, lineIndexCache: lineIndexCache)
        let nextY = yPositionForSourceLine(targetLine + 1, lineIndexCache: lineIndexCache)
        let y = nextY > currentY ? currentY + (nextY - currentY) * progress : currentY
        return NSPoint(x: 0, y: max(y, 0))
    }

    private func yPositionForSourceLine(_ line: Int, lineIndexCache: SourceLineIndexCache) -> CGFloat {
        guard let layoutManager else { return 0 }
        let nsString = string as NSString
        guard nsString.length > 0 else { return 0 }
        let characterIndex = lineIndexCache.characterIndex(for: line, in: nsString)

        guard characterIndex < nsString.length else {
            let glyphCount = layoutManager.numberOfGlyphs
            guard glyphCount > 0 else { return 0 }
            let rect = layoutManager.lineFragmentRect(forGlyphAt: glyphCount - 1, effectiveRange: nil)
            return max(rect.maxY + textContainerOrigin.y, 0)
        }

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
        let rect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        return max(rect.minY + textContainerOrigin.y, 0)
    }
}

final class SourceLineIndexCache {
    private var cachedLength = -1
    private var cachedLineStarts = [0]

    func invalidate() {
        cachedLength = -1
        cachedLineStarts = [0]
    }

    func lineNumber(containing characterIndex: Int, in string: NSString) -> Int {
        let starts = lineStarts(in: string)
        let target = min(max(characterIndex, 0), string.length)
        var low = 0
        var high = starts.count - 1

        while low <= high {
            let mid = (low + high) / 2
            if starts[mid] <= target {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return max(high + 1, 1)
    }

    func characterIndex(for line: Int, in string: NSString) -> Int {
        let starts = lineStarts(in: string)
        let index = max(line, 1) - 1
        guard index < starts.count else { return string.length }
        return starts[index]
    }

    private func lineStarts(in string: NSString) -> [Int] {
        guard cachedLength != string.length else {
            return cachedLineStarts
        }

        var starts = [0]
        var index = 0
        while index < string.length {
            if string.character(at: index) == 10 {
                starts.append(index + 1)
            }
            index += 1
        }

        cachedLength = string.length
        cachedLineStarts = starts
        return starts
    }
}

final class PasteAwareTextView: NSTextView {
    weak var pasteCoordinator: MarkdownTextView.Coordinator?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty else { return }

        let placeholder = "Start writing Markdown..."
        let font = font ?? .monospacedSystemFont(ofSize: 14, weight: .regular)
        let padding = textContainer?.lineFragmentPadding ?? 0
        let point = NSPoint(
            x: textContainerOrigin.x + padding,
            y: textContainerOrigin.y
        )
        let rect = NSRect(
            x: point.x,
            y: point.y,
            width: max(bounds.width - point.x - textContainerInset.width, 0),
            height: font.ascender - font.descender + font.leading + 4
        )

        placeholder.draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: NSColor.placeholderTextColor,
            ]
        )
    }

    override func paste(_ sender: Any?) {
        if pasteCoordinator?.insertImages(from: .general) == true {
            return
        }
        super.paste(sender)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53,
           event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty,
           !hasMarkedText() {
            window?.makeFirstResponder(nil)
            return
        }

        if performEditorShortcut(event) {
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        performEditorShortcut(event) || super.performKeyEquivalent(with: event)
    }

    private func performEditorShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard flags.contains(.command),
              !flags.contains(.option),
              !flags.contains(.control),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }

        switch (key, flags.contains(.shift)) {
        case ("e", false):
            pasteCoordinator?.togglePreview()
        case ("z", false):
            undoManager?.undo()
        case ("z", true):
            undoManager?.redo()
        case ("x", false):
            cut(nil)
        case ("c", false):
            copy(nil)
        case ("v", false):
            paste(nil)
        case ("a", false):
            selectAll(nil)
        default:
            return false
        }

        return true
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
