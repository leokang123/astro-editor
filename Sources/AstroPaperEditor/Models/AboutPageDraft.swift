import Foundation

struct AboutPageDraft: Equatable {
    var frontmatter: String
    var body: String

    init(frontmatter: String = "", body: String = "") {
        self.frontmatter = frontmatter
        self.body = body
    }

    init(page: SiteMarkdownPage) {
        self.init(frontmatter: page.frontmatter, body: page.body)
    }

    var page: SiteMarkdownPage {
        SiteMarkdownPage(frontmatter: frontmatter, body: body)
    }

    var profileImageSource: String? {
        AboutPageFrontmatter.stringValue(for: "profileImage", in: frontmatter)
            ?? AboutProfileImageMarkup.firstImageSource(in: body)
    }

    mutating func replaceProfileImage(with publicPath: String, defaultAlt: String) {
        frontmatter = AboutPageFrontmatter.upsertingStringValue(for: "profileImage", value: publicPath, in: frontmatter)
        if AboutPageFrontmatter.stringValue(for: "profileImageAlt", in: frontmatter) == nil {
            frontmatter = AboutPageFrontmatter.upsertingStringValue(for: "profileImageAlt", value: defaultAlt, in: frontmatter)
        }
        body = AboutProfileImageMarkup.removingFirstImage(in: body)
    }
}

enum AboutPageFrontmatter {
    static func stringValue(for key: String, in frontmatter: String) -> String? {
        guard let valueRange = stringValueRange(for: key, in: frontmatter) else { return nil }
        return String(frontmatter[valueRange])
    }

    static func upsertingStringValue(for key: String, value: String, in frontmatter: String) -> String {
        if let valueRange = stringValueRange(for: key, in: frontmatter) {
            var updated = frontmatter
            updated.replaceSubrange(valueRange, with: escaped(value))
            return updated
        }

        guard frontmatter.hasPrefix("---") else {
            return """
            ---
            \(key): "\(escaped(value))"
            ---
            """
        }

        let line = "\(key): \"\(escaped(value))\"\n"
        var updated = frontmatter
        if let closeRange = updated.range(of: "\n---", options: .backwards) {
            updated.insert(contentsOf: line, at: updated.index(after: closeRange.lowerBound))
        } else {
            updated.append("\n\(line)---")
        }
        return updated
    }

    private static func stringValueRange(for key: String, in frontmatter: String) -> Range<String.Index>? {
        guard let regex = try? NSRegularExpression(pattern: #"(?m)^(\#(key)\s*:\s*['"])([^'"]*)(['"]\s*)$"#) else {
            return nil
        }
        let nsRange = NSRange(frontmatter.startIndex..<frontmatter.endIndex, in: frontmatter)
        guard let match = regex.firstMatch(in: frontmatter, range: nsRange),
              let range = Range(match.range(at: 2), in: frontmatter) else {
            return nil
        }
        return range
    }

    private static func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

enum AboutProfileImageMarkup {
    static func firstImageSource(in markdown: String) -> String? {
        guard let range = firstImageSourceRange(in: markdown) else { return nil }
        return String(markdown[range])
    }

    static func removingFirstImage(in markdown: String) -> String {
        guard let range = firstImageRange(in: markdown) else { return markdown }
        var updated = markdown
        updated.removeSubrange(range)
        return updated.trimmingLeadingNewlines()
    }

    private static func firstImageSourceRange(in markdown: String) -> Range<String.Index>? {
        if let range = capturedRange(pattern: #"(?is)<img\b[^>]*\bsrc\s*=\s*(['"])(.*?)\1[^>]*>"#, group: 2, in: markdown) {
            return range
        }
        return capturedRange(pattern: #"!\[[^\]]*\]\(([^)]+)\)"#, group: 1, in: markdown)
    }

    private static func firstImageRange(in markdown: String) -> Range<String.Index>? {
        if let range = capturedRange(pattern: #"(?is)<img\b[^>]*>\s*"#, group: 0, in: markdown) {
            return range
        }
        return capturedRange(pattern: #"(?m)^\s*!\[[^\]]*\]\([^)]+\)\s*\n*"#, group: 0, in: markdown)
    }

    private static func capturedRange(pattern: String, group: Int, in text: String) -> Range<String.Index>? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              group < match.numberOfRanges,
              let range = Range(match.range(at: group), in: text) else {
            return nil
        }
        return range
    }
}
