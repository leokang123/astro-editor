import Foundation

struct PreviewAssets {
    let projectRoot: URL

    var katexStylesheetTag: String {
        tag(for: "node_modules/katex/dist/katex.min.css", kind: .stylesheet)
    }

    var katexFallbackStylesheetTag: String {
        """
        <style>
          .katex {
            font-size: 1.08em;
            line-height: 1.2;
            text-rendering: auto;
          }
          .katex .katex-mathml {
            border: 0;
            clip: rect(1px, 1px, 1px, 1px);
            height: 1px;
            overflow: hidden;
            padding: 0;
            position: absolute;
            width: 1px;
          }
          .katex-display {
            display: block;
            margin: 1em 0;
            overflow-x: auto;
            overflow-y: hidden;
            text-align: center;
          }
          .katex-display > .katex {
            display: inline-block;
            max-width: 100%;
            text-align: initial;
            white-space: nowrap;
          }
        </style>
        """
    }

    var katexScriptTag: String {
        tag(for: "node_modules/katex/dist/katex.min.js", kind: .script)
    }

    var katexAutoRenderScriptTag: String {
        tag(for: "node_modules/katex/dist/contrib/auto-render.min.js", kind: .script)
    }

    var mermaidScriptTag: String {
        tag(for: "node_modules/mermaid/dist/mermaid.min.js", kind: .script)
    }

    private func tag(for relativePath: String, kind: AssetKind) -> String {
        let url = projectRoot.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return fallbackTag(for: relativePath, kind: kind)
        }

        switch kind {
        case .stylesheet:
            guard let stylesheet = Self.cachedText(for: url) else {
                return fallbackTag(for: relativePath, kind: kind)
            }
            let rewrittenStylesheet = rewriteStylesheetResourceURLs(stylesheet, relativeTo: url.deletingLastPathComponent())
            return "<style>\n\(rewrittenStylesheet.replacingOccurrences(of: "</style>", with: "<\\/style>"))\n</style>"
        case .script:
            guard let script = Self.cachedText(for: url) else {
                return fallbackTag(for: relativePath, kind: kind)
            }
            return "<script>\n\(script.replacingOccurrences(of: "</script>", with: "<\\/script>"))\n</script>"
        }
    }

    private func rewriteStylesheetResourceURLs(_ stylesheet: String, relativeTo directory: URL) -> String {
        let range = NSRange(stylesheet.startIndex..<stylesheet.endIndex, in: stylesheet)
        let matches = Self.stylesheetURLRegex.matches(in: stylesheet, range: range).reversed()
        var rewritten = stylesheet

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let urlRange = Range(match.range(at: 2), in: rewritten),
                  let fullRange = Range(match.range(at: 0), in: rewritten) else {
                continue
            }

            let value = String(rewritten[urlRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard shouldRewriteStylesheetURL(value) else { continue }

            let fileURL = URL(fileURLWithPath: value, relativeTo: directory).standardizedFileURL
            guard isInsideProject(fileURL) else { continue }

            let quote = match.range(at: 1).location == NSNotFound
                ? ""
                : Range(match.range(at: 1), in: rewritten).map { String(rewritten[$0]) } ?? ""
            rewritten.replaceSubrange(fullRange, with: "url(\(quote)\(Self.localResourceURLString(for: fileURL))\(quote))")
        }

        return rewritten
    }

    private func shouldRewriteStylesheetURL(_ value: String) -> Bool {
        !value.isEmpty
            && !value.hasPrefix("/")
            && !value.hasPrefix("#")
            && !value.hasPrefix("data:")
            && !value.hasPrefix("http://")
            && !value.hasPrefix("https://")
            && !value.hasPrefix("astro-paper-resource:")
    }

    private func isInsideProject(_ url: URL) -> Bool {
        let filePath = url.standardizedFileURL.path
        let projectPath = projectRoot.standardizedFileURL.path
        return filePath == projectPath || filePath.hasPrefix(projectPath + "/")
    }

    private static func cachedText(for url: URL) -> String? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let cacheKey = [
            url.path,
            String(values?.contentModificationDate?.timeIntervalSince1970 ?? 0),
            String(values?.fileSize ?? 0)
        ].joined(separator: "|") as NSString

        if let cached = scriptCache.object(forKey: cacheKey) {
            return cached as String
        }

        guard let script = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        scriptCache.setObject(script as NSString, forKey: cacheKey)
        return script
    }

    private func fallbackTag(for relativePath: String, kind: AssetKind) -> String {
        switch (relativePath, kind) {
        case ("node_modules/katex/dist/katex.min.css", .stylesheet):
            return "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/katex@0.16.46/dist/katex.min.css\">"
        case ("node_modules/katex/dist/katex.min.js", .script):
            return "<script src=\"https://cdn.jsdelivr.net/npm/katex@0.16.46/dist/katex.min.js\"></script>"
        case ("node_modules/katex/dist/contrib/auto-render.min.js", .script):
            return "<script src=\"https://cdn.jsdelivr.net/npm/katex@0.16.46/dist/contrib/auto-render.min.js\"></script>"
        case ("node_modules/mermaid/dist/mermaid.min.js", .script):
            return "<script src=\"https://cdn.jsdelivr.net/npm/mermaid@11.15.0/dist/mermaid.min.js\"></script>"
        default:
            return ""
        }
    }

    private enum AssetKind {
        case stylesheet
        case script
    }

    private static func localResourceURLString(for url: URL) -> String {
        var components = URLComponents()
        components.scheme = "astro-paper-resource"
        components.path = url.standardizedFileURL.path
        return components.url?.absoluteString ?? url.absoluteString
    }

    private static let stylesheetURLRegex = try! NSRegularExpression(pattern: #"url\(\s*(['"]?)([^'")]+)\1\s*\)"#)
    private static let scriptCache = NSCache<NSString, NSString>()
}
