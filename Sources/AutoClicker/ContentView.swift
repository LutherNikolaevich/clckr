import SwiftUI
import AutoClickerCore

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var engine: AutomationEngine
    @ObservedObject var permissions: Permissions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !permissions.isTrusted {
                permissionBanner
            }
            Picker("Mode", selection: $model.mode) {
                ForEach(AppModel.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch model.mode {
                case .mouse: mouseForm
                case .keyboard: keyboardForm
                }
            }
            .disabled(engine.isRunning)

            Divider()

            HStack {
                Text("Start delay (s)")
                TextField("", value: $model.startDelaySeconds, format: .number)
                    .frame(width: 60)
                    .disabled(engine.isRunning)
            }

            HStack {
                Button(engine.isRunning ? "Stop" : "Start") { model.toggle() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(engine.isRunning ? .red : .accentColor)
                    .disabled(!engine.isRunning && !model.canStart)
                Spacer()
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(statusText).monospacedDigit()
            }

            Text("F6 start/stop · Esc or top-left corner = emergency stop")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 420)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
        }
    }

    private var statusText: String {
        if engine.isRunning { return "Running — \(engine.actionCount) actions" }
        return engine.hasStopped ? "Stopped" : "Idle"
    }

    private var statusColor: Color {
        if engine.isRunning { return .green }
        return engine.hasStopped ? .orange : .secondary
    }

    private var permissionBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("Accessibility permission is required to send clicks and key presses.")
                .font(.callout)
            Spacer()
            Button("Open Settings") { permissions.openSettings() }
        }
        .padding(10)
        .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }

    private var mouseForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Button", selection: $model.button) {
                ForEach(MouseButton.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Click", selection: $model.clickType) {
                ForEach(ClickType.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            IntervalRow(intervalMs: $model.mouseIntervalMs)
            Picker("Position", selection: $model.usesFixedPosition) {
                Text("Cursor").tag(false)
                Text("Fixed").tag(true)
            }
            .pickerStyle(.segmented)
            if model.usesFixedPosition {
                HStack {
                    Button(model.pickCountdown.map { "Picking in \($0)…" } ?? "Pick Location") {
                        model.pickLocation()
                    }
                    .disabled(model.pickCountdown != nil)
                    .foregroundStyle(model.pickCountdown == nil ? Color.primary : Color.orange)
                    Text(model.fixedPoint.map { "X: \(Int($0.x))  Y: \(Int($0.y))" } ?? "Not set")
                        .monospacedDigit()
                }
            }
            RepeatRow(repeatsForever: $model.mouseRepeatsForever, count: $model.mouseRepeatCount)
        }
    }

    private var keyboardForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(model.isRecordingKey ? "Press a key…" : "Record Key") { model.recordKey() }
                    .foregroundStyle(model.isRecordingKey ? Color.orange : Color.primary)
                Text(model.keyCode.map { KeyCodeMap.name(for: $0) } ?? "None")
                    .font(.system(.body, design: .monospaced))
            }
            HStack {
                Toggle("⌘ Cmd", isOn: $model.useCommand)
                Toggle("⌥ Option", isOn: $model.useOption)
                Toggle("⌃ Control", isOn: $model.useControl)
                Toggle("⇧ Shift", isOn: $model.useShift)
            }
            .toggleStyle(.checkbox)
            IntervalRow(intervalMs: $model.keyIntervalMs)
            RepeatRow(repeatsForever: $model.keyRepeatsForever, count: $model.keyRepeatCount)
        }
    }
}

private struct IntervalRow: View {
    @Binding var intervalMs: Int

    var body: some View {
        HStack {
            Text("Interval (ms, min \(AutomationEngine.minimumIntervalMs))")
            TextField("", value: $intervalMs, format: .number)
                .frame(width: 70)
        }
    }
}

private struct RepeatRow: View {
    @Binding var repeatsForever: Bool
    @Binding var count: Int

    var body: some View {
        HStack {
            Picker("Repeat", selection: $repeatsForever) {
                Text("Until stopped").tag(true)
                Text("N times").tag(false)
            }
            .pickerStyle(.segmented)
            if !repeatsForever {
                TextField("", value: $count, format: .number)
                    .frame(width: 60)
            }
        }
    }
}
