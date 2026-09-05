#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-power-only}"
ARTIFACT_DIR="${2:-$(mktemp -d "${TMPDIR:-/tmp}/AwakeCat_idle.XXXXXX")}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWAKECAT_BINARY="$(swift build --package-path "$ROOT_DIR" --configuration debug --show-bin-path)/AwakeCat"
TARGET_IDLE_SECONDS=660
MAX_WAIT_SECONDS=1800
RG_BIN="$(command -v rg)"
PROBE_PID=""
UI_MODE=0

case "$MODE" in
  power-only)
    VALIDATION_ARGUMENT="--validation-power-only-seconds"
    ;;
  full)
    VALIDATION_ARGUMENT="--validation-awake-seconds"
    ;;
  ui)
    UI_MODE=1
    VALIDATION_ARGUMENT="--validation-ui-awake"
    ;;
  *)
    /bin/echo "usage: $0 [power-only|full|ui] [artifact-dir]" >&2
    exit 2
    ;;
esac

mkdir -p "$ARTIFACT_DIR"
/usr/bin/defaults -currentHost read com.apple.screensaver idleTime \
  > "$ARTIFACT_DIR/idle_time_before.txt"

cleanup() {
  if [[ -n "$PROBE_PID" ]]; then
    /bin/kill -TERM "$PROBE_PID" >/dev/null 2>&1 || true
    wait "$PROBE_PID" >/dev/null 2>&1 || true
  fi
  if [[ "$MODE" == "full" ]]; then
    "$AWAKECAT_BINARY" --validation-restore-only >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT HUP INT TERM

if [[ "$UI_MODE" -eq 1 ]]; then
  if ! /usr/bin/strings "$ROOT_DIR/dist/AwakeCat.app/Contents/MacOS/AwakeCat" \
    | "$RG_BIN" -- '--validation-ui-awake' > "$ARTIFACT_DIR/ui_validation_hook.txt"; then
    /bin/echo "UI mode requires a staged Debug bundle with validation hooks." >&2
    exit 12
  fi
  "$ROOT_DIR/dist/AwakeCat.app/Contents/MacOS/AwakeCat" "$VALIDATION_ARGUMENT" \
    > "$ARTIFACT_DIR/awakecat_process.log" 2>&1 &
else
  "$AWAKECAT_BINARY" "$VALIDATION_ARGUMENT" "$MAX_WAIT_SECONDS" \
    > "$ARTIFACT_DIR/awakecat_process.log" 2>&1 &
fi
PROBE_PID=$!

/bin/sleep 1
/usr/bin/pmset -g assertions > "$ARTIFACT_DIR/assertions_on.txt"

if ! "$RG_BIN" -q "pid $PROBE_PID\\(AwakeCat\\).*PreventUserIdleSystemSleep.*AwakeCat: prevent automatic idle system sleep" \
  "$ARTIFACT_DIR/assertions_on.txt"; then
  /bin/echo "AwakeCat does not own the expected system-idle assertion." >&2
  exit 5
fi
if ! "$RG_BIN" -q "pid $PROBE_PID\\(AwakeCat\\).*PreventUserIdleDisplaySleep.*AwakeCat: keep display awake to prevent automatic idle lock" \
  "$ARTIFACT_DIR/assertions_on.txt"; then
  /bin/echo "AwakeCat does not own the expected display-idle assertion." >&2
  exit 6
fi

START_SECONDS=$SECONDS
while true; do
  if ! /bin/kill -0 "$PROBE_PID" >/dev/null 2>&1; then
    /bin/echo "AwakeCat exited before the observation window completed." >&2
    exit 4
  fi

  ELAPSED_SECONDS=$((SECONDS - START_SECONDS))
  HID_IDLE_NANOSECONDS="$(/usr/sbin/ioreg -r -c IOHIDSystem | /usr/bin/sed -n 's/.*"HIDIdleTime" = \([0-9][0-9]*\).*/\1/p')"
  HID_IDLE_SECONDS=$((HID_IDLE_NANOSECONDS / 1000000000))

  if [[ "$ELAPSED_SECONDS" -ge "$TARGET_IDLE_SECONDS" && "$HID_IDLE_SECONDS" -ge "$TARGET_IDLE_SECONDS" ]]; then
    break
  fi
  if [[ "$ELAPSED_SECONDS" -ge "$MAX_WAIT_SECONDS" ]]; then
    /bin/echo "Timed out waiting for 660 continuous seconds of inactivity." >&2
    exit 3
  fi
  /bin/sleep 2
done

/usr/sbin/ioreg -n Root -d1 | "$RG_BIN" 'IOConsoleLocked' \
  > "$ARTIFACT_DIR/lock_state_at_660s.txt"
/usr/sbin/ioreg -r -c IOHIDSystem | "$RG_BIN" 'HIDIdleTime' \
  > "$ARTIFACT_DIR/hid_idle_at_660s.txt"
/usr/bin/pmset -g assertions > "$ARTIFACT_DIR/assertions_at_660s.txt"
/bin/echo "$ELAPSED_SECONDS" > "$ARTIFACT_DIR/elapsed_seconds.txt"
/bin/kill -0 "$PROBE_PID"
/bin/echo "running" > "$ARTIFACT_DIR/process_state_at_660s.txt"

if ! "$RG_BIN" -q '"IOConsoleLocked" = No' "$ARTIFACT_DIR/lock_state_at_660s.txt"; then
  /bin/echo "The GUI session is locked after the idle observation window." >&2
  exit 7
fi
if ! "$RG_BIN" -q "pid $PROBE_PID\\(AwakeCat\\).*PreventUserIdleSystemSleep.*AwakeCat: prevent automatic idle system sleep" \
  "$ARTIFACT_DIR/assertions_at_660s.txt"; then
  /bin/echo "The system-idle assertion did not survive the observation window." >&2
  exit 8
fi
if ! "$RG_BIN" -q "pid $PROBE_PID\\(AwakeCat\\).*PreventUserIdleDisplaySleep.*AwakeCat: keep display awake to prevent automatic idle lock" \
  "$ARTIFACT_DIR/assertions_at_660s.txt"; then
  /bin/echo "The display-idle assertion did not survive the observation window." >&2
  exit 9
fi

cleanup
PROBE_PID=""
trap - EXIT HUP INT TERM

/usr/bin/defaults -currentHost read com.apple.screensaver idleTime \
  > "$ARTIFACT_DIR/idle_time_after.txt"
/usr/bin/pmset -g assertions > "$ARTIFACT_DIR/assertions_off.txt"

if ! /usr/bin/cmp -s "$ARTIFACT_DIR/idle_time_before.txt" "$ARTIFACT_DIR/idle_time_after.txt"; then
  /bin/echo "The screen-saver idleTime preference changed during validation." >&2
  exit 10
fi
if "$RG_BIN" -q 'AwakeCat:' "$ARTIFACT_DIR/assertions_off.txt"; then
  /bin/echo "An AwakeCat assertion remains after cleanup." >&2
  exit 11
fi

/bin/echo "ARTIFACT_DIR=$ARTIFACT_DIR"
/bin/echo "MODE=$MODE"
/bin/echo "LOCK_STATE=$(/usr/bin/sed -n '1p' "$ARTIFACT_DIR/lock_state_at_660s.txt")"
/bin/echo "ELAPSED_SECONDS=$ELAPSED_SECONDS"
/bin/echo "IDLE_TIME_AFTER=$(/usr/bin/sed -n '1p' "$ARTIFACT_DIR/idle_time_after.txt")"
