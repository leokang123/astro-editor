import XCTest
import Yams
@testable import AstroPaperEditor

final class FrontmatterTests: XCTestCase {
    func testStringRoundTrip() throws {
        let text = "Line one\nLine two: \"quoted\" \\path\tend"
        let frontmatter = Frontmatter.new(title: text, description: text, tags: ["a: b", "#tag", "true", "a,b"])
        let rendered = frontmatter.rendered()
        try FrontmatterValidation.validate(rendered, path: "post.md")
        let parsed = Frontmatter.parse(from: rendered + "\nbody", fallbackTitle: "fallback")
        XCTAssertEqual(parsed.0.title, text)
        XCTAssertEqual(parsed.0.description, text)
        XCTAssertEqual(parsed.0.tags, frontmatter.tags)
        XCTAssertEqual(parsed.1, "body")
    }

    func testMalformedPreservedLinesCanBeFixed() throws {
        let source = "---\ntitle: Test\ntags:\n  - general\nstray title\nstray title\nstray title\"\n---\nbody"
        XCTAssertThrowsError(try FrontmatterValidation.validate(source, path: "broken.md"))
        var (frontmatter, body) = Frontmatter.parse(from: source, fallbackTitle: "fallback")
        XCTAssertEqual(frontmatter.extraLines.count, 3)
        XCTAssertThrowsError(try FrontmatterValidation.validate(frontmatter.rendered(), path: "broken.md"))
        frontmatter.extraLines = []
        try FrontmatterValidation.validate(frontmatter.rendered(), path: "fixed.md")
        XCTAssertEqual(body, "body")
    }

    func testMultilineAndUnknownFieldsPreserved() throws {
        let source = "---\ntitle: Test\ndescription: |-\n  first\n  second\ndraft: true\ncustom:\n  nested: value\n---\nbody"
        let (frontmatter, _) = Frontmatter.parse(from: source, fallbackTitle: "fallback")
        XCTAssertEqual(frontmatter.description, "first\nsecond")
        XCTAssertEqual(frontmatter.extraLines, ["draft: true", "custom:", "  nested: value"])
        try FrontmatterValidation.validate(frontmatter.rendered(), path: "post.md")
    }

    func testMissingDelimiterRejected() {
        XCTAssertThrowsError(try FrontmatterValidation.validate("---\ntitle: Test", path: "post.md"))
    }

    func testInvalidSaveDoesNotOverwriteFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("post.md")
        try "original".write(to: file, atomically: true, encoding: .utf8)
        var frontmatter = Frontmatter.new(title: "Test", description: "", tags: [])
        frontmatter.extraLines = ["orphan text", "orphan text"]
        let document = BlogDocument(fileURL: file, relativePath: "post.md", frontmatter: frontmatter, body: "body")
        XCTAssertThrowsError(try BlogFileService().writeDocument(document))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "original")
    }
}
