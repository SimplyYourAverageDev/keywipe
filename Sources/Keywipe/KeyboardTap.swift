import CoreGraphics
import Foundation

/// An active event tap at the HID level that swallows every keyboard event before the
/// system or any app sees it.
///
/// The tap is serviced on its own thread. macOS disables a tap whose callback is slow to
/// answer, which would let keystrokes through, so it must not share the main thread with
/// the interface.
final class KeyboardTap: @unchecked Sendable {
    private let onKey: @Sendable (BlockedKey) -> Void
    private let lock = NSLock()
    private var port: CFMachPort?
    private var runLoop: CFRunLoop?

    /// - Parameter onKey: Called on the tap's thread for each swallowed event.
    init(onKey: @escaping @Sendable (BlockedKey) -> Void) {
        self.onKey = onKey
    }

    /// Installs the tap and returns once it is live. Returns false when macOS refuses to
    /// create it, which is what happens without the accessibility permission.
    func start() -> Bool {
        if isInstalled { return true }

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<KeyboardTap>.fromOpaque(userInfo).takeUnretainedValue()
            return tap.handle(type: type, event: event)
        }
        guard
            let port = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: BlockedKey.eventMask,
                callback: callback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ),
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        else { return false }

        lock.withLock { self.port = port }

        // The thread keeps `self` alive until `stop()` ends its run loop, so the unretained
        // pointer handed to the callback stays valid for as long as the tap can fire.
        nonisolated(unsafe) let runLoopSource = source
        let running = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in
            let runLoop = CFRunLoopGetCurrent()!
            lock.withLock { self.runLoop = runLoop }
            CFRunLoopAddSource(runLoop, runLoopSource, .commonModes)
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) { running.signal() }
            CFRunLoopRun()
        }
        thread.name = "keywipe.tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        running.wait()
        return true
    }

    /// Removes the tap. Keyboard input flows normally again as soon as this returns.
    func stop() {
        let (port, runLoop) = lock.withLock {
            defer { (self.port, self.runLoop) = (nil, nil) }
            return (self.port, self.runLoop)
        }
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let runLoop {
            CFRunLoopStop(runLoop)
        }
    }

    var isInstalled: Bool {
        lock.withLock { port != nil }
    }

    /// False when the tap exists but macOS has switched it off, for example after sleep.
    var isEnabled: Bool {
        lock.withLock { port.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }
    }

    func enable() {
        lock.withLock {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            enable()
            return Unmanaged.passUnretained(event)
        }
        guard let key = BlockedKey(type: type, event: event) else {
            return Unmanaged.passUnretained(event)
        }
        onKey(key)
        return nil
    }
}
