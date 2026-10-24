import Foundation
import JavaScriptCore

struct PostLinkService {
    func documentID(for url: URL, in documents: [PostLinkDocument]) throws -> String? {
        let scriptURL = Bundle.main.url(forResource: "post-link.bundle", withExtension: "js", subdirectory: "CodeMirror")
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/CodeMirror/post-link.bundle.js")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)
        guard let context = JSContext() else { throw PostLinkError.unavailable }
        context.evaluateScript(script)
        let pathFunction = context.objectForKeyedSubscript("AstroPaperPostLinks")?.objectForKeyedSubscript("postLinkPath")
        let targetPath = normalizedPath(url.path)

        for document in documents {
            let data = try JSONEncoder().encode(document)
            let payload = try JSONSerialization.jsonObject(with: data)
            guard let path = pathFunction?.call(withArguments: [payload])?.toString(),
                  context.exception == nil,
                  let decodedPath = path.removingPercentEncoding else {
                throw PostLinkError.unavailable
            }
            if normalizedPath(decodedPath) == targetPath {
                return document.id
            }
        }
        return nil
    }

    private func normalizedPath(_ path: String) -> String {
        path.precomposedStringWithCanonicalMapping.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

private enum PostLinkError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Could not resolve the post link."
    }
}
