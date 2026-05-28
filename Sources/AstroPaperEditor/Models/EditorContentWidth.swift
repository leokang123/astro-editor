import CoreGraphics

enum EditorContentWidth: String, CaseIterable, Identifiable {
    case comfortable
    case wide
    case full

    static let storageKey = "editorContentWidth"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .comfortable:
            return "Comfortable"
        case .wide:
            return "Wide"
        case .full:
            return "Full"
        }
    }

    var maxWidth: CGFloat {
        switch self {
        case .comfortable:
            return 760
        case .wide:
            return 980
        case .full:
            return .infinity
        }
    }
}
