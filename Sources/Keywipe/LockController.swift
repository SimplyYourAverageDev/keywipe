import Foundation
import Observation

/// Owns the lock: permission state, the event tap, and the ways back out of it.
@MainActor
@Observable
final class LockController {
    enum Phase: Equatable {
        case needsAccess
        case ready
        case locked(since: Date)
    }

    /// How long both Command keys must be held to unlock from the keyboard.
    static let unlockHold: TimeInterval = 2

    private(set) var phase: Phase
    /// Key presses swallowed since the keyboard was last locked.
    private(set) var blockedCount = 0
    /// The app holding Secure Event Input, which makes keystrokes bypass the tap.
    private(set) var secureInputHolder: String?
    /// When the current unlock hold began; nil while the gesture is not in progress.
    private(set) var unlockHoldStart: Date?
    /// Set when macOS refuses the tap even though permission looks granted.
    private(set) var tapFailed = false

    @ObservationIgnored private var tap: KeyboardTap?
    @ObservationIgnored private var unlockTask: Task<Void, Never>?
    @ObservationIgnored private var capsLockBeforeLock: Bool?
    @ObservationIgnored private var hasPrompted = false

    init() {
        phase = InputAccess.isGranted ? .ready : .needsAccess
        secureInputHolder = SecureInput.holder
    }

    var isLocked: Bool {
        if case .locked = phase { true } else { false }
    }

    /// Locking is pointless while another app holds secure input, so it is refused.
    var canLock: Bool {
        phase == .ready && secureInputHolder == nil
    }

    func lock() {
        refresh()
        guard canLock else { return }

        let tap = KeyboardTap { [weak self] key in
            // The main queue keeps events in order, which the unlock gesture depends on.
            DispatchQueue.main.async {
                self?.blocked(key)
            }
        }
        guard tap.start() else {
            tapFailed = true
            return
        }
        self.tap = tap
        tapFailed = false
        blockedCount = 0
        capsLockBeforeLock = CapsLock.isOn
        phase = .locked(since: .now)
    }

    func unlock() {
        guard isLocked else { return }
        tap?.stop()
        tap = nil
        cancelUnlockHold()
        restoreCapsLock()
        phase = InputAccess.isGranted ? .ready : .needsAccess
    }

    /// The first request shows the system prompt, which registers the app in the list.
    /// The prompt appears once, so later requests go straight to the settings pane.
    func requestAccess() {
        if hasPrompted {
            InputAccess.openSettings()
        } else {
            hasPrompted = true
            InputAccess.prompt()
        }
    }

    /// Keeps permission, secure input and tap health current for as long as it runs.
    func monitor() async {
        while !Task.isCancelled {
            refresh()
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private func refresh() {
        let holder = SecureInput.holder
        if holder != secureInputHolder {
            secureInputHolder = holder
        }

        let isGranted = InputAccess.isGranted
        switch phase {
        case .needsAccess:
            if isGranted { phase = .ready }
        case .ready:
            if !isGranted { phase = .needsAccess }
        case .locked:
            if !isGranted {
                // An active tap without its permission can stall input, so drop it at once.
                unlock()
            } else if tap?.isEnabled == false {
                tap?.enable()
            }
        }
    }

    private func blocked(_ key: BlockedKey) {
        guard isLocked else { return }
        if key.isPress {
            blockedCount += 1
        }
        if key.isCapsLock {
            restoreCapsLock()
        }

        if let modifiers = key.modifiers {
            if modifiers.leftCommand && modifiers.rightCommand && !modifiers.others {
                beginUnlockHold()
            } else {
                cancelUnlockHold()
            }
        } else if key.isPress {
            // Any other key during the hold means the keys are being wiped, not held.
            cancelUnlockHold()
        }
    }

    private func beginUnlockHold() {
        guard unlockHoldStart == nil else { return }
        unlockHoldStart = .now
        unlockTask = Task {
            try? await Task.sleep(for: .seconds(Self.unlockHold))
            if !Task.isCancelled {
                unlock()
            }
        }
    }

    private func cancelUnlockHold() {
        unlockTask?.cancel()
        unlockTask = nil
        if unlockHoldStart != nil {
            unlockHoldStart = nil
        }
    }

    private func restoreCapsLock() {
        if let capsLockBeforeLock, CapsLock.isOn != capsLockBeforeLock {
            CapsLock.set(capsLockBeforeLock)
        }
    }
}
