import Foundation

enum SidebarSortOption: String, CaseIterable, Identifiable {
    case fileName
    case newestModified
    case oldestModified
    case createdDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fileName:
            return "File name"
        case .newestModified:
            return "Newest modified"
        case .oldestModified:
            return "Oldest modified"
        case .createdDate:
            return "Created date"
        }
    }
}
