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
