import AppKit
import Foundation

final class BuildService {
    static let localPreviewURL = URL(string: "http://localhost:4321/")!
    static let composeProjectName = "astropaper-editor-preview"
    private let previewReadyTimeout: TimeInterval = 60
    private let processLock = NSLock()
    private var runningProcess: Process?

    func runDockerCompose(at projectRoot: URL, onOutput: @escaping @MainActor (String) -> Void) async throws -> Int32 {
        Task { @MainActor in onOutput("Stopping existing Docker preview...\n") }
        let downStatus = try runDocker(
            arguments: ["compose", "-p", Self.composeProjectName, "down"],
            at: projectRoot,
            onOutput: onOutput
        )
        guard downStatus == 0 else { return downStatus }

        Task { @MainActor in onOutput("Starting Docker preview...\n") }
        let upStatus = try runDocker(
            arguments: ["compose", "-p", Self.composeProjectName, "up", "--build", "-d"],
            at: projectRoot,
            onOutput: onOutput
        )
        guard upStatus == 0 else { return upStatus }

        Task { @MainActor in onOutput("Waiting for local preview at \(Self.localPreviewURL.absoluteString)...\n") }
        let isReady = await waitForPreviewReady(timeout: previewReadyTimeout)
        Task { @MainActor in
            onOutput(isReady ? "Preview ready at \(Self.localPreviewURL.absoluteString)\n" : "Preview started, but readiness was not confirmed within \(Int(previewReadyTimeout)) seconds.\n")
        }
        return 0
    }

    func stopDockerCompose(at projectRoot: URL, onOutput: @escaping @MainActor (String) -> Void) async throws -> Int32 {
        Task { @MainActor in onOutput("Stopping Docker preview...\n") }
        return try runDocker(
            arguments: ["compose", "-p", Self.composeProjectName, "down"],
            at: projectRoot,
            onOutput: onOutput
        )
    }

    func cancelCurrentOperation() {
        processLock.lock()
        let process = runningProcess
        processLock.unlock()
        process?.terminate()
    }

    func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func runDocker(
        arguments: [String],
        at projectRoot: URL,
        onOutput: @escaping @MainActor (String) -> Void
    ) throws -> Int32 {
        let process = Process()
        if let dockerURL = dockerExecutableURL() {
            process.executableURL = dockerURL
            process.arguments = arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["docker"] + arguments
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

        do {
            try process.run()
        } catch {
            readability.readabilityHandler = nil
            throw error
        }
        setRunningProcess(process)
        defer {
            clearRunningProcess(process)
            readability.readabilityHandler = nil
        }
        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return process.terminationStatus
    }

    private func waitForPreviewReady(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, !Task.isCancelled {
            if await previewResponds() {
                return true
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        return false
    }

    private func previewResponds() async -> Bool {
        var request = URLRequest(url: Self.localPreviewURL)
        request.timeoutInterval = 1.5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200..<500).contains(httpResponse.statusCode)
        } catch {
            return false
        }
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

    private func setRunningProcess(_ process: Process) {
        processLock.lock()
        runningProcess = process
        processLock.unlock()
    }

    private func clearRunningProcess(_ process: Process) {
        processLock.lock()
        if runningProcess === process {
            runningProcess = nil
        }
        processLock.unlock()
    }
}
