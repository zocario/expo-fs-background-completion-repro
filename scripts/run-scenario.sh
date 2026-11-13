#!/usr/bin/env bash
# Runs the scenario on a booted simulator and prints the [BGREPRO] log lines.
# Usage: scripts/run-scenario.sh <simulator udid> [terminate|background] [log file]
# Needs `node server/slow-server.mjs` running.
set -euo pipefail
UDID=${1:?simulator udid}
MODE=${2:-terminate}
LOG=${3:-scenario.log}
BUNDLE=dev.repro.bgcompletion

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl spawn "$UDID" log stream --level debug --style compact \
  --predicate 'eventMessage CONTAINS "[BGREPRO]"' > "$LOG" 2>&1 &
LOG_PID=$!
trap 'kill $LOG_PID 2>/dev/null || true' EXIT
sleep 2

echo "launching $BUNDLE with the upload auto-start"
xcrun simctl launch "$UDID" "$BUNDLE" -BGReproAutoStart YES
sleep 4

if [ "$MODE" = terminate ]; then
  echo "terminating the app; iOS relaunches it in the background when the upload finishes"
  xcrun simctl terminate "$UDID" "$BUNDLE"
else
  echo "sending the app to the background (opening Settings)"
  xcrun simctl launch "$UDID" com.apple.Preferences >/dev/null
fi

echo "waiting 75 s (server answers after 20 s, expo-file-system fallback is 25 s, watchdog is 28 s)"
sleep 75
kill $LOG_PID 2>/dev/null || true
grep -o '\[BGREPRO\].*' "$LOG" || echo "(no [BGREPRO] lines)"
