import Foundation

struct HomeSettings: Equatable {
    var siteTitle: String
    var siteDescription: String
    var author: String
    var website: String
    var profile: String
    var homeTitle: String
    var homeDescription: [String]
    var readMoreText: String
    var readMoreLinkText: String
    var readMoreHref: String
    var socialLabel: String
    var allPostsText: String
    var postPerIndex: String
    var postPerPage: String
    var socials: [SocialLinkSetting]
}

struct SocialLinkSetting: Identifiable, Equatable {
    var id: String { name }
    var name: String
    var isEnabled: Bool
    var href: String
}
