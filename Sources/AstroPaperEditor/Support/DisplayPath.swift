import Foundation

extension URL {
    var displayPath: String {
        standardizedFileURL.path.abbreviatingHomeDirectoryForDisplay
    }
}

extension String {
    var abbreviatingHomeDirectoryForDisplay: String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        guard hasPrefix(homePath) else { return self }
        if self == homePath {
            return "~"
        }
        guard hasPrefix(homePath + "/") else { return self }
        return "~" + dropFirst(homePath.count)
    }
}
