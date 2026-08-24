# Validation record

Validation was performed on the actual Mac described in [PREFLIGHT.md](PREFLIGHT.md), not only with mocks. Temporary artifacts were written under `/private/tmp`; AwakeCat did not change any power, screen-saver, authentication, or security preference. Overall status is **PASS**: automatic idle-lock prevention and the physical Control-Command-Q safety check both passed on the actual Mac. An idle-system-sleep transition could not be independently observed because of the host's existing power configuration and unrelated sleep assertions; that evidence boundary is recorded below.

## Result summary

| Check | Result | Evidence |
| --- | --- | --- |
| SwiftPM Debug tests | Pass | 8 tests, 0 failures |
| SwiftPM Release tests | Pass | 8 tests, 0 failures |
| Xcode Debug tests | Pass | 8 tests, 0 failures |
| Xcode Release tests | Pass | 8 tests, 0 failures; test build used `ENABLE_TESTABILITY=YES` for `@testable import` |
| Debug build | Pass | SwiftPM and staged `.app` |
| Release build | Pass | SwiftPM and staged/ad-hoc-signed `.app` |
| Application icon | Pass | Opaque 16–1024 px asset catalog compiled to `Assets.car` and `AppIcon.icns`; Finder/Get Info verified in Light and Dark |
| Assertion acquisition | Pass | AwakeCat PID owns both named IOKit assertions |
| Assertion release | Pass | Neither AwakeCat name remains after Off/termination |
| Ten ON/OFF cycles | Pass | 10 acquisitions/releases; no AwakeCat assertion afterward |
| Actual idle automatic lock | Pass on this Mac | Eyes-open UI path, 660.5 s continuous HID idle, `IOConsoleLocked = No`; `loginwindow` records PM display-sleep protection suppressing idle launch |
| Screen saver defeating protection | Pass on this Mac | Normal logs launch at 600 s; Awake logs `PMNoDisplaySleepEnabled so do not launch screen saver` |
| Long-running process | Pass | AwakeCat remained responsive/running through the 660.5 s and 865 s idle observations |
| Crash cleanup | Pass | `SIGKILL` removed both process-owned assertions |
| Normal/Awake resources | Pass | Approximately 0% CPU/power, 11 MB, 3 threads in 10 samples per state |
| Manual Control-Command-Q | Pass | With Awake active, the physical shortcut entered Lock Screen normally; AwakeCat neither intercepted it nor attempted to unlock |
| Physical idle-system-sleep transition | Not independently observable | Host AC `sleep = 0`, `displaysleep = 0`, with unrelated processes also holding sleep assertions |

The final Xcode Release test invocation supplied `ENABLE_TESTABILITY=YES` as a test-only command-line build setting because the generated SwiftPM Xcode scheme otherwise hides `AwakeCatCore` from `@testable import` in Release. The separately staged production Release bundle was rebuilt afterward without that override.

## Automatic-lock acceptance test

The decisive run used the actual status-item button action via a Debug-only UI harness, then observed the real machine without changing its 600-second screen-saver preference:

```text
Mode:                  UI / eyes-open path
Wall time:             990 s (wait extended after incidental input)
Continuous HID idle:   660,515,356,000 ns (660.5 s)
Screen-saver idleTime: 600 before; 600 after
Console lock state:    IOConsoleLocked = No
Process state:         running
AwakeCat PID:          43226
```

At the end of the continuous-idle window, `pmset -g assertions` attributed exactly these entries to PID 43226:

```text
PreventUserIdleSystemSleep
  "AwakeCat: prevent automatic idle system sleep"
PreventUserIdleDisplaySleep
  "AwakeCat: keep display awake to prevent automatic idle lock"
```

After the app was stopped, neither AwakeCat assertion appeared, and `idleTime` was still 600. A second 660-second power-only run produced the same unlocked result, with 865 seconds of HID inactivity at capture.

The power evidence is corroborated by the macOS screen-saver decision logs:

```text
08:47:39 Normal: actualUserIdle = 600.0; starting screen saver due to user idle
08:47:39 Normal: processing lock screen request, reason: 3
10:10:58 Awake: PMNoDisplaySleepEnabled so do not launch screen saver
10:18:40 Awake: actualUserIdle = 423.7; PMNoDisplaySleepEnabled so do not launch screen saver
```

The final `pmset` sample at 10:22 listed AwakeCat as the only owner of `PreventUserIdleDisplaySleep`. A WindowServer `UserIsActive` record from the last UI event was also present, but `loginwindow` explicitly attributed its decision not to launch to the PM no-display-sleep state. In Normal mode, the same configured idle path reached 600 seconds, started the saver, and processed an immediate lock.

No screen-saver override was used or required on this tested Mac. The supported display assertion caused `loginwindow` to defer the idle screen saver, and Off restored the ordinary 600-second path without changing that preference.

## Toggle, quit, and crash cleanup

- A Debug harness exercised 10 ON/OFF cycles through the production coordinator. Every cycle logged one ON and one OFF; the final `pmset` scan contained no AwakeCat assertion names.
- Quitting while Normal left no assertion or preference change.
- Terminating while Awake removed both process-owned assertions.
- A forced `SIGKILL` while both assertions were visible also removed both. Since the production design has no persistent preference override, crash recovery is intentionally a no-op and repeated relaunches start Normal.

## Atomic failure behavior

Unit tests verify that the state becomes Awake only after successful acquisition, acquisition failure never renders Awake, a release failure retains the session for retry, and 10 controller cycles leave no active session. The IOKit implementation releases an already-created system assertion if display-assertion acquisition fails; if that rollback itself fails, it returns a retained cleanup session so the next click or Quit retries cleanup. Error uses a distinct one-eye-open glyph, never the authoritative closed-eye Normal glyph.

## Manual-lock safety

The production sources contain no `CGEvent`, event tap, `IOHID`, Accessibility injection, lock interception, authentication, password, or auto-unlock implementation. IOKit idle assertions do not implement explicit-lock interception.

A final physical Control-Command-Q test was completed while Awake mode was active. macOS entered Lock Screen normally. AwakeCat did not intercept or suppress the shortcut, bypass authentication, or attempt to unlock the session. Returning to the GUI session followed the user's ordinary macOS authentication/unlock path. Result: **PASS**.

An earlier read-only observation window had timed out before the shortcut was entered. That incomplete attempt is superseded by the completed physical test above. Synthetic shortcut injection was not used, and AwakeCat does not request Input Monitoring permission.

A separate explicit ScreenSaverEngine request at 10:39:27 was made while PID 52643 owned both AwakeCat assertions. `loginwindow` recorded a running screen saver and processed lock request reason 4. macOS then reported Apple Watch Auto Unlock; no AwakeCat process was involved in unlocking. This independently corroborates that explicit lock remains authoritative while Awake mode is active.

## Resource measurements

Ten one-second `top` samples in Normal and Awake showed:

```text
CPU:              0.0% in every Awake sample; 0.0% except one 0.1% Normal sample
Power impact:     0.0 in every Awake sample; 0.0 except one 0.1 Normal sample
Memory:           11 MB stable
Physical footprint: 11 MB
Threads:          3
CPU time:         unchanged at 0.09 s across the Awake sample
```

The Release sources have no repeating timer, polling loop, network path, analytics, or telemetry. Debug-only validation code may sleep for bounded test durations and is compiled out of Release.

## Caveats in the evidence

This Mac already used AC `sleep = 0` and `displaysleep = 0`, while unrelated processes held their own system-sleep assertions. Changing system-wide power settings solely to force a sleep transition would have been disruptive. Accordingly the report proves AwakeCat's display/system assertion ownership and the actual automatic-lock outcome, but a before/after physical idle-system-sleep transition was not independently observable on this host. This limitation does not alter the automatic-lock acceptance result or the verified ownership and cleanup of AwakeCat's native system-sleep assertion.
