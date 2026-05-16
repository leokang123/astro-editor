import Foundation

struct AssetImageCleanupPreview {
    var allImageCount: Int
    var unusedImages: [URL]

    var unusedCount: Int {
        unusedImages.count
    }
}

struct AssetImageCleanupResult {
    var trashedImages: [URL]
}

struct AssetImageCleanupService {
    func preview(projectRoot: URL) throws -> AssetImageCleanupPreview {
        let imageDirectory = assetImageDirectory(inProjectRoot: projectRoot)
        let imageURLs = try imageFiles(in: imageDirectory)
        let sourceText = try searchableSourceText(projectRoot: projectRoot)

        let unused = imageURLs.filter { url in
            !sourceText.contains(url.lastPathComponent)
        }

        return AssetImageCleanupPreview(
            allImageCount: imageURLs.count,
            unusedImages: unused.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        )
    }

    func moveUnusedImagesToTrash(projectRoot: URL) throws -> AssetImageCleanupResult {
        let preview = try preview(projectRoot: projectRoot)
        var trashed: [URL] = []

        for imageURL in preview.unusedImages {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: imageURL, resultingItemURL: &resultingURL)
            trashed.append(imageURL)
        }

        return AssetImageCleanupResult(trashedImages: trashed)
    }

    private func assetImageDirectory(inProjectRoot projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("images", isDirectory: true)
    }

    private func imageFiles(in directory: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            isImageExtension(url.pathExtension)
        }
    }

    private func searchableSourceText(projectRoot: URL) throws -> String {
        let roots = [
            projectRoot.appendingPathComponent("src", isDirectory: true),
            projectRoot.appendingPathComponent("public", isDirectory: true)
        ]

        var chunks: [String] = []
        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            try collectSourceText(from: root, chunks: &chunks)
        }
        return chunks.joined(separator: "\n")
    }

    private func collectSourceText(from directory: URL, chunks: inout [String]) throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        for url in contents {
            if url.pathComponents.suffix(3) == ["src", "assets", "images"] {
                continue
            }

            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true {
                try collectSourceText(from: url, chunks: &chunks)
            } else if values.isRegularFile == true, isSearchableTextExtension(url.pathExtension) {
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    chunks.append(text)
                }
            }
        }
    }

    private func isImageExtension(_ value: String) -> Bool {
        ["png", "jpg", "jpeg", "gif", "webp", "svg", "avif", "heic", "tiff"].contains(value.lowercased())
    }

    private func isSearchableTextExtension(_ value: String) -> Bool {
        [
            "md", "mdx", "astro", "ts", "tsx", "js", "jsx", "json", "css", "scss",
            "yaml", "yml", "toml", "html"
        ].contains(value.lowercased())
    }
}
