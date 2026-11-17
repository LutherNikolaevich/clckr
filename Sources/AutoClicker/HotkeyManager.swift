import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    private static let escapeKeyCode: UInt16 = 53
    private static let cornerTolerance: CGFloat = 2
    private static let hotKeySignature: OSType = 0x41434C4B
    private static var toggleAction: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var monitors: [Any] = []
    private var cornerTimer: Timer?

    func install(onToggle: @escaping () -> Void, onStop: @escaping () -> Void) {
        Self.toggleAction = onToggle
        installToggleHotKey()

        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { event in
            guard event.keyCode == Self.escapeKeyCode else { return }
            MainActor.assumeIsolated { onStop() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            if event.keyCode == Self.escapeKeyCode {
                MainActor.assumeIsolated { onStop() }
            }
            return event
        }) {
            monitors.append(local)
        }

        cornerTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            MainActor.assumeIsolated {
                if Self.isCursorInTopLeftCorner() { onStop() }
            }
        }
    }

    private func installToggleHotKey() {
        var pressedEvent = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotkeyManager.toggleAction?() }
            return noErr
        }, 1, &pressedEvent, nil, &handlerRef)

        RegisterEventHotKey(
            UInt32(kVK_F6),
            0,
            EventHotKeyID(signature: Self.hotKeySignature, id: 1),
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private static func isCursorInTopLeftCorner() -> Bool {
        guard let frame = NSScreen.screens.first?.frame else { return false }
        let mouse = NSEvent.mouseLocation
        return mouse.x <= frame.minX + cornerTolerance && mouse.y >= frame.maxY - cornerTolerance
    }
}
