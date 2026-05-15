import Foundation

struct BlogDocument: Identifiable, Equatable {
    var id: String { relativePath }
    var fileURL: URL
    var relativePath: String
    var frontmatter: Frontmatter
    var body: String
}
