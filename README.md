# Keywipe

A small macOS 27 app that blocks the keyboard so you can wipe it down without typing
into whatever is open. The mouse and trackpad keep working.

## Build and run

Requires macOS 27 and the Xcode Command Line Tools (Swift 6.4). Xcode itself is not needed.

```sh
make install    # builds, then installs to /Applications/Keywipe.app
make app        # only builds build/Keywipe.app
make run        # builds, then opens the copy in build/
```

Run `make install` again after changing the code to update the installed app.

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

## Signing and the permission

macOS ties the permission to the app's code signature, not to its name or location. So
that an updated build keeps the permission, every build is signed with the same
self-signed certificate. `Scripts/signing-identity.sh` creates it on the first build and
stores it in `.signing/`, a keychain file inside this folder that is not checked in and is
not added to your keychain list.

Keep `.signing/`. If it is deleted (`make clean` leaves it alone, `git clean -x` does
not), the next build gets a new certificate and macOS no longer recognises the app. The
switch in System Settings still looks on in that case; clear it and grant access again:

```sh
tccutil reset Accessibility com.azhua30.keywipe
```

Anything signed with that certificate under Keywipe's identifier is treated by macOS as
Keywipe, so treat `.signing/` as private to this Mac.

To sign with a certificate from your own keychain instead:

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name" make install
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
| `Scripts/signing-identity.sh` | Creates and unlocks the local signing certificate |
| `Scripts/make-icon.swift` | Draws the icon (`make icon`) |
