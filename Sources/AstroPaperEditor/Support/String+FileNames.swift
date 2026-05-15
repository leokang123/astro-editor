import Foundation

extension String {
    var astropaperSafePathComponent: String {
        let invalid = CharacterSet(charactersIn: "/:\\\0")
            .union(.controlCharacters)
        let pieces = components(separatedBy: invalid)
        let joined = pieces.joined(separator: "-")
        let collapsed = joined
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? "untitled" : collapsed
    }

    var trimmingForTags: [String] {
        components(separatedBy: CharacterSet(charactersIn: ",\n"))
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    }
}
