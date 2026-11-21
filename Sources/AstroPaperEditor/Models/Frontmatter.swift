import Foundation
import Yams

struct Frontmatter: Equatable {
    var title: String
    var order: String?
    var pubDatetime: String
    var modDatetime: String
    var description: String
    var featured: Bool?
    var ogImage: String?
    var tags: [String]
    var extraLines: [String]

    static func new(
        title: String,
        description: String,
        tags: [String],
        order: String? = nil,
        featured: Bool? = nil,
        ogImage: String? = nil,
        now: Date = Date()
    ) -> Frontmatter {
        let timestamp = DateFormatting.astropaperTimestamp.string(from: now)
        return Frontmatter(
            title: title,
            order: normalizedOrder(order),
            pubDatetime: timestamp,
            modDatetime: timestamp,
            description: description,
            featured: featured,
            ogImage: normalizedOptionalScalar(ogImage),
            tags: tags,
            extraLines: []
        )
    }

    static func parse(from markdown: String, fallbackTitle: String) -> (Frontmatter, String) {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else {
            return (
                fallback(fallbackTitle: fallbackTitle),
                normalized
            )
        }

        let searchStart = normalized.index(normalized.startIndex, offsetBy: 4)
        guard let closeRange = normalized.range(of: "\n---", range: searchStart..<normalized.endIndex) else {
            return (
                fallback(fallbackTitle: fallbackTitle),
                normalized
            )
        }

        let yaml = String(normalized[searchStart..<closeRange.lowerBound])
        var bodyStart = closeRange.upperBound
        if bodyStart < normalized.endIndex, normalized[bodyStart] == "\n" {
            bodyStart = normalized.index(after: bodyStart)
        }
        let body = String(normalized[bodyStart...])

        return (parseYAML(yaml, fallbackTitle: fallbackTitle), body)
    }

    static func parseFrontmatter(from markdown: String, fallbackTitle: String) -> Frontmatter {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else {
            return fallback(fallbackTitle: fallbackTitle)
        }

        let searchStart = normalized.index(normalized.startIndex, offsetBy: 4)
        guard let closeRange = normalized.range(of: "\n---", range: searchStart..<normalized.endIndex) else {
            return fallback(fallbackTitle: fallbackTitle)
        }

        let yaml = String(normalized[searchStart..<closeRange.lowerBound])
        return parseYAML(yaml, fallbackTitle: fallbackTitle)
    }

    private static func parseYAML(_ yaml: String, fallbackTitle: String) -> Frontmatter {
        var title = fallbackTitle
        var order: String?
        var pubDatetime = ""
        var modDatetime = ""
        var description = ""
        var featured: Bool?
        var ogImage: String?
        var tags: [String] = []
        var extraLines: [String] = []
        var readingTags = false

        for line in normalizedFieldLines(yaml) {
            if readingTags {
                if let tag = Self.tagValue(from: line) {
                    tags.append(tag)
                    continue
                }
                readingTags = false
            }

            if line.hasPrefix("title:") {
                title = Self.scalarValue(from: line)
            } else if line.hasPrefix("order:") {
                order = Self.normalizedOrder(Self.scalarValue(from: line))
            } else if line.hasPrefix("pubDatetime:") {
                pubDatetime = Self.scalarValue(from: line)
            } else if line.hasPrefix("modDatetime:") {
                modDatetime = Self.scalarValue(from: line)
            } else if line.hasPrefix("description:") {
                description = Self.scalarValue(from: line)
            } else if line.hasPrefix("featured:") {
                featured = Self.boolValue(from: line)
            } else if line.hasPrefix("ogImage:") {
                ogImage = Self.normalizedOptionalScalar(Self.scalarValue(from: line))
            } else if line.hasPrefix("tags:") {
                let parsedInlineTags = Self.inlineTags(from: line)
                if parsedInlineTags.isEmpty {
                    readingTags = true
                } else {
                    tags.append(contentsOf: parsedInlineTags)
                    readingTags = false
                }
            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                extraLines.append(line)
            }
        }

        let now = DateFormatting.astropaperTimestamp.string(from: Date())
        return Frontmatter(
            title: title,
            order: order,
            pubDatetime: pubDatetime.isEmpty ? now : pubDatetime,
            modDatetime: modDatetime.isEmpty ? now : modDatetime,
            description: description,
            featured: featured,
            ogImage: ogImage,
            tags: tags,
            extraLines: extraLines
        )
    }

    private static func fallback(fallbackTitle: String) -> Frontmatter {
        let now = DateFormatting.astropaperTimestamp.string(from: Date())
        return Frontmatter(
            title: fallbackTitle,
            order: nil,
            pubDatetime: now,
            modDatetime: now,
            description: "",
            featured: nil,
            ogImage: nil,
            tags: [],
            extraLines: []
        )
    }

    func rendered() -> String {
        var lines: [String] = [
            "---",
            "title: \"\(Self.escape(title))\""
        ]

        if let order = Self.normalizedOrder(order) {
            lines.append("order: \(order)")
        }

        lines.append(contentsOf: [
            "pubDatetime: \(pubDatetime)",
            "modDatetime: \(modDatetime)",
            "description: \"\(Self.escape(description))\""
        ])

        if featured == true {
            lines.append("featured: true")
        }

        if let ogImage = Self.normalizedOptionalScalar(ogImage) {
            lines.append("ogImage: \"\(Self.escape(ogImage))\"")
        }

        lines.append("tags:")

        if tags.isEmpty {
            lines.append("  - general")
        } else {
            lines.append(contentsOf: tags.map { "  - \"\(Self.escape($0))\"" })
        }

        if !extraLines.isEmpty {
            lines.append(contentsOf: extraLines)
        }

        lines.append("---")
        return lines.joined(separator: "\n")
    }

    var postLinkSlug: String? {
        guard let line = extraLines.first(where: { $0.hasPrefix("slug:") }) else { return nil }
        let value = Self.scalarValue(from: line)
        if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
            return String(value.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
        }
        return value
    }

    private static func scalarValue(from line: String) -> String {
        guard let colon = line.firstIndex(of: ":") else { return "" }
        return unquoted(String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces))
    }

    // Collapse valid multiline fields before the line-oriented editor reads them.
    private static func normalizedFieldLines(_ yaml: String) -> [String] {
        let lines = yaml.components(separatedBy: "\n")
        guard (try? Yams.compose(yaml: yaml)) != nil else { return lines }
        let fields = ["title", "description", "ogImage", "pubDatetime", "modDatetime"]
        var result: [String] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            guard let field = fields.first(where: { line.hasPrefix($0 + ":") }) else {
                result.append(line)
                index += 1
                continue
            }
            var end = index + 1
            while end <= lines.count {
                let block = lines[index..<end].joined(separator: "\n")
                if let node = try? Yams.compose(yaml: block),
                   let value = node[field]?.string,
                   (end == lines.count || (!lines[end].hasPrefix(" ") && !lines[end].hasPrefix("\t"))) {
                    result.append("\(field): \"\(escape(value))\"")
                    break
                }
                end += 1
            }
            if end > lines.count {
                result.append(line)
                index += 1
            } else {
                index = end
            }
        }
        return result
    }

    private static func boolValue(from line: String) -> Bool? {
        let raw = scalarValue(from: line).lowercased()
        if ["true", "yes", "1"].contains(raw) { return true }
        if ["false", "no", "0"].contains(raw) { return false }
        return nil
    }

    private static func normalizedOptionalScalar(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedOrder(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func tagValue(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("-") else { return nil }
        return unquoted(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func inlineTags(from line: String) -> [String] {
        guard let colon = line.firstIndex(of: ":") else { return [] }
        var raw = line[line.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return [] }

        if raw.hasPrefix("["), raw.hasSuffix("]") {
            raw = String(raw.dropFirst().dropLast())
        }

        return raw.components(separatedBy: ",")
            .map { unquoted($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }
    }

    private static func unquoted(_ value: String) -> String {
        if let node = try? Yams.compose(yaml: value), let scalar = node.string {
            return scalar
        }
        return value
    }

    private static func escape(_ value: String) -> String {
        let data = try! JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8)!.dropFirst().dropLast().description
    }
}
