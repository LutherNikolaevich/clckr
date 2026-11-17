import AppKit
import ApplicationServices

@MainActor
final class Permissions: ObservableObject {
    static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    @Published private(set) var isTrusted: Bool

    init() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    func openSettings() {
        NSWorkspace.shared.open(Self.settingsURL)
    }
}
