import SwiftUI

struct TerminalView: View {
    let controller: LockController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("~ ❯ keywipe")
                .font(Theme.mono(12))
                .foregroundStyle(Theme.dim)

            headline
                .padding(.top, 16)

            rows
                .padding(.top, 20)

            Spacer(minLength: 16)

            message
                .padding(.bottom, 14)

            action
        }
        .padding(.horizontal, 28)
        // The hidden title bar still reserves its strip above this content.
        .padding(.top, 12)
        .padding(.bottom, 26)
        .frame(width: 440, height: 352, alignment: .topLeading)
        .background(Theme.background)
        .background(WindowLevel(isFloating: controller.isLocked))
        .preferredColorScheme(.dark)
        .task { await controller.monitor() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            controller.unlock()
        }
    }

    // MARK: State

    /// Secure input turning on while locked means keystrokes are getting through.
    private var isLeaking: Bool {
        controller.isLocked && controller.secureInputHolder != nil
    }

    private var accent: Color {
        switch controller.phase {
        case .needsAccess: Theme.alert
        case .ready: Theme.live
        case .locked: isLeaking ? Theme.alert : Theme.locked
        }
    }

    // MARK: Sections

    private var headline: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(headlineWord)
                .font(Theme.mono(40, weight: .semibold))
                .foregroundStyle(accent)
            Cursor(color: accent)
                .frame(width: 20, height: 38)
        }
    }

    private var headlineWord: String {
        switch controller.phase {
        case .needsAccess: "no access"
        case .ready: "ready"
        case .locked: isLeaking ? "leaking" : "locked"
        }
    }

    @ViewBuilder
    private var rows: some View {
        VStack(alignment: .leading, spacing: 7) {
            switch controller.phase {
            case .needsAccess:
                Row("keyboard") { Text("live") }
                Row("access") { Text("not granted").foregroundStyle(Theme.alert) }
            case .ready:
                Row("keyboard") { Text("live") }
                Row("access") { Text("granted") }
            case .locked(let since):
                Row("keyboard") { Text(isLeaking ? "not blocked" : "blocked").foregroundStyle(accent) }
                Row("elapsed") { Text(since, style: .timer) }
                Row("caught") {
                    Text("\(controller.blockedCount) \(controller.blockedCount == 1 ? "key" : "keys")")
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.15), value: controller.blockedCount)
                }
            }
        }
    }

    @ViewBuilder
    private var message: some View {
        if controller.tapFailed {
            Note("macos refused the event tap. quit keywipe and open it again.", color: Theme.alert)
        } else if let holder = controller.secureInputHolder, controller.phase != .needsAccess {
            Note(
                isLeaking
                    ? "\(holder) switched on secure input, which hides keystrokes from keywipe. keys reach apps until it lets go."
                    : "\(holder) is holding secure input, which hides keystrokes from keywipe. leave its password field or quit it to lock.",
                color: Theme.alert
            )
        } else {
            switch controller.phase {
            case .needsAccess:
                Note("keywipe stops keystrokes before they reach other apps. allow it under privacy & security › \(InputAccess.settingsName.lowercased()).")
            case .ready:
                Note("mouse and trackpad stay active while locked.")
            case .locked:
                HStack(spacing: 12) {
                    Note("or hold both ⌘ keys for \(Int(LockController.unlockHold))s")
                    Spacer(minLength: 0)
                    HoldProgress(start: controller.unlockHoldStart, tint: accent)
                }
            }
        }
    }

    @ViewBuilder
    private var action: some View {
        switch controller.phase {
        case .needsAccess:
            Button(action: controller.requestAccess) {
                ButtonLabel("grant access", hint: "opens system settings")
            }
            .buttonStyle(TerminalButtonStyle(tint: accent))
            .keyboardShortcut(.defaultAction)
        case .ready:
            Button(action: controller.lock) {
                ButtonLabel("lock keyboard", hint: "return ⏎")
            }
            .buttonStyle(TerminalButtonStyle(tint: accent))
            .keyboardShortcut(.defaultAction)
            .disabled(!controller.canLock)
        case .locked:
            Button(action: controller.unlock) {
                ButtonLabel("unlock", hint: "click")
            }
            .buttonStyle(TerminalButtonStyle(tint: accent))
        }
    }
}

// MARK: - Pieces

private struct Row<Value: View>: View {
    let label: String
    let value: Value

    init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .foregroundStyle(Theme.dim)
                .frame(width: 96, alignment: .leading)
            value
                .foregroundStyle(Theme.text)
        }
        .font(Theme.mono(13))
    }
}

private struct Note: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = Theme.dim) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(Theme.mono(11.5))
            .foregroundStyle(color)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ButtonLabel: View {
    let title: String
    let hint: String

    init(_ title: String, hint: String) {
        self.title = title
        self.hint = hint
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(hint)
                .font(Theme.mono(11.5))
                .opacity(0.55)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

/// A terminal block cursor with a hard blink.
private struct Cursor: View {
    let color: Color
    private let interval = 0.6

    var body: some View {
        TimelineView(.periodic(from: .now, by: interval)) { context in
            let isOn = Int(context.date.timeIntervalSinceReferenceDate / interval).isMultiple(of: 2)
            Rectangle()
                .fill(color)
                .opacity(isOn ? 1 : 0)
        }
    }
}

/// Fills cell by cell while both Command keys are held, emptying the moment they are not.
private struct HoldProgress: View {
    let start: Date?
    let tint: Color
    private let cells = 12

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { context in
            let fraction = start.map { context.date.timeIntervalSince($0) / LockController.unlockHold } ?? 0
            let filled = Int((min(max(fraction, 0), 1) * Double(cells)).rounded(.down))
            HStack(spacing: 3) {
                ForEach(0..<cells, id: \.self) { index in
                    Rectangle()
                        .fill(index < filled ? tint : Theme.faint)
                        .frame(width: 7, height: 11)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Keeps the window above other apps while locked, so the unlock button stays reachable.
private struct WindowLevel: NSViewRepresentable {
    let isFloating: Bool

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        // The view joins its window after the first update, so apply on the next turn.
        DispatchQueue.main.async {
            view.window?.level = isFloating ? .floating : .normal
        }
    }
}
