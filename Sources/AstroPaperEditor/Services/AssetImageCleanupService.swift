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
        let imageNames = Set(imageURLs.map(\.lastPathComponent))
        let usedImageNames = try referencedImageNames(projectRoot: projectRoot, imageNames: imageNames)

        let unused = imageURLs.filter { url in
            !usedImageNames.contains(url.lastPathComponent)
        }

        return AssetImageCleanupPreview(
            allImageCount: imageURLs.count,
            unusedImages: unused.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        )
    }

    func moveImagesToTrash(_ imageURLs: [URL]) throws -> AssetImageCleanupResult {
        var trashed: [URL] = []

        for imageURL in imageURLs {
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

    private func referencedImageNames(projectRoot: URL, imageNames: Set<String>) throws -> Set<String> {
        guard !imageNames.isEmpty else { return [] }

        let sourceFiles = try searchableSourceFiles(projectRoot: projectRoot)
        var used: Set<String> = []

        for url in sourceFiles {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for reference in imageReferences(in: text) {
                guard let imageName = imageFilename(from: reference),
                      imageNames.contains(imageName) else {
                    continue
                }
                used.insert(imageName)
            }
        }

        return used
    }

    private func imageReferences(in text: String) -> [String] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return Self.imageReferenceRegex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let captureRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[captureRange])
        }
    }

    private func imageFilename(from reference: String) -> String? {
        let cleaned = reference
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'()"))
        guard !cleaned.isEmpty else { return nil }

        let url = URL(fileURLWithPath: cleaned)
        let filename = url.lastPathComponent
        guard isImageExtension(url.pathExtension), !filename.isEmpty else { return nil }
        return filename
    }

    private func searchableSourceFiles(projectRoot: URL) throws -> [URL] {
        var files: [URL] = []
        let directories = [
            projectRoot.appendingPathComponent("src/data/blog", isDirectory: true),
            projectRoot.appendingPathComponent("src/pages", isDirectory: true),
            projectRoot.appendingPathComponent("src/components", isDirectory: true),
            projectRoot.appendingPathComponent("src/layouts", isDirectory: true)
        ]
        let standaloneFiles = [
            projectRoot.appendingPathComponent("src/user-settings.json"),
            projectRoot.appendingPathComponent("src/config.ts"),
            projectRoot.appendingPathComponent("src/constants.ts")
        ]

        for directory in directories where FileManager.default.fileExists(atPath: directory.path) {
            try collectSourceFiles(from: directory, files: &files)
        }

        for file in standaloneFiles where FileManager.default.fileExists(atPath: file.path) && isSearchableTextExtension(file.pathExtension) {
            files.append(file)
        }

        return files
    }

    private func collectSourceFiles(from directory: URL, files: inout [URL]) throws {
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
                try collectSourceFiles(from: url, files: &files)
            } else if values.isRegularFile == true, isSearchableTextExtension(url.pathExtension) {
                files.append(url)
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

    private static let imageReferenceRegex = try! NSRegularExpression(
        pattern: #"@/assets/images/([^\s"')\]}>,]+)"#,
        options: [.caseInsensitive]
    )
}
