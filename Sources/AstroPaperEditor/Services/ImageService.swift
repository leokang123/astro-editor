import AppKit
import Foundation

struct ImageService {
    func save(images: [PastedImage], inProjectRoot projectRoot: URL) throws -> String {
        guard !images.isEmpty else { return "" }
        let imageDirectory = projectRoot
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
            .appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)

        var markdownLines: [String] = []
        for image in images {
            let destination = nextImageURL(in: imageDirectory, fileExtension: image.fileExtension)
            try image.data.write(to: destination, options: .atomic)
            let base = destination.deletingPathExtension().lastPathComponent
            markdownLines.append("![\(base)](@/assets/images/\(destination.lastPathComponent))")
        }

        return markdownLines.joined(separator: "\n") + "\n"
    }

    private func nextImageURL(in directory: URL, fileExtension: String) -> URL {
        let day = DateFormatting.imageDate.string(from: Date())
        for index in 1...999 {
            let filename = "\(day)-\(String(format: "%03d", index)).\(fileExtension)"
            let url = directory.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return directory.appendingPathComponent("\(day)-\(UUID().uuidString).\(fileExtension)")
    }
}
