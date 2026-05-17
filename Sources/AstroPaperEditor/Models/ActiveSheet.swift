import Foundation

enum ActiveSheet: String, Identifiable {
    case newCategory
    case newDocument
    case move
    case commitPush
    case featuredDocuments

    var id: String { rawValue }
}
