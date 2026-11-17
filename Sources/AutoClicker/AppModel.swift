import AppKit
import AutoClickerCore

@MainActor
final class AppModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case mouse = "Mouse"
        case keyboard = "Keyboard"

        var id: String { rawValue }
    }

    @Published var mode = Mode.mouse
    @Published var button = MouseButton.left
    @Published var clickType = ClickType.single
    @Published var mouseIntervalMs = 100
    @Published var usesFixedPosition = false
    @Published var fixedPoint: CGPoint?
    @Published var pickCountdown: Int?
    @Published var mouseRepeatsForever = true
    @Published var mouseRepeatCount = 10

    @Published var keyCode: CGKeyCode?
    @Published var useCommand = false
    @Published var useOption = false
    @Published var useControl = false
    @Published var useShift = false
    @Published var keyIntervalMs = 100
    @Published var keyRepeatsForever = true
    @Published var keyRepeatCount = 10
    @Published var isRecordingKey = false

    @Published var startDelaySeconds = 2

    let engine = AutomationEngine(poster: CGEventPoster())
    let permissions = Permissions()
    private let hotkeys = HotkeyManager()
    private var recordMonitor: Any?

    init() {
        hotkeys.install(
            onToggle: { [weak self] in self?.toggle() },
            onStop: { [weak self] in self?.engine.stop() }
        )
    }

    var canStart: Bool {
        switch mode {
        case .mouse: return !usesFixedPosition || fixedPoint != nil
        case .keyboard: return keyCode != nil
        }
    }

    func toggle() {
        guard !isRecordingKey else { return }
        if engine.isRunning {
            engine.stop()
        } else {
            start()
        }
    }

    func start() {
        permissions.refresh()
        guard permissions.isTrusted, canStart, let action = makeAction() else { return }
        engine.start(action, startDelay: TimeInterval(max(0, startDelaySeconds)))
    }

    func pickLocation() {
        guard pickCountdown == nil else { return }
        Task {
            for remaining in stride(from: 3, to: 0, by: -1) {
                pickCountdown = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            pickCountdown = nil
            fixedPoint = CGEvent(source: nil)?.location
        }
    }

    func recordKey() {
        guard !isRecordingKey else { return }
        isRecordingKey = true
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            MainActor.assumeIsolated { self?.captureKey(keyCode) }
            return nil
        }
    }

    private func captureKey(_ pressed: UInt16) {
        let escape: UInt16 = 53
        let toggle: UInt16 = 97
        if pressed != escape && pressed != toggle {
            keyCode = CGKeyCode(pressed)
        }
        if pressed != toggle {
            finishRecording()
        }
    }

    private func finishRecording() {
        if let recordMonitor {
            NSEvent.removeMonitor(recordMonitor)
        }
        recordMonitor = nil
        isRecordingKey = false
    }

    private func makeAction() -> AutomationEngine.Action? {
        switch mode {
        case .mouse:
            let position: ClickPosition
            if usesFixedPosition {
                guard let fixedPoint else { return nil }
                position = .fixed(fixedPoint)
            } else {
                position = .current
            }
            return .mouse(ClickConfig(
                button: button,
                clickType: clickType,
                intervalMs: mouseIntervalMs,
                position: position,
                repeatMode: mouseRepeatsForever ? .untilStopped : .times(mouseRepeatCount)
            ))
        case .keyboard:
            guard let keyCode else { return nil }
            return .key(KeyConfig(
                keyCode: keyCode,
                modifiers: modifierFlags,
                intervalMs: keyIntervalMs,
                repeatMode: keyRepeatsForever ? .untilStopped : .times(keyRepeatCount)
            ))
        }
    }

    private var modifierFlags: CGEventFlags {
        var flags = CGEventFlags()
        if useCommand { flags.insert(.maskCommand) }
        if useOption { flags.insert(.maskAlternate) }
        if useControl { flags.insert(.maskControl) }
        if useShift { flags.insert(.maskShift) }
        return flags
    }
}
