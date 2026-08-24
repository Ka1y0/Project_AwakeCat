# AwakeCat

AwakeCat is a deliberately small, menu-bar-only macOS utility for long local coding and automation sessions.

- Closed eyes mean **Normal**: AwakeCat owns no power assertions and macOS follows the user's existing idle behavior.
- Open eyes mean **Awake**: AwakeCat prevents automatic idle system sleep and keeps the display awake so this Mac does not reach its configured idle screen saver and lock path.
- Left-click the cat to toggle. Right-click or Control-click for status, Keep Awake, Launch at Login, About, and Quit.

AwakeCat starts in Normal every time. It never auto-unlocks, intercepts Control-Command-Q, changes authentication, bypasses lid-close sleep, or blocks an explicit user-requested sleep.

## How it works

AwakeCat acquires two process-owned IOKit assertions only after the user enables Awake:

- `kIOPMAssertionTypePreventUserIdleSystemSleep`
- `kIOPMAssertionTypePreventUserIdleDisplaySleep`

The app calls `IOPMAssertionCreateWithName` for both and does not show the open-eye state unless both calls succeed. A partial acquisition is rolled back. Toggling Off or quitting calls `IOPMAssertionRelease` for every acquired ID; macOS also removes process-owned assertions if the process crashes.

During an actual 660-second continuous-HID-inactivity observation against this Mac's configured 600-second screen-saver timer, the session remained unlocked and AwakeCat owned both assertions. macOS `loginwindow` logs supply the causal check: Normal mode reached 600 seconds and logged “starting screen saver due to user idle” before locking, whereas the Awake run logged `PMNoDisplaySleepEnabled so do not launch screen saver`. The final `pmset` capture contained no other user display-sleep assertion owner. This proves the automatic-lock outcome on this Mac despite a concurrent WindowServer `UserIsActive` record.

Manual-lock safety was also verified with a physical Control-Command-Q test while Awake was active: macOS entered Lock Screen normally, and AwakeCat neither intercepted the shortcut nor attempted to bypass authentication or unlock the session.

AwakeCat does **not** change `com.apple.screensaver`, password-delay, Touch ID, FileVault, or any other user/system preference. No temporary screen-saver override is implemented, and there is no recovery metadata because there is no persistent override to recover.

This is preferable to keeping a `caffeinate` child process alive: ownership and error handling stay in-process, assertion IDs are explicit, acquisition is atomic at the UI boundary, and cleanup does not depend on supervising another process.

## Privacy and footprint

AwakeCat is fully local. It has no network code, analytics, telemetry, account, updater, WebView, or third-party runtime dependency. There is no polling or repeating timer in the Release build. Ten-second idle samples measured 0.0% CPU in every Awake sample and all but one Normal sample (0.1%), three threads, and an 11 MB physical footprint.

## Build and run

Requirements: Apple Silicon Mac, macOS 15 or later, Xcode with Swift 6.2 or later.

```sh
swift test
./script/build_and_run.sh
```

The script builds and ad-hoc signs `dist/AwakeCat.app`. Set `CONFIGURATION=release` for a Release bundle:

```sh
env CONFIGURATION=release ./script/build_and_run.sh --verify
```

Launch at Login uses `SMAppService.mainApp`, is Off by default, and is available after placing a normally signed application bundle in Applications.

## Tested environment

- macOS 26.5.2 (25F84), Apple Silicon (`arm64`)
- Xcode 26.6 (17F113)
- Apple Swift 6.3.3
- macOS SDK 26.5
- deployment target: macOS 15.0

See [Documentation/PREFLIGHT.md](Documentation/PREFLIGHT.md) and [Documentation/VALIDATION.md](Documentation/VALIDATION.md) for the observed configuration and evidence.

## Known limitations

- Assertions apply only while AwakeCat is running and Awake is enabled. Managed/MDM policy, explicit Lock Screen, explicit sleep, and lid close remain authoritative.
- This Mac's existing AC `sleep` and `displaysleep` values were both `0`, and unrelated apps also held sleep assertions. Assertion ownership and the unlocked automatic-idle outcome were proved, but an idle-system-sleep transition could not be independently observed without changing broader power settings or disrupting the session.
