import AppKit
import Foundation

final class BuildService {
    static let localPreviewURL = URL(string: "http://localhost:8080/")!

    func runDockerCompose(at projectRoot: URL, onOutput: @escaping @MainActor (String) -> Void) async throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["docker", "compose", "up", "--build", "-d"]
        process.currentDirectoryURL = projectRoot
        var environment = ProcessInfo.processInfo.environment
        environment["PUBLIC_SITE_URL"] = Self.localPreviewURL.absoluteString
        environment["PUBLIC_BASE_PATH"] = ""
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let readability = pipe.fileHandleForReading
        readability.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in onOutput(text) }
        }

        try process.run()
        process.waitUntilExit()
        readability.readabilityHandler = nil
        return process.terminationStatus
    }

    func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
