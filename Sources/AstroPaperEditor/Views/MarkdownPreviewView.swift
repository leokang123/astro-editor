import AppKit
import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let document: BlogDocument
    let projectRoot: URL
    let sourceLine: Int
    var onSourceLineChange: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSourceLineChange: onSourceLineChange)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "sourceLine")
        configuration.userContentController.addUserScript(WKUserScript(
            source: Self.sourceLineScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let previousSourceLine = context.coordinator.sourceLine
        context.coordinator.sourceLine = sourceLine
        context.coordinator.onSourceLineChange = onSourceLineChange
        let renderKey = [
            document.fileURL.path,
            document.frontmatter.title,
            document.frontmatter.description,
            String(document.body.hashValue)
        ].joined(separator: "\u{1F}")
        guard context.coordinator.renderKey != renderKey else {
            if previousSourceLine != sourceLine {
                context.coordinator.scrollToSourceLine(in: webView)
            }
            return
        }
        context.coordinator.renderKey = renderKey

        let html = MarkdownPreviewHTMLRenderer(document: document, projectRoot: projectRoot).html()
        webView.loadHTMLString(html, baseURL: projectRoot)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "sourceLine")
    }

    private static let sourceLineScript = """
    (() => {
      var scheduled = false;
      const report = () => {
        scheduled = false;
        const elements = Array.from(document.querySelectorAll("[data-source-line]"));
        if (!elements.length) return;
        let best = elements[0];
        let bestDistance = Math.abs(elements[0].getBoundingClientRect().top);
        for (const element of elements) {
          const rect = element.getBoundingClientRect();
          if (rect.bottom < 0) continue;
          const distance = Math.abs(rect.top);
          if (distance < bestDistance) {
            best = element;
          }
          if (rect.top >= 0) break;
        }
        const line = Number(best.dataset.sourceLine || "1");
        window.webkit.messageHandlers.sourceLine.postMessage(line);
      };
      window.addEventListener("scroll", () => {
        if (scheduled) return;
        scheduled = true;
        window.requestAnimationFrame(report);
      }, { passive: true });
      report();
    })();
    """

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var renderKey = ""
        var sourceLine = 1
        var onSourceLineChange: (Int) -> Void

        init(onSourceLineChange: @escaping (Int) -> Void) {
            self.onSourceLineChange = onSourceLineChange
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "sourceLine" else { return }
            if let line = message.body as? Int {
                onSourceLineChange(line)
            } else if let number = message.body as? NSNumber {
                onSourceLineChange(number.intValue)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            scrollToSourceLine(in: webView)
        }

        func scrollToSourceLine(in webView: WKWebView) {
            let line = max(sourceLine, 1)
            let script = """
            (() => {
              const targetLine = \(line);
              const reveal = () => document.body.classList.add("preview-ready");
              const scrollToTargetLine = () => {
                const elements = Array.from(document.querySelectorAll("[data-source-line]"));
                if (!elements.length) return;
                let best = elements[0];
                let bestLine = Number(best.dataset.sourceLine || "1");
                for (const element of elements) {
                  const line = Number(element.dataset.sourceLine || "1");
                  if (line <= targetLine && line >= bestLine) {
                    best = element;
                    bestLine = line;
                  }
                }
                best.scrollIntoView({ block: "start" });
              };
              Promise.resolve(window.previewEnhancementsReady)
                .catch(() => {})
                .finally(() => {
                  scrollToTargetLine();
                  requestAnimationFrame(() => {
                    scrollToTargetLine();
                    window.setTimeout(() => {
                      scrollToTargetLine();
                      reveal();
                    }, 80);
                  });
                });
            })();
            """
            DispatchQueue.main.async {
                webView.evaluateJavaScript(script)
            }
        }
    }
}

private struct MarkdownPreviewHTMLRenderer {
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
            html.append("<p\(marker(paragraphStartLine))>\(inlineHTML(paragraph.joined(separator: "\n")))</p>")
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
        return dataURL(for: url) ?? url.absoluteString
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
            return URL(fileURLWithPath: source)
        }

        return nil
    }

    private func dataURL(for url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let mimeType = mimeType(for: url.pathExtension)
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "svg":
            return "image/svg+xml"
        case "webp":
            return "image/webp"
        case "heic":
            return "image/heic"
        default:
            return "image/png"
        }
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let inlineCodeRegex = try! NSRegularExpression(pattern: #"`([^`]+)`"#)
    private static let strongRegex = try! NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#)
    private static let emphasisRegex = try! NSRegularExpression(pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#)
    private static let linkRegex = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)
}

private struct PreviewAssets {
    let projectRoot: URL

    var katexStylesheetTag: String {
        tag(for: "node_modules/katex/dist/katex.min.css", kind: .stylesheet)
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
            return "<link rel=\"stylesheet\" href=\"\(url.absoluteString)\">"
        case .script:
            guard let script = Self.cachedScript(for: url) else {
                return fallbackTag(for: relativePath, kind: kind)
            }
            return "<script>\n\(script.replacingOccurrences(of: "</script>", with: "<\\/script>"))\n</script>"
        }
    }

    private static func cachedScript(for url: URL) -> String? {
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

    private static let scriptCache = NSCache<NSString, NSString>()
}
