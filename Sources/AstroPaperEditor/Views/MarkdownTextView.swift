import AppKit
import SwiftUI

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var onInsertImages: ([PastedImage]) -> String
    var onTogglePreview: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onInsertImages: onInsertImages, onTogglePreview: onTogglePreview)
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
        textView.delegate = context.coordinator
        textView.pasteCoordinator = context.coordinator
        textView.registerForDraggedTypes([.fileURL, .tiff, .png])

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selectedRange.location, text.count), length: 0))
        }
        context.coordinator.onInsertImages = onInsertImages
        context.coordinator.onTogglePreview = onTogglePreview
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onInsertImages: ([PastedImage]) -> String
        var onTogglePreview: (() -> Void)?
        weak var textView: NSTextView?

        init(text: Binding<String>, onInsertImages: @escaping ([PastedImage]) -> String, onTogglePreview: (() -> Void)?) {
            _text = text
            self.onInsertImages = onInsertImages
            self.onTogglePreview = onTogglePreview
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }

        func insertImages(from pasteboard: NSPasteboard) -> Bool {
            let images = PasteboardImageReader.images(from: pasteboard)
            guard !images.isEmpty else { return false }
            let markdown = onInsertImages(images)
            guard !markdown.isEmpty, let textView else { return true }
            textView.insertText(markdown, replacementRange: textView.selectedRange())
            text = textView.string
            return true
        }

        func togglePreview() {
            onTogglePreview?()
        }
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
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isCommandE(event) {
            pasteCoordinator?.togglePreview()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func isCommandE(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags == .command && event.charactersIgnoringModifiers?.lowercased() == "e"
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
