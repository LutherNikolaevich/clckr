import Foundation
import CoreGraphics

private final class RunSession: @unchecked Sendable {
    private let lock = NSLock()
    private var active = true
    private var performed = 0

    func deactivate() {
        lock.lock()
        active = false
        lock.unlock()
    }

    func perform(limit: Int?, body: () -> Void) -> (count: Int, finished: Bool)? {
        lock.lock()
        defer { lock.unlock() }
        guard active else { return nil }
        body()
        performed += 1
        let finished = limit.map { performed >= $0 } ?? false
        if finished { active = false }
        return (performed, finished)
    }
}

@MainActor
public final class AutomationEngine: ObservableObject {
    public enum Action {
        case mouse(ClickConfig)
        case key(KeyConfig)

        var intervalMs: Int {
            switch self {
            case .mouse(let config): return config.intervalMs
            case .key(let config): return config.intervalMs
            }
        }

        var repeatMode: RepeatMode {
            switch self {
            case .mouse(let config): return config.repeatMode
            case .key(let config): return config.repeatMode
            }
        }
    }

    public static let minimumIntervalMs = 10

    public static func clampedInterval(_ intervalMs: Int) -> Int {
        max(intervalMs, minimumIntervalMs)
    }

    public static func events(for action: Action) -> [SyntheticEvent] {
        switch action {
        case .mouse(let config):
            let location: CGPoint?
            if case .fixed(let point) = config.position { location = point } else { location = nil }
            let clicks: Int64 = config.clickType == .double ? 2 : 1
            return (1...clicks).flatMap { state in
                [true, false].map {
                    SyntheticEvent.mouse(down: $0, button: config.button, location: location, clickState: state)
                }
            }
        case .key(let config):
            return [true, false].map {
                SyntheticEvent.key(down: $0, keyCode: config.keyCode, flags: config.modifiers)
            }
        }
    }

    @Published public private(set) var isRunning = false
    @Published public private(set) var actionCount = 0
    @Published public private(set) var hasStopped = false

    private let poster: EventPosting
    private let queue = DispatchQueue(label: "autoclicker.engine", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var session: RunSession?

    public init(poster: EventPosting) {
        self.poster = poster
    }

    public func start(_ action: Action, startDelay: TimeInterval = 0) {
        guard !isRunning else { return }
        let session = RunSession()
        let events = Self.events(for: action)
        let limit = action.repeatMode.limit
        let poster = self.poster
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer.schedule(
            deadline: .now() + max(0, startDelay),
            repeating: .milliseconds(Self.clampedInterval(action.intervalMs)),
            leeway: .nanoseconds(0)
        )
        timer.setEventHandler { [weak self] in
            guard let result = session.perform(limit: limit, body: { events.forEach(poster.post) }) else { return }
            if result.finished { timer.cancel() }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.record(result, from: session) }
            }
        }
        self.session = session
        self.timer = timer
        actionCount = 0
        hasStopped = false
        isRunning = true
        timer.resume()
    }

    public func stop() {
        guard let session else { return }
        session.deactivate()
        finish()
    }

    private func record(_ result: (count: Int, finished: Bool), from source: RunSession) {
        guard session === source else { return }
        actionCount = result.count
        if result.finished { finish() }
    }

    private func finish() {
        timer?.cancel()
        timer = nil
        session = nil
        isRunning = false
        hasStopped = true
    }
}
