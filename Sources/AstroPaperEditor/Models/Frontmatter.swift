import Foundation

struct Frontmatter: Equatable {
    var title: String
    var order: String?
    var pubDatetime: String
    var modDatetime: String
    var description: String
    var tags: [String]
    var extraLines: [String]

    static func new(title: String, description: String, tags: [String], order: String? = nil, now: Date = Date()) -> Frontmatter {
        let timestamp = DateFormatting.astropaperTimestamp.string(from: now)
        return Frontmatter(
            title: title,
            order: normalizedOrder(order),
            pubDatetime: timestamp,
            modDatetime: timestamp,
            description: description,
            tags: tags,
            extraLines: []
        )
    }

    static func parse(from markdown: String, fallbackTitle: String) -> (Frontmatter, String) {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") else {
            return (
                Frontmatter(
                    title: fallbackTitle,
                    order: nil,
                    pubDatetime: DateFormatting.astropaperTimestamp.string(from: Date()),
                    modDatetime: DateFormatting.astropaperTimestamp.string(from: Date()),
                    description: "",
                    tags: [],
                    extraLines: []
                ),
                normalized
            )
        }

        let searchStart = normalized.index(normalized.startIndex, offsetBy: 4)
        guard let closeRange = normalized.range(of: "\n---", range: searchStart..<normalized.endIndex) else {
            return (
                Frontmatter(
                    title: fallbackTitle,
                    order: nil,
                    pubDatetime: DateFormatting.astropaperTimestamp.string(from: Date()),
                    modDatetime: DateFormatting.astropaperTimestamp.string(from: Date()),
                    description: "",
                    tags: [],
                    extraLines: []
                ),
                normalized
            )
        }

        let yaml = String(normalized[searchStart..<closeRange.lowerBound])
        var bodyStart = closeRange.upperBound
        if bodyStart < normalized.endIndex, normalized[bodyStart] == "\n" {
            bodyStart = normalized.index(after: bodyStart)
        }
        let body = String(normalized[bodyStart...])

        var title = fallbackTitle
        var order: String?
        var pubDatetime = ""
        var modDatetime = ""
        var description = ""
        var tags: [String] = []
        var extraLines: [String] = []
        var readingTags = false

        for line in yaml.components(separatedBy: "\n") {
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
        return (
            Frontmatter(
                title: title,
                order: order,
                pubDatetime: pubDatetime.isEmpty ? now : pubDatetime,
                modDatetime: modDatetime.isEmpty ? now : modDatetime,
                description: description,
                tags: tags,
                extraLines: extraLines
            ),
            body
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
            "description: \"\(Self.escape(description))\"",
            "tags:"
        ])

        if tags.isEmpty {
            lines.append("  - 일반")
        } else {
            lines.append(contentsOf: tags.map { "  - \(Self.escape($0))" })
        }

        if !extraLines.isEmpty {
            lines.append(contentsOf: extraLines)
        }

        lines.append("---")
        return lines.joined(separator: "\n")
    }

    private static func scalarValue(from line: String) -> String {
        guard let colon = line.firstIndex(of: ":") else { return "" }
        let raw = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        if raw.hasPrefix("\""), raw.hasSuffix("\""), raw.count >= 2 {
            return String(raw.dropFirst().dropLast()).replacingOccurrences(of: "\\\"", with: "\"")
        }
        return raw
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
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            return String(value.dropFirst().dropLast()).replacingOccurrences(of: "\\\"", with: "\"")
        }
        if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\\\"")
    }
}
