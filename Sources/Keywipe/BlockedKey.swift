import AppKit
import Carbon.HIToolbox
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

    /// Classifies an event the tap received. Returns nil for the one kind that must pass
    /// through untouched: pointer button reports, which share the system-defined type.
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
            guard let nsEvent = NSEvent(cgEvent: event) else { break }
            let subtype = Int32(nsEvent.subtype.rawValue)
            if subtype == NX_SUBTYPE_AUX_MOUSE_BUTTONS { return nil }
            if subtype == NX_SUBTYPE_AUX_CONTROL_BUTTONS {
                // data1 packs the key code in the high word, then a state byte and a repeat bit.
                let keyCode = Int32((nsEvent.data1 & 0xFFFF_0000) >> 16)
                let isDown = (nsEvent.data1 & 0xFF00) >> 8 == 0x0A
                let isRepeat = nsEvent.data1 & 0x1 != 0
                // Caps Lock is counted here; its flagsChanged twin only triggers the restore.
                isPress = isDown && !isRepeat
                isCapsLock = keyCode == NX_KEYTYPE_CAPS_LOCK
            }

        default:
            return nil
        }
    }

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
