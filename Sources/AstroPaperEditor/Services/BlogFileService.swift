import AppKit
import Foundation

struct BlogFileService {
    static let defaultProjectRoot = URL(fileURLWithPath: "/Users/jeonghoon/Desktop/공부목록/blog", isDirectory: true)

    func blogRoot(for projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("data", isDirectory: true)
            .appendingPathComponent("blog", isDirectory: true)
    }

    func validateProjectRoot(_ projectRoot: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let root = blogRoot(for: projectRoot)
        return FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func scan(projectRoot: URL) throws -> [BlogNode] {
        let root = blogRoot(for: projectRoot)
        return try scanDirectory(root, blogRoot: root)
    }

    func readDocument(at url: URL, blogRoot: URL) throws -> BlogDocument {
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let relativePath = Self.relativePath(from: blogRoot, to: url)
        let fallbackTitle = url.deletingPathExtension().lastPathComponent
        let parsed = Frontmatter.parse(from: markdown, fallbackTitle: fallbackTitle)
        return BlogDocument(
            fileURL: url,
            relativePath: relativePath,
            frontmatter: parsed.0,
            body: parsed.1
        )
    }

    func writeDocument(_ document: BlogDocument) throws {
        let text = document.frontmatter.rendered() + "\n\n" + document.body.trimmingLeadingNewlines()
        try text.write(to: document.fileURL, atomically: true, encoding: .utf8)
    }

    func createCategory(named name: String, under parent: URL) throws -> URL {
        let target = parent.appendingPathComponent(name.astropaperSafePathComponent, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw BlogFileError.alreadyExists(target.lastPathComponent)
        }
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        return target
    }

    func createDocument(
        title: String,
        description: String,
        tags: [String],
        order: String?,
        featured: Bool?,
        ogImage: String?,
        under parent: URL
    ) throws -> URL {
        let filename = title.astropaperSafePathComponent + ".md"
        let target = parent.appendingPathComponent(filename, isDirectory: false)
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw BlogFileError.alreadyExists(filename)
        }

        let frontmatter = Frontmatter.new(
            title: title,
            description: description,
            tags: tags,
            order: order,
            featured: featured,
            ogImage: ogImage
        )
        let body = "# \(title)\n"
        let document = BlogDocument(
            fileURL: target,
            relativePath: "",
            frontmatter: frontmatter,
            body: body
        )
        try writeDocument(document)
        return target
    }

    func rename(node: BlogNode, to rawName: String) throws -> URL {
        let safe = rawName.astropaperSafePathComponent
        let destinationName = node.kind == .document && !safe.hasSuffix(".md") ? safe + ".md" : safe
        let destination = node.url.deletingLastPathComponent().appendingPathComponent(destinationName)
        guard destination != node.url else { return destination }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw BlogFileError.alreadyExists(destinationName)
        }
        try FileManager.default.moveItem(at: node.url, to: destination)
        return destination
    }

    func move(node: BlogNode, to destinationCategory: URL) throws -> URL {
        let destination = destinationCategory.appendingPathComponent(node.url.lastPathComponent)
        guard destination != node.url else { return destination }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw BlogFileError.alreadyExists(destination.lastPathComponent)
        }
        try FileManager.default.moveItem(at: node.url, to: destination)
        return destination
    }

    func trash(node: BlogNode) throws {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: node.url, resultingItemURL: &resultingURL)
    }

    static func relativePath(from root: URL, to url: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let urlPath = url.standardizedFileURL.path
        guard urlPath.hasPrefix(rootPath) else { return url.lastPathComponent }
        let start = urlPath.index(urlPath.startIndex, offsetBy: rootPath.count)
        return String(urlPath[start...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func scanDirectory(_ directory: URL, blogRoot: URL) throws -> [BlogNode] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let sorted = contents.sorted { lhs, rhs in
            let lhsIsDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let rhsIsDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if lhsIsDirectory != rhsIsDirectory { return lhsIsDirectory }
            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }

        return try sorted.compactMap { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            let relativePath = Self.relativePath(from: blogRoot, to: url)
            if values.isDirectory == true {
                guard url.lastPathComponent != "images" else { return nil }
                return BlogNode(
                    id: BlogNodeID.make(kind: .category, relativePath: relativePath),
                    name: url.lastPathComponent,
                    relativePath: relativePath,
                    url: url,
                    kind: .category,
                    children: try scanDirectory(url, blogRoot: blogRoot)
                )
            }

            guard url.pathExtension.lowercased() == "md" else { return nil }
            return BlogNode(
                id: BlogNodeID.make(kind: .document, relativePath: relativePath),
                name: url.deletingPathExtension().lastPathComponent,
                relativePath: relativePath,
                url: url,
                kind: .document,
                children: []
            )
        }
    }
}

enum BlogFileError: LocalizedError {
    case alreadyExists(String)
    case missingBlogRoot
    case invalidMove

    var errorDescription: String? {
        switch self {
        case .alreadyExists(let name):
            return "'\(name)' already exists."
        case .missingBlogRoot:
            return "src/data/blog folder was not found."
        case .invalidMove:
            return "That item cannot be moved there."
        }
    }
}

enum BlogNodeID {
    static let root = "category:"

    static func make(kind: BlogNodeKind, relativePath: String) -> String {
        "\(kind.rawValue):\(relativePath)"
    }

    static func kind(from id: String) -> BlogNodeKind? {
        if id.hasPrefix("category:") { return .category }
        if id.hasPrefix("document:") { return .document }
        return nil
    }

    static func relativePath(from id: String) -> String {
        guard let colon = id.firstIndex(of: ":") else { return id }
        return String(id[id.index(after: colon)...])
    }
}

private extension String {
    func trimmingLeadingNewlines() -> String {
        var text = self
        while text.hasPrefix("\n") {
            text.removeFirst()
        }
        return text
    }
}
