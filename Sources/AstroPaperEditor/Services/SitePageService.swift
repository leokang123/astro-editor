import Foundation

struct SitePageService {
    func aboutURL(for projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("pages", isDirectory: true)
            .appendingPathComponent("about.md", isDirectory: false)
    }

    func readAbout(projectRoot: URL) throws -> SiteMarkdownPage {
        let markdown = try String(contentsOf: aboutURL(for: projectRoot), encoding: .utf8)
        return SiteMarkdownPage.parse(markdown)
    }

    func writeAbout(_ page: SiteMarkdownPage, projectRoot: URL) throws {
        try page.rendered().write(to: aboutURL(for: projectRoot), atomically: true, encoding: .utf8)
    }
}
