import AppKit
import Foundation

struct BlogFileService {
    static let defaultProjectRoot = FileManager.default.homeDirectoryForCurrentUser

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

    func scan(projectRoot: URL, sortOption: SidebarSortOption) throws -> [BlogNode] {
        let root = blogRoot(for: projectRoot)
        return try scanDirectory(root, blogRoot: root, sortOption: sortOption)
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

    func readFrontmatter(at url: URL) throws -> Frontmatter {
        let fallbackTitle = url.deletingPathExtension().lastPathComponent
        let markdown = try frontmatterPrefix(at: url)
        return Frontmatter.parseFrontmatter(from: markdown, fallbackTitle: fallbackTitle)
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
        let document = BlogDocument(
            fileURL: target,
            relativePath: "",
            frontmatter: frontmatter,
            body: ""
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

    private func scanDirectory(_ directory: URL, blogRoot: URL, sortOption: SidebarSortOption) throws -> [BlogNode] {
        let entries = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ).map { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .creationDateKey])
            return (
                url: url,
                isDirectory: values?.isDirectory ?? false,
                modifiedDate: values?.contentModificationDate,
                creationDate: values?.creationDate
            )
        }

        let sorted = entries.sorted { lhs, rhs in
            let lhsIsDirectory = lhs.isDirectory
            let rhsIsDirectory = rhs.isDirectory
            if lhsIsDirectory != rhsIsDirectory { return lhsIsDirectory }
            return isSorted(lhs, before: rhs, by: sortOption)
        }

        return try sorted.compactMap { entry in
            let url = entry.url
            let relativePath = Self.relativePath(from: blogRoot, to: url)
            if entry.isDirectory {
                guard url.lastPathComponent != "images" else { return nil }
                return BlogNode(
                    id: BlogNodeID.make(kind: .category, relativePath: relativePath),
                    name: url.lastPathComponent,
                    relativePath: relativePath,
                    url: url,
                    kind: .category,
                    children: try scanDirectory(url, blogRoot: blogRoot, sortOption: sortOption)
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

    private func isSorted(
        _ lhs: (url: URL, isDirectory: Bool, modifiedDate: Date?, creationDate: Date?),
        before rhs: (url: URL, isDirectory: Bool, modifiedDate: Date?, creationDate: Date?),
        by sortOption: SidebarSortOption
    ) -> Bool {
        switch sortOption {
        case .fileName:
            return isNameSorted(lhs.url, before: rhs.url)
        case .newestModified:
            return isDateSorted(lhs.modifiedDate, before: rhs.modifiedDate, newestFirst: true)
                ?? isNameSorted(lhs.url, before: rhs.url)
        case .oldestModified:
            return isDateSorted(lhs.modifiedDate, before: rhs.modifiedDate, newestFirst: false)
                ?? isNameSorted(lhs.url, before: rhs.url)
        case .createdDate:
            return isDateSorted(lhs.creationDate, before: rhs.creationDate, newestFirst: false)
                ?? isNameSorted(lhs.url, before: rhs.url)
        }
    }

    private func isNameSorted(_ lhs: URL, before rhs: URL) -> Bool {
        lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
    }

    private func isDateSorted(_ lhs: Date?, before rhs: Date?, newestFirst: Bool) -> Bool? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            guard lhs != rhs else { return nil }
            return newestFirst ? lhs > rhs : lhs < rhs
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            return nil
        }
    }

    private func frontmatterPrefix(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let marker = Data("\n---".utf8)
        let frontmatterStart = Data("---\n".utf8)
        var data = Data()

        while let chunk = try handle.read(upToCount: 4_096), !chunk.isEmpty {
            data.append(chunk)

            if data.count >= frontmatterStart.count, data.prefix(frontmatterStart.count) != frontmatterStart {
                break
            }

            if data.count > frontmatterStart.count,
               let closeRange = data.range(
                of: marker,
                options: [],
                in: data.index(data.startIndex, offsetBy: frontmatterStart.count)..<data.endIndex
               ) {
                data = data.subdata(in: data.startIndex..<closeRange.upperBound)
                break
            }

            if data.count > 1_048_576 {
                break
            }
        }

        return String(data: data, encoding: .utf8) ?? ""
    }
}

enum BlogFileError: LocalizedError {
    case alreadyExists(String)
    case invalidMove

    var errorDescription: String? {
        switch self {
        case .alreadyExists(let name):
            return "'\(name)' already exists."
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
}
