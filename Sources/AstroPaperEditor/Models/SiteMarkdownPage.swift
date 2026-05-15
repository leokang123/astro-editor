import Foundation

struct SiteMarkdownPage {
    var frontmatter: String
    var body: String

    static func parse(_ markdown: String) -> SiteMarkdownPage {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else {
            return SiteMarkdownPage(frontmatter: "", body: normalized)
        }

        let searchStart = normalized.index(normalized.startIndex, offsetBy: 4)
        guard let closeRange = normalized.range(of: "\n---", range: searchStart..<normalized.endIndex) else {
            return SiteMarkdownPage(frontmatter: "", body: normalized)
        }

        var bodyStart = closeRange.upperBound
        if bodyStart < normalized.endIndex, normalized[bodyStart] == "\n" {
            bodyStart = normalized.index(after: bodyStart)
        }

        return SiteMarkdownPage(
            frontmatter: String(normalized[normalized.startIndex..<closeRange.upperBound]),
            body: String(normalized[bodyStart...])
        )
    }

    func rendered() -> String {
        guard !frontmatter.isEmpty else { return body }
        return frontmatter + "\n\n" + body.trimmingLeadingNewlines()
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
