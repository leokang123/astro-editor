import AppKit
import Foundation

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
