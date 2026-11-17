import CoreGraphics

public enum MouseButton: String, CaseIterable, Sendable {
    case left, right, middle
}

public enum ClickType: String, CaseIterable, Sendable {
    case single, double
}

public enum ClickPosition: Equatable, Sendable {
    case current
    case fixed(CGPoint)
}

public enum RepeatMode: Equatable, Sendable {
    case untilStopped
    case times(Int)

    var limit: Int? {
        guard case .times(let count) = self else { return nil }
        return max(1, count)
    }
}

public struct ClickConfig: Equatable, Sendable {
    public var button: MouseButton
    public var clickType: ClickType
    public var intervalMs: Int
    public var position: ClickPosition
    public var repeatMode: RepeatMode

    public init(
        button: MouseButton = .left,
        clickType: ClickType = .single,
        intervalMs: Int = 100,
        position: ClickPosition = .current,
        repeatMode: RepeatMode = .untilStopped
    ) {
        self.button = button
        self.clickType = clickType
        self.intervalMs = intervalMs
        self.position = position
        self.repeatMode = repeatMode
    }
}
