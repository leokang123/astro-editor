import AppKit
import Foundation

enum ImageCache {
    static func image(at url: URL?) -> NSImage? {
        guard let url else { return nil }
        let key = cacheKey(for: url)
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    private static func cacheKey(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return [
            url.standardizedFileURL.path,
            String(values?.contentModificationDate?.timeIntervalSince1970 ?? 0),
            String(values?.fileSize ?? 0),
        ].joined(separator: "|")
    }

    private static let cache = NSCache<NSString, NSImage>()
}
