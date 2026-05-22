import Foundation

struct SiteSettingsService {
    func configURL(for projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("config.ts", isDirectory: false)
    }

    func userSettingsURL(for projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("user-settings.json", isDirectory: false)
    }

    func readHomeSettings(projectRoot: URL) throws -> HomeSettings {
        try ensureUserSettingsFileExists(projectRoot: projectRoot)
        let data = try Data(contentsOf: userSettingsURL(for: projectRoot))
        let decoded = try JSONDecoder().decode(UserSettingsFile.self, from: data)
        return decoded.homeSettings
    }

    func writeHomeSettings(_ settings: HomeSettings, projectRoot: URL) throws {
        try ensureUserSettingsFileExists(projectRoot: projectRoot)
        var file = try readSettingsFile(projectRoot: projectRoot)
        file.userSite = UserSiteSettings(settings: settings)
        try writeSettingsFile(file, projectRoot: projectRoot)
    }

    func writeSocialSettings(_ settings: HomeSettings, projectRoot: URL) throws {
        try ensureUserSettingsFileExists(projectRoot: projectRoot)
        var file = try readSettingsFile(projectRoot: projectRoot)
        file.userSocials = settings.socials.map(UserSocialSettings.init)
        try writeSettingsFile(file, projectRoot: projectRoot)
    }

    private func writeSettings(_ settings: HomeSettings, projectRoot: URL) throws {
        let file = UserSettingsFile(settings: settings)
        try writeSettingsFile(file, projectRoot: projectRoot)
    }

    private func readSettingsFile(projectRoot: URL) throws -> UserSettingsFile {
        let data = try Data(contentsOf: userSettingsURL(for: projectRoot))
        return try JSONDecoder().decode(UserSettingsFile.self, from: data)
    }

    private func writeSettingsFile(_ file: UserSettingsFile, projectRoot: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try data.write(to: userSettingsURL(for: projectRoot), options: .atomic)
    }

    private func ensureUserSettingsFileExists(projectRoot: URL) throws {
        let url = userSettingsURL(for: projectRoot)
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeSettings(Self.defaultSettings, projectRoot: projectRoot)
    }

    fileprivate static let defaultSettings = HomeSettings(
        siteTitle: "AstroPaper Blog",
        siteDescription: "Personal notes and posts",
        author: "",
        website: "http://localhost:4321/",
        profile: "http://localhost:4321/about/",
        homeTitle: "AstroPaper Blog",
        homeDescription: ["Personal notes and posts."],
        readMoreText: "Read the blog posts or check",
        readMoreLinkText: "README",
        readMoreHref: "https://github.com/satnaing/astro-paper#readme",
        socialLabel: "Social Links:",
        allPostsText: "All Posts",
        postPerIndex: "4",
        postPerPage: "4",
        socials: [
            SocialLinkSetting(name: "GitHub", isEnabled: false, href: ""),
            SocialLinkSetting(name: "X", isEnabled: false, href: ""),
            SocialLinkSetting(name: "LinkedIn", isEnabled: false, href: ""),
            SocialLinkSetting(name: "Mail", isEnabled: false, href: "")
        ]
    )
}

private struct UserSettingsFile: Codable {
    var userSite: UserSiteSettings
    var userSocials: [UserSocialSettings]

    var homeSettings: HomeSettings {
        HomeSettings(
            siteTitle: userSite.title,
            siteDescription: userSite.desc,
            author: userSite.author,
            website: userSite.website,
            profile: userSite.profile,
            homeTitle: userSite.home.title,
            homeDescription: userSite.home.description,
            readMoreText: userSite.home.readMore.text,
            readMoreLinkText: userSite.home.readMore.linkText,
            readMoreHref: userSite.home.readMore.href,
            socialLabel: userSite.home.socialLabel,
            allPostsText: userSite.home.allPostsText,
            postPerIndex: userSite.postPerIndex.stringValue,
            postPerPage: userSite.postPerPage.stringValue,
            socials: userSocials.map {
                SocialLinkSetting(name: $0.name, isEnabled: $0.enabled, href: $0.href)
            }
        )
    }

    init(settings: HomeSettings) {
        userSite = UserSiteSettings(settings: settings)
        userSocials = settings.socials.map(UserSocialSettings.init)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SiteSettingsService.defaultSettings
        userSite = try container.decodeIfPresent(UserSiteSettings.self, forKey: .userSite)
            ?? UserSiteSettings(settings: defaults)
        userSocials = try container.decodeIfPresent([UserSocialSettings].self, forKey: .userSocials)
            ?? defaults.socials.map(UserSocialSettings.init)
    }

    enum CodingKeys: String, CodingKey {
        case userSite = "USER_SITE"
        case userSocials = "USER_SOCIALS"
    }
}

private struct UserSiteSettings: Codable {
    var website: String
    var author: String
    var profile: String
    var desc: String
    var title: String
    var postPerIndex: FlexibleJSONScalar
    var postPerPage: FlexibleJSONScalar
    var home: UserHomeSettings

    init(settings: HomeSettings) {
        website = settings.website
        author = settings.author
        profile = settings.profile
        desc = settings.siteDescription
        title = settings.siteTitle
        postPerIndex = FlexibleJSONScalar(settings.postPerIndex)
        postPerPage = FlexibleJSONScalar(settings.postPerPage)
        home = UserHomeSettings(settings: settings)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = UserSiteSettings(settings: SiteSettingsService.defaultSettings)
        website = try container.decodeIfPresent(String.self, forKey: .website) ?? defaults.website
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? defaults.author
        profile = try container.decodeIfPresent(String.self, forKey: .profile) ?? defaults.profile
        desc = try container.decodeIfPresent(String.self, forKey: .desc) ?? defaults.desc
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? defaults.title
        postPerIndex = try container.decodeIfPresent(FlexibleJSONScalar.self, forKey: .postPerIndex) ?? defaults.postPerIndex
        postPerPage = try container.decodeIfPresent(FlexibleJSONScalar.self, forKey: .postPerPage) ?? defaults.postPerPage
        home = try container.decodeIfPresent(UserHomeSettings.self, forKey: .home) ?? defaults.home
    }

    enum CodingKeys: String, CodingKey {
        case website
        case author
        case profile
        case desc
        case title
        case postPerIndex
        case postPerPage
        case home
    }
}

private struct UserHomeSettings: Codable {
    var title: String
    var description: [String]
    var readMore: UserReadMoreSettings
    var socialLabel: String
    var allPostsText: String

    init(settings: HomeSettings) {
        title = settings.homeTitle
        description = settings.homeDescription
        readMore = UserReadMoreSettings(settings: settings)
        socialLabel = settings.socialLabel
        allPostsText = settings.allPostsText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = UserHomeSettings(settings: SiteSettingsService.defaultSettings)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? defaults.title
        description = try container.decodeIfPresent([String].self, forKey: .description) ?? defaults.description
        readMore = try container.decodeIfPresent(UserReadMoreSettings.self, forKey: .readMore) ?? defaults.readMore
        socialLabel = try container.decodeIfPresent(String.self, forKey: .socialLabel) ?? defaults.socialLabel
        allPostsText = try container.decodeIfPresent(String.self, forKey: .allPostsText) ?? defaults.allPostsText
    }

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case readMore
        case socialLabel
        case allPostsText
    }
}

private struct UserReadMoreSettings: Codable {
    var text: String
    var linkText: String
    var href: String

    init(settings: HomeSettings) {
        text = settings.readMoreText
        linkText = settings.readMoreLinkText
        href = settings.readMoreHref
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = UserReadMoreSettings(settings: SiteSettingsService.defaultSettings)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? defaults.text
        linkText = try container.decodeIfPresent(String.self, forKey: .linkText) ?? defaults.linkText
        href = try container.decodeIfPresent(String.self, forKey: .href) ?? defaults.href
    }

    enum CodingKeys: String, CodingKey {
        case text
        case linkText
        case href
    }
}

private struct UserSocialSettings: Codable {
    var name: String
    var enabled: Bool
    var href: String

    init(_ setting: SocialLinkSetting) {
        name = setting.name
        enabled = setting.isEnabled
        href = setting.href
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        href = try container.decodeIfPresent(String.self, forKey: .href) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case name
        case enabled
        case href
    }
}

private struct FlexibleJSONScalar: Codable {
    var stringValue: String

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            stringValue = value
        } else if let value = try? container.decode(Int.self) {
            stringValue = String(value)
        } else if let value = try? container.decode(Double.self) {
            stringValue = String(value)
        } else if let value = try? container.decode(Bool.self) {
            stringValue = value ? "true" : "false"
        } else {
            stringValue = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Int(trimmed) {
            try container.encode(value)
        } else {
            try container.encode(stringValue)
        }
    }
}
