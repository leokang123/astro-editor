import Foundation

struct SiteSettingsService {
    func configURL(for projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("config.ts", isDirectory: false)
    }

    func readHomeSettings(projectRoot: URL) throws -> HomeSettings {
        let config = try String(contentsOf: configURL(for: projectRoot), encoding: .utf8)

        return HomeSettings(
            siteTitle: config.tsStringValue(path: ["SITE", "title"]) ?? "",
            siteDescription: config.tsStringValue(path: ["SITE", "desc"]) ?? "",
            author: config.tsStringValue(path: ["SITE", "author"]) ?? "",
            website: config.tsStringValue(path: ["SITE", "website"]) ?? "",
            profile: config.tsStringValue(path: ["SITE", "profile"]) ?? "",
            homeTitle: config.tsStringValue(path: ["SITE", "home", "title"]) ?? "",
            homeDescription: config.tsStringArray(path: ["SITE", "home", "description"]),
            readMoreText: config.tsStringValue(path: ["SITE", "home", "readMore", "text"]) ?? "",
            readMoreLinkText: config.tsStringValue(path: ["SITE", "home", "readMore", "linkText"]) ?? "",
            readMoreHref: config.tsStringValue(path: ["SITE", "home", "readMore", "href"]) ?? "",
            socialLabel: config.tsStringValue(path: ["SITE", "home", "socialLabel"]) ?? "",
            allPostsText: config.tsStringValue(path: ["SITE", "home", "allPostsText"]) ?? "",
            postPerIndex: config.tsScalarValue(path: ["SITE", "postPerIndex"]) ?? ""
        )
    }

    func writeHomeSettings(_ settings: HomeSettings, projectRoot: URL) throws {
        let configURL = configURL(for: projectRoot)
        var config = try String(contentsOf: configURL, encoding: .utf8)

        config.replaceTSString(path: ["SITE", "title"], with: settings.siteTitle)
        config.replaceTSString(path: ["SITE", "desc"], with: settings.siteDescription)
        config.replaceTSString(path: ["SITE", "author"], with: settings.author)
        config.replaceTSString(path: ["SITE", "website"], with: settings.website)
        config.replaceTSString(path: ["SITE", "profile"], with: settings.profile)
        config.replaceTSString(path: ["SITE", "home", "title"], with: settings.homeTitle)
        config.replaceTSStringArray(path: ["SITE", "home", "description"], with: settings.homeDescription)
        config.replaceTSString(path: ["SITE", "home", "readMore", "text"], with: settings.readMoreText)
        config.replaceTSString(path: ["SITE", "home", "readMore", "linkText"], with: settings.readMoreLinkText)
        config.replaceTSString(path: ["SITE", "home", "readMore", "href"], with: settings.readMoreHref)
        config.replaceTSString(path: ["SITE", "home", "socialLabel"], with: settings.socialLabel)
        config.replaceTSString(path: ["SITE", "home", "allPostsText"], with: settings.allPostsText)
        config.replaceTSScalar(path: ["SITE", "postPerIndex"], with: settings.postPerIndex)

        try config.write(to: configURL, atomically: true, encoding: .utf8)
    }
}

private extension String {
    func tsStringValue(path: [String]) -> String? {
        guard let object = objectText(path: Array(path.dropLast())) else { return nil }
        let key = path.last ?? ""
        let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: key))\s*:\s*"((?:\\.|[^"\\])*)""#
        guard let match = object.firstMatch(pattern: pattern), match.numberOfRanges >= 2 else { return nil }
        return object.substring(range: match.range(at: 1))?.unescapedTSString
    }

    func tsScalarValue(path: [String]) -> String? {
        guard let object = objectText(path: Array(path.dropLast())) else { return nil }
        let key = path.last ?? ""
        let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: key))\s*:\s*([^,\n]+)"#
        guard let match = object.firstMatch(pattern: pattern), match.numberOfRanges >= 2 else { return nil }
        return object.substring(range: match.range(at: 1))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func tsStringArray(path: [String]) -> [String] {
        guard let object = objectText(path: Array(path.dropLast())) else { return [] }
        let key = path.last ?? ""
        let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: key))\s*:\s*\[([\s\S]*?)\]"#
        guard let match = object.firstMatch(pattern: pattern), match.numberOfRanges >= 2,
              let body = object.substring(range: match.range(at: 1)) else {
            return []
        }
        return body.matches(pattern: #""((?:\\.|[^"\\])*)""#)
            .compactMap { body.substring(range: $0.range(at: 1))?.unescapedTSString }
    }

    mutating func replaceTSString(path: [String], with value: String) {
        guard let objectRange = objectRange(path: Array(path.dropLast())) else { return }
        let object = String(self[objectRange])
        let key = path.last ?? ""
        let pattern = #"(\b\#(NSRegularExpression.escapedPattern(for: key))\s*:\s*)"((?:\\.|[^"\\])*)""#
        guard let match = object.firstMatch(pattern: pattern), match.numberOfRanges >= 3,
              let fullRangeInObject = Range(match.range(at: 0), in: object),
              let prefixRange = Range(match.range(at: 1), in: object) else {
            return
        }
        let replacement = "\(object[prefixRange])\"\(value.escapedTSString)\""
        var updatedObject = object
        updatedObject.replaceSubrange(fullRangeInObject, with: replacement)
        replaceSubrange(objectRange, with: updatedObject)
    }

    mutating func replaceTSScalar(path: [String], with value: String) {
        guard let objectRange = objectRange(path: Array(path.dropLast())) else { return }
        let object = String(self[objectRange])
        let key = path.last ?? ""
        let pattern = #"(\b\#(NSRegularExpression.escapedPattern(for: key))\s*:\s*)([^,\n]+)"#
        guard let match = object.firstMatch(pattern: pattern), match.numberOfRanges >= 3,
              let fullRangeInObject = Range(match.range(at: 0), in: object),
              let prefixRange = Range(match.range(at: 1), in: object) else {
            return
        }
        let replacement = "\(object[prefixRange])\(value.trimmingCharacters(in: .whitespacesAndNewlines))"
        var updatedObject = object
        updatedObject.replaceSubrange(fullRangeInObject, with: replacement)
        replaceSubrange(objectRange, with: updatedObject)
    }

    mutating func replaceTSStringArray(path: [String], with values: [String]) {
        guard let objectRange = objectRange(path: Array(path.dropLast())) else { return }
        let object = String(self[objectRange])
        let key = path.last ?? ""
        let pattern = #"(\b\#(NSRegularExpression.escapedPattern(for: key))\s*:\s*)\[([\s\S]*?)\]"#
        guard let match = object.firstMatch(pattern: pattern), match.numberOfRanges >= 3,
              let fullRangeInObject = Range(match.range(at: 0), in: object),
              let prefixRange = Range(match.range(at: 1), in: object) else {
            return
        }
        let lines = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { "      \"\($0.escapedTSString)\"," }
        let replacement = "\(object[prefixRange])[\n\(lines.joined(separator: "\n"))\n    ]"
        var updatedObject = object
        updatedObject.replaceSubrange(fullRangeInObject, with: replacement)
        replaceSubrange(objectRange, with: updatedObject)
    }

    func objectText(path: [String]) -> String? {
        guard let range = objectRange(path: path) else { return nil }
        return String(self[range])
    }

    func objectRange(path: [String]) -> Range<String.Index>? {
        if path.isEmpty {
            return startIndex..<endIndex
        }

        var searchRange = startIndex..<endIndex
        var objectRange: Range<String.Index>?
        for key in path {
            let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: key))\s*[:=]\s*\{"#
            guard let match = firstMatch(pattern: pattern, range: searchRange),
                  let matchRange = Range(match.range(at: 0), in: self),
                  let opening = self[matchRange].lastIndex(of: "{"),
                  let range = balancedRange(opening: opening, open: "{", close: "}") else {
                return nil
            }
            objectRange = range
            searchRange = range
        }
        return objectRange
    }

    func balancedRange(opening: String.Index, open: Character, close: Character) -> Range<String.Index>? {
        var depth = 0
        var isInString = false
        var stringQuote: Character?
        var isEscaped = false
        var index = opening

        while index < endIndex {
            let character = self[index]
            if isInString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == stringQuote {
                    isInString = false
                    stringQuote = nil
                }
            } else if character == "\"" || character == "'" || character == "`" {
                isInString = true
                stringQuote = character
            } else if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0 {
                    return opening..<self.index(after: index)
                }
            }
            index = self.index(after: index)
        }
        return nil
    }

    func firstMatch(pattern: String, range: Range<String.Index>? = nil) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let searchRange = range ?? startIndex..<endIndex
        return regex.firstMatch(in: self, range: NSRange(searchRange, in: self))
    }

    func matches(pattern: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: self, range: NSRange(startIndex..<endIndex, in: self))
    }

    func substring(range: NSRange) -> String? {
        guard let range = Range(range, in: self) else { return nil }
        return String(self[range])
    }

    var escapedTSString: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    var unescapedTSString: String {
        replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
