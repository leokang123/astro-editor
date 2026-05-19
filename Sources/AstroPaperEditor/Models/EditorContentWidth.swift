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
            return 980
        case .wide:
            return 1180
        case .full:
            return .infinity
        }
    }
}
