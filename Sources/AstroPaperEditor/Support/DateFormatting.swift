import Foundation

enum DateFormatting {
    static let astropaperTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter
    }()

    static let imageDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let inspectorTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func inspectorTimestampString(from value: String) -> String {
        guard let date = astropaperTimestamp.date(from: value) else { return value }
        return inspectorTimestamp.string(from: date)
    }
}
