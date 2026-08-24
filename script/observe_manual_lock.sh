#!/usr/bin/env bash
set -euo pipefail

AWAKECAT_PID="${1:?usage: observe_manual_lock.sh <AwakeCat-pid> [artifact-dir]}"
ARTIFACT_DIR="${2:-/private/tmp/AwakeCat_observed_manual_lock}"
MAX_LOCK_WAIT_SECONDS=180
MAX_UNLOCK_WAIT_SECONDS=300
RG_BIN="$(command -v rg)"

mkdir -p "$ARTIFACT_DIR"
/bin/kill -0 "$AWAKECAT_PID"
/usr/sbin/ioreg -n Root -d1 | "$RG_BIN" 'IOConsoleLocked' \
  > "$ARTIFACT_DIR/lock_state_before.txt"
/usr/bin/pmset -g assertions > "$ARTIFACT_DIR/assertions_before.txt"

WAITED_SECONDS=0
while ! /usr/sbin/ioreg -n Root -d1 | "$RG_BIN" -q '"IOConsoleLocked" = Yes'; do
  if [[ "$WAITED_SECONDS" -ge "$MAX_LOCK_WAIT_SECONDS" ]]; then
    /bin/echo "Timed out waiting for the user to lock the session." >&2
    exit 3
  fi
  /bin/sleep 1
  WAITED_SECONDS=$((WAITED_SECONDS + 1))
done

/usr/sbin/ioreg -n Root -d1 | "$RG_BIN" 'IOConsoleLocked' \
  > "$ARTIFACT_DIR/lock_state_detected.txt"
/bin/sleep 10
/usr/sbin/ioreg -n Root -d1 | "$RG_BIN" 'IOConsoleLocked' \
  > "$ARTIFACT_DIR/lock_state_after_10s.txt"
/usr/bin/pmset -g assertions > "$ARTIFACT_DIR/assertions_while_locked.txt"
/bin/kill -0 "$AWAKECAT_PID"

if ! /usr/sbin/ioreg -n Root -d1 | "$RG_BIN" -q '"IOConsoleLocked" = Yes'; then
  /bin/echo "The session was manually unlocked before the 10-second sample." >&2
  exit 4
fi

WAITED_SECONDS=0
while /usr/sbin/ioreg -n Root -d1 | "$RG_BIN" -q '"IOConsoleLocked" = Yes'; do
  if [[ "$WAITED_SECONDS" -ge "$MAX_UNLOCK_WAIT_SECONDS" ]]; then
    /bin/echo "Timed out waiting for manual unlock." >&2
    exit 5
  fi
  /bin/sleep 1
  WAITED_SECONDS=$((WAITED_SECONDS + 1))
done

/usr/sbin/ioreg -n Root -d1 | "$RG_BIN" 'IOConsoleLocked' \
  > "$ARTIFACT_DIR/lock_state_after_manual_unlock.txt"
/usr/bin/pmset -g assertions > "$ARTIFACT_DIR/assertions_after_manual_unlock.txt"
/bin/kill -0 "$AWAKECAT_PID"

/bin/echo "ARTIFACT_DIR=$ARTIFACT_DIR"
/bin/echo "PID=$AWAKECAT_PID"
/bin/echo "LOCK_DETECTED=$(/usr/bin/sed -n '1p' "$ARTIFACT_DIR/lock_state_detected.txt")"
/bin/echo "LOCKED_10S=$(/usr/bin/sed -n '1p' "$ARTIFACT_DIR/lock_state_after_10s.txt")"
/bin/echo "UNLOCKED=$(/usr/bin/sed -n '1p' "$ARTIFACT_DIR/lock_state_after_manual_unlock.txt")"
/bin/echo "PROCESS_STATE=running"
