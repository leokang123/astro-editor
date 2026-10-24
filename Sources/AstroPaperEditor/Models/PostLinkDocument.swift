import Foundation

struct PostLinkDocument: Identifiable, Encodable {
    let id: String
    let title: String
    let relativePath: String
    let slug: String?
}
