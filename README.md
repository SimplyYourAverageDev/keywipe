# Keywipe

A small macOS 27 app that blocks the keyboard so you can wipe it down without typing
into whatever is open. The mouse and trackpad keep working.

## Build and run

Requires macOS 27 and the Xcode Command Line Tools (Swift 6.4). Xcode itself is not needed.

```sh
make app    # builds build/Keywipe.app
make run    # builds, then opens it
```

Move `build/Keywipe.app` to `/Applications` if you want to keep it around.

## First launch

Blocking keys before other apps see them needs one permission. Click **grant access**,
then switch Keywipe on under System Settings › Privacy & Security ›
**Device Control and Data Access** (called "Accessibility" before macOS 27). The window
changes to `ready` by itself once the permission is in place.

## Use

- **Lock:** click `lock keyboard` or press Return.
- **Unlock:** click `unlock`, or hold both ⌘ keys for two seconds.

Closing the window or quitting the app always releases the keyboard. While locked, the
window floats above other apps so the unlock button stays reachable, and Caps Lock is put
back to the state it had when you locked.

Keywipe counts the keys it catches but never records which ones they were.

## What it cannot block

- **Touch ID and the power button.** They never reach apps as key events.
- **Keys typed while another app holds Secure Event Input.** Password fields switch this
  on, and macOS then hides keystrokes from every other app. Keywipe refuses to lock while
  that is the case and names the app responsible; if it starts while the keyboard is
  locked, the window turns red and says keys are getting through.

## After rebuilding

The default build is signed ad hoc, so macOS treats every rebuild as a different app and
the permission stops applying, even though the switch in System Settings still looks on.
Remove Keywipe from the list with the minus button and grant access again, or run:

```sh
tccutil reset Accessibility com.azhua30.keywipe
```

To avoid this, sign with a certificate that stays the same between builds:

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name" make app
```

## Layout

| Path | Purpose |
| --- | --- |
| `Sources/Keywipe/KeyboardTap.swift` | The event tap that swallows keyboard events |
| `Sources/Keywipe/BlockedKey.swift` | Decides which events are keyboard events |
| `Sources/Keywipe/LockController.swift` | Lock state, permission checks, unlock gesture |
| `Sources/Keywipe/SystemKeyboard.swift` | Permission, Secure Event Input and Caps Lock access |
| `Sources/Keywipe/TerminalView.swift`, `Theme.swift` | The window |
| `Scripts/build-app.sh` | Assembles and signs the app bundle |
| `Scripts/make-icon.swift` | Draws the icon (`make icon`) |
