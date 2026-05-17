import AppKit
import Foundation

final class BuildService {
    static let localPreviewURL = URL(string: "http://localhost:8080/")!

    func runDockerCompose(at projectRoot: URL, onOutput: @escaping @MainActor (String) -> Void) async throws -> Int32 {
        let process = Process()
        if let dockerURL = dockerExecutableURL() {
            process.executableURL = dockerURL
            process.arguments = ["compose", "up", "--build", "-d"]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["docker", "compose", "up", "--build", "-d"]
        }
        process.currentDirectoryURL = projectRoot
        var environment = processEnvironment()
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

    private func dockerExecutableURL() -> URL? {
        let candidates = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/Applications/Docker.app/Contents/Resources/bin/docker",
        ] + processPathCandidates(named: "docker")

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        return nil
    }

    private func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = mergedPath(
            preferredPaths: [
                "/opt/homebrew/bin",
                "/usr/local/bin",
                "/usr/bin",
                "/bin",
                "/usr/sbin",
                "/sbin",
            ],
            existingPath: environment["PATH"]
        )
        environment["HOME"] = NSHomeDirectory()
        return environment
    }

    private func processPathCandidates(named executableName: String) -> [String] {
        ProcessInfo.processInfo.environment["PATH", default: ""]
            .split(separator: ":")
            .map { String($0) + "/" + executableName }
    }

    private func mergedPath(preferredPaths: [String], existingPath: String?) -> String {
        var seen = Set<String>()
        return (preferredPaths + (existingPath ?? "").split(separator: ":").map(String.init))
            .filter { path in
                guard !path.isEmpty, !seen.contains(path) else { return false }
                seen.insert(path)
                return true
            }
            .joined(separator: ":")
    }
}
