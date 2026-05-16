import Foundation

enum BlogNodeKind: String {
    case category
    case document
}

struct BlogNode: Identifiable {
    let id: String
    var name: String
    var relativePath: String
    var url: URL
    var kind: BlogNodeKind
    var children: [BlogNode]

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

struct CategoryDestination: Identifiable {
    let id: String
    let title: String
    let url: URL
}
