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

    func copyAboutProfileImage(from sourceURL: URL, inProjectRoot projectRoot: URL) throws -> String {
        let fileExtension = normalizedExtension(sourceURL.pathExtension)
        let filename = "about-profile.\(fileExtension)"
        let destination = try copyReplacingPublicFile(named: filename, from: sourceURL, inProjectRoot: projectRoot)

        return "/" + destination.lastPathComponent
    }

    func replacePublicFile(named filename: String, from sourceURL: URL, inProjectRoot projectRoot: URL) throws {
        _ = try copyReplacingPublicFile(named: filename, from: sourceURL, inProjectRoot: projectRoot)
    }

    private func copyReplacingPublicFile(named filename: String, from sourceURL: URL, inProjectRoot projectRoot: URL) throws -> URL {
        let publicDirectory = projectRoot.appendingPathComponent("public", isDirectory: true)
        try FileManager.default.createDirectory(at: publicDirectory, withIntermediateDirectories: true)

        let destination = publicDirectory.appendingPathComponent(filename)
        if sourceURL.standardizedFileURL.path != destination.standardizedFileURL.path {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        }
        return destination
    }

    func stageTemporaryFile(from sourceURL: URL, filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AstroPaperEditorStagedImages", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let destination = directory.appendingPathComponent("\(UUID().uuidString)-\(filename)")
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
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
