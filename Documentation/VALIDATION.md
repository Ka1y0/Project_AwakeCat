# Validation

AwakeCat separates deterministic unit tests from native power-assertion checks and observations that require an idle or manually locked Mac. These checks do not change power, screen-saver, authentication, or login-item settings.

## Repeatable checks

Run from the repository root with the active Xcode toolchain:

```sh
swift package clean
swift test --configuration debug
swift test --configuration release
./script/build_and_run.sh --verify
CONFIGURATION=release ./script/build_and_run.sh --verify
codesign --verify --deep --strict dist/AwakeCat.app
```

The eight XCTest cases exercise initial state, successful and failed acquisition, retained partial cleanup, release retry, repeated toggles, recovery error reporting, and coordinator forwarding. No dedicated XCUITest target exists. `for script_path in script/*.sh; do bash -n "$script_path" || exit; done` checks shell syntax; no additional static-check tool is configured.

### Native integration hooks (Debug only)

Build Debug first. These explicit command-line hooks use the production coordinator without starting an AppKit UI, so invoking the executable directly is intentional here:

```sh
swift build --configuration debug
AWAKECAT_BINARY="$(swift build --configuration debug --show-bin-path)/AwakeCat"
"$AWAKECAT_BINARY" --validation-cycle 10
"$AWAKECAT_BINARY" --validation-awake-seconds 10
```

While the timed probe runs, inspect `pmset -g assertions` in another terminal. Match the probe PID and both exact names:

- `AwakeCat: prevent automatic idle system sleep`
- `AwakeCat: keep display awake to prevent automatic idle lock`

Neither assertion should remain for that PID afterward. A separate Debug hook, `--validation-crash-after-awake`, stops its own probe with `SIGSTOP` after acquiring both assertions so a test harness can inspect ownership, send `SIGKILL` to that exact probe PID, and verify OS cleanup. Do not target an unrelated or daily-use app process.

To exercise the real status-item button action, stage Debug and launch the bundle:

```sh
./script/build_and_run.sh --build-only
open -n dist/AwakeCat.app --args --validation-ui-awake
```

This performs the existing status-item button action and should acquire both assertions. Use the menu to disable protection and quit. All validation argument handlers and UI hooks are excluded from Release.

### Optional idle and manual-lock observations

These scripts need `rg` (ripgrep) in addition to the build requirements. Their outputs include system diagnostics; keep the output directories private and redact before sharing.

- `./script/validate_real_idle.sh ui`: requires a staged Debug bundle. It starts a probe and waits for at least 660 continuous seconds without keyboard/mouse input (up to 30 minutes), checking the unlocked session, assertion ownership, and unchanged screen-saver timer. It assumes the original 600-second idle timer; it is not a general acceptance test for a machine configured with another timer. `power-only` and `full` modes exercise the non-UI Debug hooks instead.
- `./script/observe_manual_lock.sh <AwakeCat-pid>`: with Awake enabled, waits up to three minutes for a person to press Control-Command-Q, checks that the session stays locked for ten seconds, and waits up to five minutes for manual unlock. It does not inject keys or unlock the Mac.

Both scripts create a unique directory in the system temporary location unless an output directory is supplied. The idle observer starts a separate process; quit other AwakeCat instances first because its final cleanup check expects no AwakeCat assertions to remain.

## Original device observations — 2026-08-24

The original implementation records report macOS 26.5.2 (25F84), Apple Silicon, Xcode 26.6 (17F113), Swift 6.3.3, and macOS SDK 26.5. These are historical observations, not measurements repeated on every build:

- Eight tests passed in SwiftPM Debug/Release and Xcode Debug/Release. Xcode Release tests used the test-only `ENABLE_TESTABILITY=YES` override; the separately built production bundle did not.
- A Debug status-item button probe stayed unlocked through 660.5 seconds of continuous HID inactivity with a 600-second screen-saver timer. Both named IOKit assertions were present. The macOS screen-saver logs attributed deferral to display-sleep protection. A separate power probe observed 865 seconds of inactivity with the same outcome.
- A physical Control-Command-Q test entered Lock Screen normally while Awake was active. Unlocking followed normal macOS authentication. AwakeCat neither intercepted the shortcut nor attempted authentication.
- Ten native ON/OFF cycles, termination, and forced-crash cleanup left no AwakeCat assertions.
- Finder/Get Info displayed the application icon in Light and Dark appearance. All ten source and compiled icon sizes were opaque RGB; Debug/Release bundle signatures verified.
- Ten one-second resource samples reported approximately 0% CPU, an 11 MB physical footprint, and three threads. These are short observations on one Mac, not performance guarantees.

The original host already had AC idle-system and display sleep disabled and other processes held sleep assertions. A physical idle-system-sleep transition could not be isolated. The evidence proves assertion ownership and the observed automatic-lock outcome on that machine, not a universal guarantee about managed policy, closed-lid behavior, every macOS version, or sleep transitions.

## Open-source publication validation — 2026-09-05

Environment: macOS 26.6.2 (25G83), Apple Silicon, Xcode 26.6 (17F113), Swift 6.3.3, macOS SDK 26.5. The application deployment target remains macOS 15.0.

| Check | Result |
| --- | --- |
| `swift package clean`, then `swift test --configuration debug` | Passed; 8 tests, 0 failures |
| `swift test --configuration release` | Passed; 8 tests, 0 failures |
| `xcodebuild -scheme AwakeCat-Package -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath <temporary-directory> test` | Passed; 8 tests, 0 failures |
| Same Xcode command with `-configuration Release ENABLE_TESTABILITY=YES` | Passed; 8 tests, 0 failures; test-only setting |
| `./script/build_and_run.sh --verify` | Debug build, icon compilation, ad-hoc signing, and launch passed |
| `CONFIGURATION=release ./script/build_and_run.sh --verify` | Release build, icon compilation, ad-hoc signing, and launch passed |
| Existing Debug native probes | 10 cycles, timed release, SIGTERM cleanup, and stopped-probe SIGKILL cleanup passed; both named assertions matched by PID |
| Existing `--validation-ui-awake` bundle hook | Status-item button action acquired both assertions; termination released both |
| `codesign --verify --deep --strict dist/AwakeCat.app` | Passed for Debug and Release; no signing identity or team required |
| Icon source and `assetutil --info` / `iconutil --convert iconset` | All 10 source sizes and compiled RGB/opaque renditions validated; all 10 ICNS representations unpacked |
| Bundle metadata and contents | Identifier, macOS minimum, icon keys, and MIT license verified; Release executable strings contain no Debug validation arguments or personal build path |
| Path portability | Fresh Release build through a temporary path alias containing spaces with `--scratch-path`; complete bundle script run from outside the checkout through the same alias passed |
| Repository checks | Every shell script passed `bash -n`; plist lint, Markdown local links, English documentation, and `git diff --check` passed |
| Secrets and history | Gitleaks 8.30.1 reported no leaks in full history or working tree; all original Git objects and PNG metadata were separately inspected |
| Dependencies and provenance | No third-party packages, vendored frameworks, fonts, certificates, provisioning profiles, or private signing material found; generated icon provenance reviewed |
| Preservation | Application Swift sources, tests, package manifest, and source icon hashes unchanged |

Xcode reported only its non-blocking App Intents metadata-extraction warning because the app has no AppIntents dependency. No compiler or asset-catalog warnings were found. The production Release bundle was built separately without the Xcode testability override.

The path test exposed an existing `PlistBuddy` merge failure with spaces in the checkout path. Bundle assembly now inserts the two generated icon keys with `plutil`, passing paths as separate quoted arguments. Debug and Release bundle checks were repeated after this fix. The path test used an alias to the canonical checkout, not a second project copy. Dependency inspection found only local targets and system libraries; the build scripts derive paths from their own location.

The original two commits remain intact, including their author attribution and historical Finder screenshots with the author's local username/project path. That existing author email was already present in the owner's public commit history. Current documentation omits those screenshots and machine-specific preflight details. No credential or sensitive signing artifact was found in historical content; the only unreachable Git object was an empty blob.

Fresh long-idle, physical Control-Command-Q, closed-lid, Intel, and Developer ID login-item tests were not performed in this pass. The historical observations above remain explicitly dated; no system sleep, security, or login-item preferences were changed.
