# Preflight evidence

Captured read-only on 2026-08-24 before implementation. The target directory did not exist; no unrelated work was overwritten. No setting was changed during preflight.

## Toolchain and platform

```text
ProductName:    macOS
ProductVersion: 26.5.2
BuildVersion:   25F84
Architecture:   arm64
Xcode:          26.6 (17F113)
Swift:          Apple Swift 6.3.3
Swift target:   arm64-apple-macosx26.0
macOS SDK:      26.5
SDK path:       /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk
```

## Existing power and idle configuration

`pmset -g custom` reported the following relevant AC values:

```text
sleep        0
displaysleep 0
disksleep    0
```

The current-host screen-saver idle preference was present as an integer:

```text
com.apple.screensaver idleTime = 600
```

`sysadminctl -screenLock status` reported:

```text
screenLock delay is immediate
```

`profiles status -type enrollment` reported neither DEP nor MDM enrollment. No relevant configuration profile was found in the read-only profile inspection.

## Lock-path diagnosis

The evidence points to a 600-second idle screen-saver activation followed by immediate screen lock. It does not point to display sleep on AC because `displaysleep` is already zero. A Normal-mode observation subsequently reached the lock screen at roughly this interval, which corroborates the diagnosis.

The system-wide assertion baseline contained unrelated assertions from `powerd`, ChatGPT, Xcode/test processes, and other services. Consequently validation matches AwakeCat by PID and its two exact assertion names rather than treating aggregate `pmset` counts as proof.
