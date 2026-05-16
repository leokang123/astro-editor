import Foundation

final class EditorSession {
    private var bodyProvider: (() -> String?)?
    private var topLineProvider: (() -> Int?)?
    private(set) var topLine = 1

    func setBodyProvider(_ provider: (() -> String?)?) {
        bodyProvider = provider
    }

    func setTopLineProvider(_ provider: (() -> Int?)?) {
        topLineProvider = provider
    }

    func currentBody() -> String? {
        bodyProvider?()
    }

    func updateTopLine(_ line: Int) {
        topLine = max(line, 1)
    }

    func captureTopLine() {
        guard let line = topLineProvider?() else { return }
        updateTopLine(line)
    }

    func discardBodyProvider() {
        bodyProvider = nil
    }

    func reset() {
        bodyProvider = nil
        topLineProvider = nil
        topLine = 1
    }
}
