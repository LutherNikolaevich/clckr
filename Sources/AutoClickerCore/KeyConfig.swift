import CoreGraphics

public struct KeyConfig: Equatable, Sendable {
    public var keyCode: CGKeyCode
    public var modifiers: CGEventFlags
    public var intervalMs: Int
    public var repeatMode: RepeatMode

    public init(
        keyCode: CGKeyCode,
        modifiers: CGEventFlags = [],
        intervalMs: Int = 100,
        repeatMode: RepeatMode = .untilStopped
    ) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.intervalMs = intervalMs
        self.repeatMode = repeatMode
    }
}
