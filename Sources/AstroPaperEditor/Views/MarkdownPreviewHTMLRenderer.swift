import Foundation

struct MarkdownPreviewHTMLRenderer {
    let document: BlogDocument
    let projectRoot: URL

    func html() -> String {
        let assets = PreviewAssets(projectRoot: projectRoot)
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <base href="\(escapeHTML(projectBaseURLString))">
          \(assets.katexStylesheetTag)
          <style>
            :root {
              color-scheme: light dark;
              --bg: Canvas;
              --fg: CanvasText;
              --muted: color-mix(in srgb, CanvasText 58%, transparent);
              --rule: color-mix(in srgb, CanvasText 16%, transparent);
              --code-bg: color-mix(in srgb, CanvasText 8%, transparent);
            }
            html, body {
              margin: 0;
              padding: 0;
              background: var(--bg);
              color: var(--fg);
              font: -apple-system-body;
            }
            body {
              box-sizing: border-box;
              padding: 28px;
              line-height: 1.68;
              visibility: hidden;
            }
            body.preview-ready {
              visibility: visible;
            }
            main {
              max-width: 860px;
            }
            h1.title {
              font: -apple-system-large-title;
              font-weight: 750;
              line-height: 1.14;
              margin: 0 0 14px;
            }
            .description {
              color: var(--muted);
              margin: -4px 0 18px;
            }
            hr {
              border: 0;
              border-top: 1px solid var(--rule);
              margin: 18px 0 22px;
            }
            h1, h2, h3, h4, h5, h6 {
              line-height: 1.25;
              margin: 1.2em 0 0.45em;
            }
            h1 { font-size: 2rem; }
            h2 { font-size: 1.55rem; }
            h3 { font-size: 1.25rem; }
            p { margin: 0 0 1em; }
            a { color: LinkText; }
            .source-line-anchor {
              scroll-margin-top: 0;
            }
            blockquote {
              border-left: 3px solid var(--rule);
              color: var(--muted);
              margin: 1em 0;
              padding-left: 1em;
            }
            pre {
              background: var(--code-bg);
              border-radius: 8px;
              box-sizing: border-box;
              overflow-x: auto;
              padding: 14px;
            }
            code {
              font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, monospace;
              font-size: 0.92em;
            }
            :not(pre) > code {
              background: var(--code-bg);
              border-radius: 4px;
              padding: 0.12em 0.28em;
            }
            img {
              border-radius: 8px;
              display: block;
              height: auto;
              margin: 1em 0;
              max-width: 100%;
            }
            table {
              border-collapse: collapse;
              margin: 1em 0;
              width: 100%;
            }
            th, td {
              border: 1px solid var(--rule);
              padding: 0.5em 0.65em;
            }
            .mermaid {
              background: var(--code-bg);
              border-radius: 8px;
              margin: 1em 0;
              overflow-x: auto;
              padding: 14px;
            }
          </style>
        </head>
        <body>
          <main>
            <h1 class="title">\(escapeHTML(document.frontmatter.title))</h1>
            \(descriptionHTML)
            <hr>
            \(renderMarkdown(document.body))
          </main>
          \(assets.katexScriptTag)
          \(assets.katexAutoRenderScriptTag)
          \(assets.mermaidScriptTag)
          <script>
            async function renderPreviewEnhancements() {
              if (window.renderMathInElement) {
                renderMathInElement(document.body, {
                  delimiters: [
                    {left: "$$", right: "$$", display: true},
                    {left: "\\\\[", right: "\\\\]", display: true},
                    {left: "$", right: "$", display: false},
                    {left: "\\\\(", right: "\\\\)", display: false}
                  ],
                  throwOnError: false
                });
              }
              if (window.mermaid) {
                const dark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
                mermaid.initialize({
                  startOnLoad: false,
                  securityLevel: "loose",
                  theme: dark ? "dark" : "default"
                });
                await mermaid.run({ querySelector: ".mermaid" });
              }
            }
            function revealPreviewFallback() {
              document.body.classList.add("preview-ready");
            }
            if (document.readyState === "loading") {
              window.previewEnhancementsReady = new Promise(resolve => {
                document.addEventListener("DOMContentLoaded", async () => {
                  await renderPreviewEnhancements();
                  resolve();
                }, { once: true });
              });
            } else {
              window.previewEnhancementsReady = renderPreviewEnhancements();
            }
            window.setTimeout(revealPreviewFallback, 900);
          </script>
        </body>
        </html>
        """
    }

    private var descriptionHTML: String {
        let description = document.frontmatter.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { return "" }
        return "<p class=\"description\">\(escapeHTML(description))</p>"
    }

    private var projectBaseURLString: String {
        let value = projectRoot.standardizedFileURL.absoluteString
        return value.hasSuffix("/") ? value : value + "/"
    }

    private func renderMarkdown(_ markdown: String) -> String {
        var html: [String] = []
        var paragraph: [String] = []
        var listItems: [String] = []
        var codeLines: [String] = []
        var codeLanguage = ""
        var inCode = false
        var inBlockMath = false
        var blockMathLines: [String] = []
        var paragraphStartLine = 1
        var listStartLine = 1
        var codeStartLine = 1
        var blockMathStartLine = 1

        func marker(_ line: Int) -> String {
            " data-source-line=\"\(line)\""
        }

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            html.append("<p\(marker(paragraphStartLine))>\(paragraphHTML(paragraph, startLine: paragraphStartLine))</p>")
            paragraph.removeAll()
        }

        func flushList() {
            guard !listItems.isEmpty else { return }
            html.append("<ul\(marker(listStartLine))>\(listItems.map { "<li>\(inlineHTML($0))</li>" }.joined())</ul>")
            listItems.removeAll()
        }

        func flushCode() {
            let code = codeLines.joined(separator: "\n")
            if codeLanguage.lowercased() == "mermaid" {
                html.append("<div class=\"mermaid\"\(marker(codeStartLine))>\(escapeHTML(code))</div>")
            } else {
                let languageClass = codeLanguage.isEmpty ? "" : " class=\"language-\(escapeHTML(codeLanguage))\""
                html.append("<pre\(marker(codeStartLine))><code\(languageClass)>\(escapeHTML(code))</code></pre>")
            }
            codeLines.removeAll()
            codeLanguage = ""
        }

        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let sourceLine = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inCode {
                    flushCode()
                    inCode = false
                } else {
                    flushParagraph()
                    flushList()
                    inCode = true
                    codeStartLine = sourceLine
                    codeLanguage = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                index += 1
                continue
            }

            if inCode {
                codeLines.append(line)
                index += 1
                continue
            }

            if trimmed == "$$" {
                if inBlockMath {
                    html.append("<p\(marker(blockMathStartLine))>$$\(escapeHTML(blockMathLines.joined(separator: "\n")))$$</p>")
                    blockMathLines.removeAll()
                    inBlockMath = false
                } else {
                    flushParagraph()
                    flushList()
                    inBlockMath = true
                    blockMathStartLine = sourceLine
                }
                index += 1
                continue
            }

            if inBlockMath {
                blockMathLines.append(line)
                index += 1
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                flushList()
                index += 1
                continue
            }

            if trimmed == "---" || trimmed == "***" {
                flushParagraph()
                flushList()
                html.append("<hr\(marker(sourceLine))>")
                index += 1
                continue
            }

            if let image = image(from: trimmed) {
                flushParagraph()
                flushList()
                html.append("<figure\(marker(sourceLine))><img src=\"\(escapeHTML(imageSource(image.source)))\" alt=\"\(escapeHTML(image.alt))\"></figure>")
                index += 1
                continue
            }

            if let rawImageHTML = rawImageHTML(from: trimmed) {
                flushParagraph()
                flushList()
                html.append("<div\(marker(sourceLine))>\(rawImageHTML)</div>")
                index += 1
                continue
            }

            if let rawHTML = rawHTMLLine(from: trimmed) {
                flushParagraph()
                flushList()
                html.append(wrapSourceLine(rawHTML, line: sourceLine))
                index += 1
                continue
            }

            if let table = tableHTML(from: lines, startIndex: index) {
                flushParagraph()
                flushList()
                html.append(wrapSourceLine(table.html, line: sourceLine))
                index = table.nextIndex
                continue
            }

            if let heading = heading(from: trimmed) {
                flushParagraph()
                flushList()
                html.append("<h\(heading.level)\(marker(sourceLine))>\(inlineHTML(heading.text))</h\(heading.level)>")
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                flushList()
                let quote = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                html.append("<blockquote\(marker(sourceLine))>\(inlineHTML(quote))</blockquote>")
                index += 1
                continue
            }

            if let item = unorderedListItem(from: trimmed) {
                flushParagraph()
                if listItems.isEmpty {
                    listStartLine = sourceLine
                }
                listItems.append(item)
                index += 1
                continue
            }

            if paragraph.isEmpty {
                paragraphStartLine = sourceLine
            }
            paragraph.append(line)
            index += 1
        }

        if inCode { flushCode() }
        if inBlockMath {
            html.append("<p\(marker(blockMathStartLine))>$$\(escapeHTML(blockMathLines.joined(separator: "\n")))$$</p>")
        }
        flushParagraph()
        flushList()
        return html.joined(separator: "\n")
    }

    private func wrapSourceLine(_ html: String, line: Int) -> String {
        "<div data-source-line=\"\(line)\">\(html)</div>"
    }

    private func inlineHTML(_ markdown: String) -> String {
        var html = escapeHTML(markdown)
        html = replacePattern(Self.inlineCodeRegex, in: html, with: "<code>$1</code>")
        html = replacePattern(Self.strongRegex, in: html, with: "<strong>$1</strong>")
        html = replacePattern(Self.emphasisRegex, in: html, with: "<em>$1</em>")
        html = replacePattern(Self.linkRegex, in: html, with: "<a href=\"$2\">$1</a>")
        return html.replacingOccurrences(of: "\n", with: "<br>")
    }

    private func paragraphHTML(_ lines: [String], startLine: Int) -> String {
        lines.enumerated()
            .map { offset, line in
                let sourceLine = startLine + offset
                return "<span class=\"source-line-anchor\" data-source-line=\"\(sourceLine)\">\(inlineHTML(line))</span>"
            }
            .joined(separator: "<br>")
    }

    private func replacePattern(_ regex: NSRegularExpression, in text: String, with template: String) -> String {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private func heading(from line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }
        guard !hashes.isEmpty, hashes.count <= 6 else { return nil }
        let text = line.dropFirst(hashes.count).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (hashes.count, text)
    }

    private func unorderedListItem(from line: String) -> String? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return String(line.dropFirst(2))
        }
        return nil
    }

    private func image(from line: String) -> (alt: String, source: String)? {
        guard line.hasPrefix("!["), let altEnd = line.firstIndex(of: "]") else { return nil }
        let afterAlt = line[line.index(after: altEnd)...]
        guard afterAlt.hasPrefix("("), let sourceEnd = afterAlt.firstIndex(of: ")") else { return nil }
        let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<altEnd])
        let sourceStart = afterAlt.index(after: afterAlt.startIndex)
        let source = String(afterAlt[sourceStart..<sourceEnd])
        return source.isEmpty ? nil : (alt, source)
    }

    private func rawImageHTML(from line: String) -> String? {
        guard line.contains("<img"), line.contains("src=") else { return nil }
        guard let regex = try? NSRegularExpression(pattern: #"src=(["'])(.*?)\1"#) else { return line }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = regex.matches(in: line, range: range).reversed()
        guard !matches.isEmpty else { return line }

        var rewritten = line
        for match in matches {
            guard match.numberOfRanges >= 3,
                  let quoteRange = Range(match.range(at: 1), in: rewritten),
                  let sourceRange = Range(match.range(at: 2), in: rewritten) else {
                continue
            }
            let quote = String(rewritten[quoteRange])
            let source = String(rewritten[sourceRange])
            let replacement = "src=\(quote)\(escapeHTML(imageSource(source)))\(quote)"
            if let fullRange = Range(match.range(at: 0), in: rewritten) {
                rewritten.replaceSubrange(fullRange, with: replacement)
            }
        }
        return rewritten
    }

    private func rawHTMLLine(from line: String) -> String? {
        guard let tag = rawHTMLTag(from: line),
              Self.allowedRawHTMLTags.contains(tag),
              !containsBlockedRawHTML(in: line) else {
            return nil
        }
        return line
    }

    private func rawHTMLTag(from line: String) -> String? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = Self.rawHTMLTagRegex.firstMatch(in: line, range: range),
              let tagRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[tagRange]).lowercased()
    }

    private func containsBlockedRawHTML(in line: String) -> Bool {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return Self.blockedRawHTMLRegex.firstMatch(in: line, range: range) != nil
            || Self.eventHandlerAttributeRegex.firstMatch(in: line, range: range) != nil
    }

    private func tableHTML(from lines: [String], startIndex: Int) -> (html: String, nextIndex: Int)? {
        guard startIndex + 1 < lines.count else { return nil }
        let header = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let separator = lines[startIndex + 1].trimmingCharacters(in: .whitespaces)
        guard isTableRow(header), isTableSeparator(separator) else { return nil }

        var rows: [[String]] = [tableCells(from: header)]
        var index = startIndex + 2
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            guard isTableRow(line), !isTableSeparator(line) else { break }
            rows.append(tableCells(from: line))
            index += 1
        }

        guard let headerCells = rows.first, !headerCells.isEmpty else { return nil }
        let bodyRows = rows.dropFirst()
        let headHTML = "<thead><tr>\(headerCells.map { "<th>\(inlineHTML($0))</th>" }.joined())</tr></thead>"
        let rowHTML = bodyRows.map { row in
            "<tr>\(row.map { "<td>\(inlineHTML($0))</td>" }.joined())</tr>"
        }.joined()
        let bodyHTML = "<tbody>\(rowHTML)</tbody>"
        return ("<table>\(headHTML)\(bodyHTML)</table>", index)
    }

    private func isTableRow(_ line: String) -> Bool {
        line.contains("|") && tableCells(from: line).count >= 2
    }

    private func isTableSeparator(_ line: String) -> Bool {
        let cells = tableCells(from: line)
        guard cells.count >= 2 else { return false }
        return cells.allSatisfy { cell in
            let value = cell.trimmingCharacters(in: .whitespaces)
            guard value.count >= 3 else { return false }
            return value.allSatisfy { character in
                character == "-" || character == ":"
            } && value.contains("-")
        }
    }

    private func tableCells(from line: String) -> [String] {
        var value = line
        if value.hasPrefix("|") { value.removeFirst() }
        if value.hasSuffix("|") { value.removeLast() }
        return value.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func imageSource(_ source: String) -> String {
        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            return source
        }

        guard let url = imageURL(for: source) else { return source }
        return Self.localResourceURLString(for: url)
    }

    private func imageURL(for source: String) -> URL? {
        if source.hasPrefix("@/") {
            let relative = String(source.dropFirst(2))
            return projectRoot
                .appendingPathComponent("src", isDirectory: true)
                .appendingPathComponent(relative)
        }

        if source.hasPrefix("./") {
            return document.fileURL
                .deletingLastPathComponent()
                .appendingPathComponent(String(source.dropFirst(2)))
        }

        if source.hasPrefix("../") {
            return URL(fileURLWithPath: source, relativeTo: document.fileURL.deletingLastPathComponent()).standardizedFileURL
        }

        if source.hasPrefix("/") {
            return projectRoot
                .appendingPathComponent("public", isDirectory: true)
                .appendingPathComponent(String(source.dropFirst()))
        }

        return nil
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func localResourceURLString(for url: URL) -> String {
        var components = URLComponents()
        components.scheme = "astro-paper-resource"
        components.path = url.standardizedFileURL.path
        return components.url?.absoluteString ?? url.absoluteString
    }

    private static let inlineCodeRegex = try! NSRegularExpression(pattern: #"`([^`]+)`"#)
    private static let strongRegex = try! NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#)
    private static let emphasisRegex = try! NSRegularExpression(pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#)
    private static let linkRegex = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)
    private static let rawHTMLTagRegex = try! NSRegularExpression(pattern: #"^</?([A-Za-z][A-Za-z0-9-]*)\b"#)
    private static let blockedRawHTMLRegex = try! NSRegularExpression(
        pattern: #"<\s*(script|iframe|object|embed|form|input|button|style)\b|javascript:"#,
        options: [.caseInsensitive]
    )
    private static let eventHandlerAttributeRegex = try! NSRegularExpression(
        pattern: #"\son[A-Za-z]+\s*="#,
        options: [.caseInsensitive]
    )
    private static let allowedRawHTMLTags: Set<String> = [
        "a",
        "abbr",
        "b",
        "br",
        "center",
        "cite",
        "code",
        "del",
        "div",
        "em",
        "figcaption",
        "figure",
        "i",
        "ins",
        "kbd",
        "mark",
        "p",
        "small",
        "span",
        "strong",
        "sub",
        "sup",
        "u"
    ]
}
