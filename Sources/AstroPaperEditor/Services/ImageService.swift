import AppKit
import Foundation

struct SavedImages {
    var markdown: String
    var assetPaths: [String]
}

struct ImageService {
    static let assetImagePrefix = "@/assets/images/"

    func save(images: [PastedImage], inProjectRoot projectRoot: URL) throws -> SavedImages {
        guard !images.isEmpty else { return SavedImages(markdown: "", assetPaths: []) }
        let imageDirectory = try assetImageDirectory(inProjectRoot: projectRoot)

        var markdownLines: [String] = []
        var assetPaths: [String] = []
        for image in images {
            let destination = nextImageURL(in: imageDirectory, fileExtension: image.fileExtension)
            try image.data.write(to: destination, options: .atomic)
            let base = destination.deletingPathExtension().lastPathComponent
            let assetPath = Self.assetImagePrefix + destination.lastPathComponent
            assetPaths.append(assetPath)
            markdownLines.append("![\(base)](\(assetPath))")
        }

        return SavedImages(markdown: markdownLines.joined(separator: "\n") + "\n", assetPaths: assetPaths)
    }

    func copyToAssets(from sourceURL: URL, inProjectRoot projectRoot: URL, suggestedName: String) throws -> String {
        let imageDirectory = try assetImageDirectory(inProjectRoot: projectRoot)
        let fileExtension = normalizedExtension(sourceURL.pathExtension)
        let destination = nextImageURL(in: imageDirectory, fileExtension: fileExtension, role: "og")
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return Self.assetImagePrefix + destination.lastPathComponent
    }

    private func assetImageDirectory(inProjectRoot projectRoot: URL) throws -> URL {
        let imageDirectory = projectRoot
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        return imageDirectory
    }

    private func nextImageURL(in directory: URL, fileExtension: String, role: String? = nil) -> URL {
        let day = DateFormatting.imageDate.string(from: Date())
        let prefix = [day, role].compactMap { $0 }.joined(separator: "-")
        for index in 1...999 {
            let filename = "\(prefix)-\(String(format: "%03d", index)).\(fileExtension)"
            let url = directory.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return directory.appendingPathComponent("\(prefix)-\(UUID().uuidString).\(fileExtension)")
    }

    private func normalizedExtension(_ value: String) -> String {
        let lowercased = value.lowercased()
        return lowercased.isEmpty ? "png" : lowercased
    }
}
