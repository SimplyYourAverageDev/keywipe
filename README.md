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

## Notes for coding agents

Read this before changing anything. It records constraints that are not visible from the
code alone.

### Installing an update

Run `make install` after a change. It builds, signs, quits a running Keywipe and replaces
`/Applications/Keywipe.app`. The owner has granted the keyboard permission to the
installed app and expects never to grant it again, so anything that changes the code
signature's requirement breaks that expectation:

- Do not delete, regenerate or move `.signing/`, and do not run `git clean -x`.
- Do not change the bundle identifier (`com.azhua30.keywipe`) in `Resources/Info.plist`.
- Do not sign ad hoc (`codesign --sign -`) or replace the signing step in
  `Scripts/build-app.sh`.
- Do not run `tccutil reset` for Keywipe unless the owner asks; it removes their grant.

To confirm a build still matches, compare `codesign -d -r- /Applications/Keywipe.app`
before and after. It should stay
`identifier "com.azhua30.keywipe" and certificate leaf = H"…"` with the same hash.

### Toolchain

Only the Xcode Command Line Tools are installed; there is no Xcode and no `xcodebuild`.

- SwiftUI macros whose plugins ship only with Xcode do not compile here: `@State`,
  `@Entry`, `@Animatable`, `#Preview`. Use the `ViewState` alias in `KeywipeApp.swift`
  in place of `@State`. `@Observable` works.
- There is no `actool`, so no asset catalogs. The icon is an `.icns` drawn by
  `Scripts/make-icon.swift` (`make icon`).
- The two `ld: warning: search path … not found` lines come from the toolchain install,
  not from this project. Any other warning is new.
- There are no third-party dependencies and no committed tests.

### Behaviour that must hold

- The keyboard can always be unlocked without the keyboard (the button), and the tap is
  removed on unlock, quit, and loss of the permission.
- The tap callback runs on its own thread and must return quickly. macOS disables a slow
  tap, which lets keystrokes through.
- Nothing on the tap's thread may call AppKit or the text input system. In particular,
  `NSEvent(cgEvent:)` crashes the app there when Caps Lock is pressed: macOS requires that
  code to run on the main thread. `BlockedKey.init` therefore reads a media key's subtype
  and data from the `CGEvent` through two field numbers (83 and 149) that Core Graphics
  does not name. If a later macOS moves them, media keys leak while locked; compare them
  against `NSEvent.subtype` and `NSEvent.data1` on the main thread to find the new ones.
- Pointer button reports share an event type with media keys and must pass through
  (`BlockedKey.init` returns nil for them), or the mouse stops working while locked.
- Which key was pressed is never stored or logged; only the count is kept.
- Interface text is lowercase, set in the system monospaced font, with one accent colour
  per state (`Theme.swift`).

### Testing a change

Locking for real blocks the owner's keyboard, so keep it to a few seconds and always end
by killing the process, which removes the tap.

- A binary started from a terminal inherits that terminal's permission, so
  `build/Keywipe.app/Contents/MacOS/Keywipe` can reach `ready` and lock without its own
  grant. The installed app uses its own grant.
- The window can be read and its buttons pressed through the Accessibility API
  (`AXUIElementCreateApplication`, `kAXPressAction`), and captured with
  `screencapture -l <window id>`.
- Post only inert synthetic keys, such as a lone modifier press, with
  `CGEvent.post(tap: .cghidEventTap)`. Never post letter keys: if the lock leaks, they
  are typed into whatever app is in front. The same goes for real media keys: a play key
  that is not blocked launches Music. Use Caps Lock (key type 4) or an unused key type
  such as 100 for media-style events.
- Send test events through the real tap, not only through `BlockedKey.init` called from
  the main thread. The Caps Lock crash was missed because of that.
- After a crash, the next launch shows a "reopen windows?" dialog in place of the window.

### Not yet verified

- Physical media keys, the Fn/Globe key and a physical Caps Lock press. They were tested
  as synthetic events or through the API only.
- The Secure Event Input states (refusing to lock, and the red warning while locked).
- That the System Settings link opens the right pane; the pane was already open when it
  was tried.
