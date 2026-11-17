import CoreGraphics

public enum SyntheticEvent: Equatable, Sendable {
    case mouse(down: Bool, button: MouseButton, location: CGPoint?, clickState: Int64)
    case key(down: Bool, keyCode: CGKeyCode, flags: CGEventFlags)
}

public protocol EventPosting {
    func post(_ event: SyntheticEvent)
}

public struct CGEventPoster: EventPosting {
    public init() {}

    public func post(_ event: SyntheticEvent) {
        switch event {
        case let .mouse(down, button, location, clickState):
            postMouse(down: down, button: button, location: location, clickState: clickState)
        case let .key(down, keyCode, flags):
            postKey(down: down, keyCode: keyCode, flags: flags)
        }
    }

    private func postMouse(down: Bool, button: MouseButton, location: CGPoint?, clickState: Int64) {
        if let location {
            CGWarpMouseCursorPosition(location)
        }
        let point = location ?? CGEvent(source: nil)?.location ?? .zero
        let (type, cgButton) = Self.mapping(button: button, down: down)
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: cgButton
        ) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: clickState)
        event.post(tap: .cghidEventTap)
    }

    private func postKey(down: Bool, keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down) else { return }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }

    private static func mapping(button: MouseButton, down: Bool) -> (CGEventType, CGMouseButton) {
        switch button {
        case .left: return (down ? .leftMouseDown : .leftMouseUp, .left)
        case .right: return (down ? .rightMouseDown : .rightMouseUp, .right)
        case .middle: return (down ? .otherMouseDown : .otherMouseUp, .center)
        }
    }
}
