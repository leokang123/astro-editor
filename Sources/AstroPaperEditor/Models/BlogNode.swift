import Foundation

enum BlogNodeKind: String, Codable {
    case category
    case document
}

struct BlogNode: Identifiable, Hashable {
    let id: String
    var name: String
    var relativePath: String
    var url: URL
    var kind: BlogNodeKind
    var children: [BlogNode]

    var isDocument: Bool {
        kind == .document
    }

    var outlineChildren: [BlogNode]? {
        children.isEmpty ? nil : children
    }

    var systemImage: String {
        switch kind {
        case .category:
            return "folder"
        case .document:
            return "doc.text"
        }
    }
}

struct CategoryDestination: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL
    let relativePath: String
}
