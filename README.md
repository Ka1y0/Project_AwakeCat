# AwakeCat

AwakeCat is a lightweight macOS menu-bar utility that keeps your Mac and display awake during long local work sessions. Click the cat when you need uninterrupted coding, processing, or automation; click again to let macOS follow its normal idle behavior. It is small, fully local, and starts with keep-awake protection off.

## Features

- One-click keep-awake toggle with distinct Normal, Awake, and Error icons.
- Native menu-bar controls, accessibility labels, and an optional Launch at Login setting.
- Process-owned power assertions, with cleanup on disable, quit, or process exit.
- No accounts, network services, analytics, updater, or third-party packages.

## Requirements

- macOS 15 or later.
- Xcode with Swift 6.2 or later and its macOS SDK; select it as the active developer directory.
- Apple Silicon is validated. The package does not restrict CPU architecture, but Intel Macs have not been validated.

## Build from source

```sh
git clone https://github.com/Ka1y0/Project_AwakeCat.git
cd Project_AwakeCat
swift test
./script/build_and_run.sh --verify
```

The script builds a Debug executable, compiles the app icon, stages `dist/AwakeCat.app`, ad-hoc signs it, and launches it. It stops an existing AwakeCat process before rebuilding; the new process starts in Normal.

For an optimized Release bundle without launching it:

```sh
CONFIGURATION=release ./script/build_and_run.sh --build-only
open dist/AwakeCat.app
```

Builds use the current checkout's location, including paths containing spaces. No Apple Developer account or private signing identity is needed for a local build. The bundle identifier remains `com.kuiyu.awakecat`.

To install your build, quit AwakeCat and copy `dist/AwakeCat.app` into Applications. This repository provides source and a local build workflow, not a notarized installer. Ad-hoc signing is not Developer ID signing or notarization; distributing a downloaded binary requires a separate signing and distribution workflow.

## Usage

- **Closed eyes / Normal:** AwakeCat holds no power assertions.
- **Open eyes / Awake:** both idle-system and idle-display assertions are active.
- **One eye open / Error:** protection or cleanup failed; click to retry, or open the menu for controls. Do not assume full protection in this state.
- **Left-click** toggles protection. **Right-click or Control-click** opens the menu with status, Keep Awake, Launch at Login, About, and Quit.

Launch at Login uses macOS `SMAppService.mainApp`. Install the app in Applications first; availability and approval are controlled by macOS in System Settings → General → Login Items. Registration is not enabled automatically, and local ad-hoc builds may not behave like a normally signed installed app. A login launch still starts in Normal.

## How AwakeCat keeps macOS awake

AwakeCat calls the public IOKit `IOPMAssertionCreateWithName` API for:

- `kIOPMAssertionTypePreventUserIdleSystemSleep`
- `kIOPMAssertionTypePreventUserIdleDisplaySleep`

The app shows Awake only after both succeed. A partial acquisition is rolled back; failed cleanup is retained for retry. Disabling protection or quitting releases the assertion IDs. macOS also removes process-owned assertions when the process exits, including a crash.

Keeping the display awake can defer the idle screen saver and its associated automatic lock. This was observed on the original test Mac, but is not a universal guarantee across macOS versions and managed policies. AwakeCat does not edit power settings, screen-saver timers, password delays, or authentication preferences. See the [validation record](Documentation/VALIDATION.md) for the evidence and its limits, and [Apple's display assertion documentation](https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridledisplaysleep) for the underlying API.

## Keyboard and system behavior

Control-Command-Q still locks the Mac. AwakeCat does not intercept keys, simulate input, unlock a session, or bypass authentication. The context menu has the standard Command-Q Quit item; there is no global keep-awake shortcut. Closing the lid, choosing Sleep, low battery, and system or management policy remain under macOS control.

## Project structure

| Path | Purpose |
| --- | --- |
| `Package.swift` | SwiftPM targets and macOS deployment target |
| `Sources/AwakeCat/` | AppKit entry point, menu-bar UI, login-item integration, Debug validation hooks |
| `Sources/AwakeCatCore/` | State controller and IOKit assertion ownership/cleanup |
| `Tests/AwakeCatCoreTests/` | State and coordinator tests |
| `Config/Info.plist` | App identity and bundle metadata |
| `Resources/Assets.xcassets/` | Application icon source representations |
| `script/` | Build/run and optional real-machine observations |

## Development and testing

Open `Package.swift` in Xcode for editing. Use the bundle script to run the menu-bar app with its metadata and icon. It accepts `--build-only`, `--verify`, `--debug` (LLDB), and `--logs` (local macOS log stream).

```sh
swift package clean
swift test --configuration debug
swift test --configuration release
./script/build_and_run.sh --build-only
CONFIGURATION=release ./script/build_and_run.sh --build-only
codesign --verify --deep --strict dist/AwakeCat.app
```

The eight unit tests cover state transitions, failed acquisition/cleanup, retry, and repeated toggles. They use fake providers; native assertion and UI checks are separate. There is no dedicated XCUITest target or configured third-party linter. See [Documentation/VALIDATION.md](Documentation/VALIDATION.md) for Debug integration commands and optional idle/manual-lock observations. Keep diagnostic logs local and remove personal data before sharing a bug report.

Contributions should keep the app small and preserve power-management and manual-lock behavior. Include the macOS/Xcode version, reproduction steps, and relevant test results with a change.

## Privacy

AwakeCat has no network code, analytics, telemetry, account, cloud dependency, or access to personal files. Release builds have no polling loop or repeating timer. Launch-at-login registration is handled locally by macOS. Optional developer scripts capture local system diagnostics; those files are not part of the application and should not be committed.

## Limitations

- Protection works only while AwakeCat is running and Awake is enabled. It is not restored automatically after relaunch.
- Closed-lid operation, explicit sleep, explicit lock, low-battery sleep, and managed-policy overrides are unsupported.
- An idle-display assertion does not turn on an already sleeping display.
- Keeping the display and system awake uses more energy; turn protection off when finished.
- Intel hardware, all supported macOS versions, and login-item behavior with a Developer ID signed build have not been validated in this publication pass.

## License

[MIT](LICENSE), copyright 2026 KAIYO (Ka1y0). There are no third-party package dependencies or bundled fonts. The application icon's generated-artwork provenance and licensing scope are recorded in [Documentation/APP_ICON.md](Documentation/APP_ICON.md). Apple frameworks and system components retain their own licenses.
