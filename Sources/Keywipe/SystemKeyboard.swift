import AppKit
import ApplicationServices
import Carbon.HIToolbox
import IOKit
import IOKit.hidsystem

/// The permission an active event tap needs. System Settings lists it as
/// "Device Control and Data Access" from macOS 27 and as "Accessibility" before that.
enum InputAccess {
    static let settingsName = "Device Control and Data Access"

    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt, which also adds the app to the list in System Settings.
    static func prompt() {
        // The literal is the value of kAXTrustedCheckOptionPrompt, which Swift 6 rejects
        // as shared mutable state.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openSettings() {
        let pane = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        if let url = URL(string: pane) {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Secure Event Input is what password fields switch on. While any app holds it, macOS
/// delivers keystrokes straight to the frontmost app and hides them from every event
/// tap, so the keyboard cannot be locked.
enum SecureInput {
    /// The name of the app holding secure input, or nil when it is off.
    static var holder: String? {
        guard IsSecureEventInputEnabled() else { return nil }
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        if let pid = session?["kCGSSessionSecureInputPID"] as? Int,
           let name = NSRunningApplication(processIdentifier: pid_t(pid))?.localizedName {
            return name
        }
        return "another app"
    }
}

enum CapsLock {
    static var isOn: Bool? {
        withHIDSystem { connection in
            var state = false
            let result = IOHIDGetModifierLockState(connection, Int32(kIOHIDCapsLockState), &state)
            return result == KERN_SUCCESS ? state : nil
        }
    }

    /// Sets both the lock state and the key's light.
    static func set(_ isOn: Bool) {
        _ = withHIDSystem { connection in
            IOHIDSetModifierLockState(connection, Int32(kIOHIDCapsLockState), isOn)
        }
    }

    private static func withHIDSystem<Result>(_ body: (io_connect_t) -> Result?) -> Result? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = IO_OBJECT_NULL
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection) == KERN_SUCCESS else {
            return nil
        }
        defer { IOServiceClose(connection) }
        return body(connection)
    }
}
