import Foundation

struct SiteSettingsService {
    func configURL(for projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("config.ts", isDirectory: false)
    }

    func userSettingsURL(for projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("user-settings.ts", isDirectory: false)
    }

    func readHomeSettings(projectRoot: URL) throws -> HomeSettings {
        let userSettings = try String(contentsOf: userSettingsURL(for: projectRoot), encoding: .utf8)

        return HomeSettings(
            siteTitle: userSettings.tsStringValue(path: ["USER_SITE", "title"]) ?? "",
            siteDescription: userSettings.tsStringValue(path: ["USER_SITE", "desc"]) ?? "",
            author: userSettings.tsStringValue(path: ["USER_SITE", "author"]) ?? "",
            website: userSettings.tsStringValue(path: ["USER_SITE", "website"]) ?? "",
            profile: userSettings.tsStringValue(path: ["USER_SITE", "profile"]) ?? "",
            homeTitle: userSettings.tsStringValue(path: ["USER_SITE", "home", "title"]) ?? "",
            homeDescription: userSettings.tsStringArray(path: ["USER_SITE", "home", "description"]),
            readMoreText: userSettings.tsStringValue(path: ["USER_SITE", "home", "readMore", "text"]) ?? "",
            readMoreLinkText: userSettings.tsStringValue(path: ["USER_SITE", "home", "readMore", "linkText"]) ?? "",
            readMoreHref: userSettings.tsStringValue(path: ["USER_SITE", "home", "readMore", "href"]) ?? "",
            socialLabel: userSettings.tsStringValue(path: ["USER_SITE", "home", "socialLabel"]) ?? "",
            allPostsText: userSettings.tsStringValue(path: ["USER_SITE", "home", "allPostsText"]) ?? "",
            postPerIndex: userSettings.tsScalarValue(path: ["USER_SITE", "postPerIndex"]) ?? "",
            socials: userSettings.socialLinks()
        )
    }

    func writeHomeSettings(_ settings: HomeSettings, projectRoot: URL) throws {
        let settingsURL = userSettingsURL(for: projectRoot)
        var userSettings = try String(contentsOf: settingsURL, encoding: .utf8)

        userSettings.replaceTSString(path: ["USER_SITE", "title"], with: settings.siteTitle)
        userSettings.replaceTSString(path: ["USER_SITE", "desc"], with: settings.siteDescription)
        userSettings.replaceTSString(path: ["USER_SITE", "author"], with: settings.author)
        userSettings.replaceTSString(path: ["USER_SITE", "website"], with: settings.website)
        userSettings.replaceTSString(path: ["USER_SITE", "profile"], with: settings.profile)
        userSettings.replaceTSString(path: ["USER_SITE", "home", "title"], with: settings.homeTitle)
        userSettings.replaceTSStringArray(path: ["USER_SITE", "home", "description"], with: settings.homeDescription)
        userSettings.replaceTSString(path: ["USER_SITE", "home", "readMore", "text"], with: settings.readMoreText)
        userSettings.replaceTSString(path: ["USER_SITE", "home", "readMore", "linkText"], with: settings.readMoreLinkText)
        userSettings.replaceTSString(path: ["USER_SITE", "home", "readMore", "href"], with: settings.readMoreHref)
        userSettings.replaceTSString(path: ["USER_SITE", "home", "socialLabel"], with: settings.socialLabel)
        userSettings.replaceTSString(path: ["USER_SITE", "home", "allPostsText"], with: settings.allPostsText)
        userSettings.replaceTSScalar(path: ["USER_SITE", "postPerIndex"], with: settings.postPerIndex)

        try userSettings.write(to: settingsURL, atomically: true, encoding: .utf8)
    }

    func writeSocialSettings(_ settings: HomeSettings, projectRoot: URL) throws {
        let settingsURL = userSettingsURL(for: projectRoot)
        var userSettings = try String(contentsOf: settingsURL, encoding: .utf8)

        for social in settings.socials {
            userSettings.replaceSocialEnabled(name: social.name, isEnabled: social.isEnabled)
            userSettings.replaceSocialHref(name: social.name, href: social.href)
        }

        try userSettings.write(to: settingsURL, atomically: true, encoding: .utf8)
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

    func socialLinks() -> [SocialLinkSetting] {
        guard let socialRange = range(of: "export const USER_SOCIALS"),
              let bracketStart = self[socialRange.upperBound...].firstIndex(of: "["),
              let bracketRange = balancedRange(opening: bracketStart, open: "[", close: "]") else {
            return []
        }
        let section = String(self[bracketRange])
        return section.topLevelObjectTexts().compactMap { object in
            guard let name = object.tsObjectStringValue(key: "name"),
                  let href = object.tsObjectStringValue(key: "href") else {
                return nil
            }
            let enabled = object.tsObjectBooleanValue(key: "enabled") ?? true
            return SocialLinkSetting(name: name, isEnabled: enabled, href: href)
        }
    }

    mutating func replaceSocialEnabled(name: String, isEnabled: Bool) {
        guard let socialRange = range(of: "export const USER_SOCIALS"),
              let bracketStart = self[socialRange.upperBound...].firstIndex(of: "["),
              let bracketRange = balancedRange(opening: bracketStart, open: "[", close: "]") else {
            return
        }
        let section = String(self[bracketRange])
        let escapedName = NSRegularExpression.escapedPattern(for: name.escapedTSString)
        let objectPattern = #"(?s)\{\s*name:\s*"\#(escapedName)"\s*,.*?\}"#
        guard let objectMatch = section.firstMatch(pattern: objectPattern),
              let objectRange = Range(objectMatch.range(at: 0), in: section) else {
            return
        }

        var object = String(section[objectRange])
        let enabledValue = isEnabled ? "true" : "false"
        if let enabledMatch = object.firstMatch(pattern: #"\benabled:\s*(true|false)"#),
           let enabledRange = Range(enabledMatch.range(at: 0), in: object) {
            object.replaceSubrange(enabledRange, with: "enabled: \(enabledValue)")
        } else if let nameMatch = object.firstMatch(pattern: #"(name:\s*"((?:\\.|[^"\\])*)"\s*,)"#),
                  let nameLineRange = Range(nameMatch.range(at: 1), in: object) {
            object.replaceSubrange(nameLineRange, with: "\(object[nameLineRange])\n    enabled: \(enabledValue),")
        }

        var updatedSection = section
        updatedSection.replaceSubrange(objectRange, with: object)
        replaceSubrange(bracketRange, with: updatedSection)
    }

    mutating func replaceSocialHref(name: String, href: String) {
        guard let socialRange = range(of: "export const USER_SOCIALS"),
              let bracketStart = self[socialRange.upperBound...].firstIndex(of: "["),
              let bracketRange = balancedRange(opening: bracketStart, open: "[", close: "]") else {
            return
        }
        let section = String(self[bracketRange])
        let escapedName = NSRegularExpression.escapedPattern(for: name.escapedTSString)
        let pattern = #"(?s)(\{\s*name:\s*"\#(escapedName)"\s*,\s*(?:enabled:\s*(?:true|false)\s*,\s*)?href:\s*)"((?:\\.|[^"\\])*)""#
        guard let match = section.firstMatch(pattern: pattern), match.numberOfRanges >= 3,
              let fullRangeInSection = Range(match.range(at: 0), in: section),
              let prefixRange = Range(match.range(at: 1), in: section) else {
            return
        }
        let replacement = "\(section[prefixRange])\"\(href.escapedTSString)\""
        var updatedSection = section
        updatedSection.replaceSubrange(fullRangeInSection, with: replacement)
        replaceSubrange(bracketRange, with: updatedSection)
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

    func topLevelObjectTexts() -> [String] {
        var objects: [String] = []
        var index = startIndex
        while index < endIndex {
            guard self[index] == "{" else {
                index = self.index(after: index)
                continue
            }
            guard let range = balancedRange(opening: index, open: "{", close: "}") else {
                break
            }
            objects.append(String(self[range]))
            index = range.upperBound
        }
        return objects
    }

    func tsObjectStringValue(key: String) -> String? {
        let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: key))\s*:\s*"((?:\\.|[^"\\])*)""#
        guard let match = firstMatch(pattern: pattern), match.numberOfRanges >= 2 else { return nil }
        return substring(range: match.range(at: 1))?.unescapedTSString
    }

    func tsObjectBooleanValue(key: String) -> Bool? {
        let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: key))\s*:\s*(true|false)"#
        guard let match = firstMatch(pattern: pattern), match.numberOfRanges >= 2,
              let value = substring(range: match.range(at: 1)) else {
            return nil
        }
        return value == "true"
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
