import AppKit
import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let document: BlogDocument
    let projectRoot: URL
    let sourcePosition: Double
    var onSourcePositionChange: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSourcePositionChange: onSourcePositionChange)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(context.coordinator.resourceSchemeHandler, forURLScheme: "astro-paper-resource")
        configuration.userContentController.add(context.coordinator, name: "sourcePosition")
        configuration.userContentController.addUserScript(WKUserScript(
            source: Self.sourcePositionScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let previousSourcePosition = context.coordinator.sourcePosition
        context.coordinator.sourcePosition = sourcePosition
        context.coordinator.onSourcePositionChange = onSourcePositionChange
        context.coordinator.resourceSchemeHandler.projectRoot = projectRoot.standardizedFileURL
        let metadataKey = [
            document.fileURL.path,
            document.frontmatter.title,
            document.frontmatter.description
        ].joined(separator: "\u{1F}")

        guard context.coordinator.metadataKey != metadataKey || context.coordinator.body != document.body else {
            if previousSourcePosition != sourcePosition {
                if context.coordinator.didReportSourcePosition(sourcePosition) {
                    context.coordinator.clearReportedSourcePosition()
                } else {
                    context.coordinator.scrollToSourcePosition(in: webView)
                }
            }
            return
        }
        context.coordinator.metadataKey = metadataKey
        context.coordinator.body = document.body

        let html = MarkdownPreviewHTMLRenderer(document: document, projectRoot: projectRoot).html()
        webView.loadHTMLString(html, baseURL: projectRoot)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "sourcePosition")
    }

    private static let sourcePositionScript = """
    (() => {
      var scheduled = false;
      var lastReportTime = 0;
      var pendingReportTimer = 0;
      window.astroPaperScrollSync = (() => {
        var cachedMarkers = null;
        const clampedProgress = value => Math.max(0, Math.min(1, value));
        const markerEntries = () => {
          if (cachedMarkers) return cachedMarkers;
          cachedMarkers = Array.from(document.querySelectorAll("[data-source-line]"))
            .map(element => ({ element, line: Number(element.dataset.sourceLine || "1") }))
            .filter(entry => Number.isFinite(entry.line));
          return cachedMarkers;
        };
        const sourceEntries = () => {
          const byLine = new Map();
          for (const entry of markerEntries()) {
            const rect = entry.element.getBoundingClientRect();
            if (rect.height <= 0 || rect.width <= 0) continue;
            const existing = byLine.get(entry.line);
            if (!existing || rect.height < existing.rect.height) {
              byLine.set(entry.line, { element: entry.element, line: entry.line, rect });
            }
          }
          return Array.from(byLine.values());
        };
        const sourcePositionForPageOffset = offset => {
          const entries = sourceEntries();
          if (!entries.length) return null;
          const position = offset - window.scrollY;
          let previous = null;
          let next = null;
          for (const entry of entries) {
            if (entry.rect.top <= position) {
              previous = entry;
            } else {
              next = entry;
              break;
            }
          }
          if (!previous) return entries[0].line;
          if (next && next.line !== previous.line) {
            const height = next.rect.top - previous.rect.top;
            const progress = height > 0 ? clampedProgress((position - previous.rect.top) / height) : 0;
            return previous.line + progress * (next.line - previous.line);
          }
          const progress = previous.rect.height > 0 ? clampedProgress((position - previous.rect.top) / previous.rect.height) : 0;
          return previous.line + progress;
        };
        const scrollToSourcePosition = targetPosition => {
          if (targetPosition <= 1) {
            window.scrollTo({ top: 0 });
            return;
          }
          const entries = sourceEntries();
          if (!entries.length) return;
          let previous = entries[0];
          let next = null;
          for (const entry of entries) {
            if (entry.line <= targetPosition) {
              previous = entry;
            } else {
              next = entry;
              break;
            }
          }
          const previousTop = window.scrollY + previous.rect.top;
          let top = previousTop;
          if (next && next.line !== previous.line) {
            const nextTop = window.scrollY + next.rect.top;
            const progress = clampedProgress((targetPosition - previous.line) / (next.line - previous.line));
            top = previousTop + (nextTop - previousTop) * progress;
          } else {
            const progress = clampedProgress(targetPosition - Math.floor(targetPosition));
            top = previousTop + previous.rect.height * progress;
          }
          window.scrollTo({ top });
        };
        return { sourcePositionForPageOffset, scrollToSourcePosition };
      })();
      const report = () => {
        scheduled = false;
        lastReportTime = Date.now();
        const position = window.astroPaperScrollSync.sourcePositionForPageOffset(window.scrollY);
        if (position !== null) {
          window.webkit.messageHandlers.sourcePosition.postMessage(position);
        }
      };
      const scheduleReport = () => {
        if (scheduled) return;
        const elapsed = Date.now() - lastReportTime;
        scheduled = true;
        if (elapsed >= 50) {
          window.requestAnimationFrame(report);
          return;
        }
        window.clearTimeout(pendingReportTimer);
        pendingReportTimer = window.setTimeout(() => window.requestAnimationFrame(report), 50 - elapsed);
      };
      window.addEventListener("scroll", () => {
        scheduleReport();
      }, { passive: true });
    })();
    """

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var metadataKey = ""
        var body = ""
        var sourcePosition = 1.0
        var reportedSourcePosition: Double?
        var onSourcePositionChange: (Double) -> Void
        let resourceSchemeHandler = PreviewResourceSchemeHandler()

        init(onSourcePositionChange: @escaping (Double) -> Void) {
            self.onSourcePositionChange = onSourcePositionChange
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
            guard message.name == "sourcePosition" else { return }
            if let position = message.body as? Double {
                reportedSourcePosition = position
                onSourcePositionChange(position)
            } else if let number = message.body as? NSNumber {
                let position = number.doubleValue
                reportedSourcePosition = position
                onSourcePositionChange(position)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            scrollToSourcePosition(in: webView)
        }

        func scrollToSourcePosition(in webView: WKWebView) {
            let position = max(sourcePosition, 1)
            let script = """
            (() => {
              const targetPosition = \(position);
              const reveal = () => document.body.classList.add("preview-ready");
              const waitForImages = () => {
                const images = Array.from(document.images).filter(image => !image.complete);
                if (!images.length) return Promise.resolve();
                return new Promise(resolve => {
                  let remaining = images.length;
                  const finish = () => {
                    remaining -= 1;
                    if (remaining <= 0) resolve();
                  };
                  window.setTimeout(resolve, 500);
                  for (const image of images) {
                    image.addEventListener("load", finish, { once: true });
                    image.addEventListener("error", finish, { once: true });
                  }
                });
              };
              const scrollToTargetPosition = () => {
                window.astroPaperScrollSync?.scrollToSourcePosition(targetPosition);
              };
              Promise.resolve(window.previewEnhancementsReady)
                .catch(() => {})
                .then(waitForImages)
                .catch(() => {})
                .finally(() => {
                  scrollToTargetPosition();
                  requestAnimationFrame(() => {
                    scrollToTargetPosition();
                    window.setTimeout(() => {
                      scrollToTargetPosition();
                      reveal();
                    }, 120);
                  });
                });
            })();
            """
            DispatchQueue.main.async {
                webView.evaluateJavaScript(script)
            }
        }

        func didReportSourcePosition(_ position: Double) -> Bool {
            guard let reportedSourcePosition else { return false }
            return abs(reportedSourcePosition - position) < 0.0001
        }

        func clearReportedSourcePosition() {
            reportedSourcePosition = nil
        }
    }
}

final class PreviewResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    var projectRoot: URL?

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let fileURL = fileURL(for: urlSchemeTask.request.url),
              let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let response = URLResponse(
            url: urlSchemeTask.request.url ?? fileURL,
            mimeType: mimeType(for: fileURL.pathExtension),
            expectedContentLength: data.count,
            textEncodingName: nil
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func fileURL(for requestURL: URL?) -> URL? {
        guard let requestURL,
              requestURL.scheme == "astro-paper-resource",
              let projectRoot else {
            return nil
        }

        let fileURL = URL(fileURLWithPath: requestURL.path).standardizedFileURL
        let projectPath = projectRoot.standardizedFileURL.path
        guard fileURL.path == projectPath || fileURL.path.hasPrefix(projectPath + "/") else {
            return nil
        }
        return fileURL
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
}
