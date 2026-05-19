import Foundation

final class EditorSession {
    private var bodyProvider: (() -> String?)?
    private var sourcePositionProvider: (() -> Double?)?
    private(set) var sourcePosition = 1.0

    func setBodyProvider(_ provider: (() -> String?)?) {
        bodyProvider = provider
    }

    func setSourcePositionProvider(_ provider: (() -> Double?)?) {
        sourcePositionProvider = provider
    }

    func currentBody() -> String? {
        bodyProvider?()
    }

    func updateSourcePosition(_ position: Double) {
        sourcePosition = max(position, 1)
    }

    func captureSourcePosition() {
        guard let position = sourcePositionProvider?() else { return }
        updateSourcePosition(position)
    }

    func discardBodyProvider() {
        bodyProvider = nil
    }

    func reset() {
        bodyProvider = nil
        sourcePositionProvider = nil
        sourcePosition = 1.0
    }
}
