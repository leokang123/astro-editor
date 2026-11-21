import Foundation
import Yams

enum FrontmatterValidation {
    static func validate(_ markdown: String, path: String) throws {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        guard lines.first == "---" else { return }
        guard let end = lines.dropFirst().firstIndex(of: "---") else {
            throw Failure(message: "\(path): Missing closing --- in frontmatter.")
        }
        do {
            // Keep the opening delimiter's line so parser line numbers match the file.
            let yaml = ([""] + Array(lines[1..<end])).joined(separator: "\n")
            guard let node = try Yams.compose(yaml: yaml), node.mapping != nil else {
                throw Failure(message: "Frontmatter must contain YAML key/value fields.")
            }
        } catch {
            throw Failure(message: "\(path)\n\n\(error)\n\nFix Post Details or Additional YAML fields before saving or pushing.")
        }
    }

    static func validateProject(at root: URL) throws {
        let blog = root.appendingPathComponent("src/data/blog")
        guard let files = FileManager.default.enumerator(at: blog, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in files where ["md", "mdx"].contains(url.pathExtension.lowercased()) {
            try validate(String(contentsOf: url, encoding: .utf8), path: url.path)
        }
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}
