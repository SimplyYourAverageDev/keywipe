import Carbon.HIToolbox
import CoreGraphics
import IOKit.hidsystem

/// What the tap reports about one keyboard event it swallowed.
///
/// It deliberately carries no key identity beyond what the unlock gesture and the
/// Caps Lock restore need, so nothing typed while locked is ever recorded.
struct BlockedKey: Sendable, Equatable {
    /// A fresh press, as opposed to a release or auto-repeat. Feeds the on-screen tally.
    var isPress = false
    /// Caps Lock changed state. The keyboard driver toggles it before any tap runs,
    /// so swallowing the event is not enough and the state has to be put back.
    var isCapsLock = false
    /// Modifier state after a modifier key moved; nil for every other event.
    var modifiers: Modifiers?

    struct Modifiers: Sendable, Equatable {
        var leftCommand: Bool
        var rightCommand: Bool
        /// Any of Shift, Control, Option or Fn is down.
        var others: Bool
    }
}

extension BlockedKey {
    /// Media, brightness, volume and the other special keys arrive as "system defined"
    /// events, which `CGEventType` has no case for.
    static let systemDefined = CGEventType(rawValue: UInt32(NX_SYSDEFINED))!

    static let eventMask: CGEventMask = [.keyDown, .keyUp, .flagsChanged, systemDefined]
        .reduce(0) { $0 | (1 << CGEventMask($1.rawValue)) }

    /// Classifies an event the tap received. Returns nil for what must pass through
    /// untouched: system-defined events that are not keys, such as pointer button reports.
    ///
    /// Runs on the tap's thread, so it must not touch AppKit or the text input system.
    init?(type: CGEventType, event: CGEvent) {
        switch type {
        case .keyDown:
            isPress = event.getIntegerValueField(.keyboardEventAutorepeat) == 0

        case .keyUp:
            break

        case .flagsChanged:
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            if keyCode == kVK_CapsLock {
                isCapsLock = true
            } else if let mask = Self.modifierMasks[keyCode] {
                isPress = flags.rawValue & mask != 0
            }
            modifiers = Modifiers(
                leftCommand: flags.rawValue & UInt64(NX_DEVICELCMDKEYMASK) != 0,
                rightCommand: flags.rawValue & UInt64(NX_DEVICERCMDKEYMASK) != 0,
                others: !flags.isDisjoint(with: [.maskShift, .maskControl, .maskAlternate, .maskSecondaryFn])
            )

        case Self.systemDefined:
            // Read from the event itself. `NSEvent(cgEvent:)` is the documented way to get
            // at these values, but for Caps Lock it calls into the text input system, which
            // traps when it is not on the main thread, and the tap runs on its own thread.
            let subtype = Int32(truncatingIfNeeded: event.getIntegerValueField(Self.subtypeField))
            guard Self.keyboardSubtypes.contains(subtype) else { return nil }
            if subtype == NX_SUBTYPE_AUX_CONTROL_BUTTONS {
                // data1 packs the key code in the high word, then a state byte and a repeat bit.
                let data1 = event.getIntegerValueField(Self.data1Field)
                let keyCode = Int32((data1 & 0xFFFF_0000) >> 16)
                let isDown = (data1 & 0xFF00) >> 8 == 0x0A
                let isRepeat = data1 & 0x1 != 0
                // Caps Lock is counted here; its flagsChanged twin only triggers the restore.
                isPress = isDown && !isRepeat
                isCapsLock = keyCode == NX_KEYTYPE_CAPS_LOCK
            }

        default:
            return nil
        }
    }

    /// Where a system-defined event keeps what `NSEvent` exposes as `subtype` and `data1`.
    /// Core Graphics has no named constants for these two fields; the numbers were found by
    /// comparing against `NSEvent` on macOS 27 (see the README before changing them).
    private static let subtypeField = CGEventField(rawValue: 83)!
    private static let data1Field = CGEventField(rawValue: 149)!

    /// The system-defined subtypes that come from keys. Everything else passes through,
    /// pointer button reports above all. Naming the ones to swallow, instead of the one to
    /// let through, means a wrong field number leaks media keys but leaves the mouse working.
    private static let keyboardSubtypes: Set<Int32> = [
        NX_SUBTYPE_POWER_KEY, NX_SUBTYPE_AUX_CONTROL_BUTTONS, NX_SUBTYPE_EJECT_KEY,
    ]

    /// The device-specific flag bit each modifier key sets while it is held, which tells
    /// a press from a release when the other key of the pair is also down.
    private static let modifierMasks: [Int: UInt64] = [
        kVK_Command: UInt64(NX_DEVICELCMDKEYMASK),
        kVK_RightCommand: UInt64(NX_DEVICERCMDKEYMASK),
        kVK_Shift: UInt64(NX_DEVICELSHIFTKEYMASK),
        kVK_RightShift: UInt64(NX_DEVICERSHIFTKEYMASK),
        kVK_Control: UInt64(NX_DEVICELCTLKEYMASK),
        kVK_RightControl: UInt64(NX_DEVICERCTLKEYMASK),
        kVK_Option: UInt64(NX_DEVICELALTKEYMASK),
        kVK_RightOption: UInt64(NX_DEVICERALTKEYMASK),
        kVK_Function: CGEventFlags.maskSecondaryFn.rawValue,
    ]
}
