import Foundation

struct AstroPaperTemplateService {
    func isEmptyProjectDestination(_ url: URL) throws -> Bool {
        let entries = try FileManager.default.contentsOfDirectory(atPath: url.path)
        return entries.allSatisfy { $0 == ".DS_Store" }
    }

    func isGitOnlyProjectDestination(_ url: URL) throws -> Bool {
        let entries = try FileManager.default.contentsOfDirectory(atPath: url.path)
        let meaningfulEntries = entries.filter { $0 != ".DS_Store" }
        return meaningfulEntries == [".git"]
    }

    func createProject(at projectRoot: URL) throws {
        guard try isEmptyProjectDestination(projectRoot) else {
            throw AstroPaperTemplateError.destinationNotEmpty
        }

        let archiveURL = try templateArchiveURL()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = [
            "-xzf",
            archiveURL.path,
            "-C",
            projectRoot.path,
            "--strip-components",
            "1",
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw AstroPaperTemplateError.extractFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let blogRoot = projectRoot
            .appendingPathComponent("src", isDirectory: true)
            .appendingPathComponent("data", isDirectory: true)
            .appendingPathComponent("blog", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: blogRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw AstroPaperTemplateError.invalidTemplate
        }
    }

    private func templateArchiveURL() throws -> URL {
        if let bundledURL = Bundle.main.url(forResource: "AstroPaperStarter", withExtension: "tar.gz") {
            return bundledURL
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        let repositoryRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let developmentURL = repositoryRoot
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("AstroPaperStarter.tar.gz", isDirectory: false)

        guard FileManager.default.fileExists(atPath: developmentURL.path) else {
            throw AstroPaperTemplateError.missingTemplate
        }
        return developmentURL
    }
}

enum AstroPaperTemplateError: LocalizedError {
    case destinationNotEmpty
    case missingTemplate
    case extractFailed(String)
    case invalidTemplate

    var errorDescription: String? {
        switch self {
        case .destinationNotEmpty:
            return "The selected folder is not empty."
        case .missingTemplate:
            return "The bundled AstroPaper starter template is missing."
        case .extractFailed(let output):
            return output.isEmpty ? "Could not create the AstroPaper project." : output
        case .invalidTemplate:
            return "The bundled AstroPaper template did not create src/data/blog."
        }
    }
}
