#!/usr/bin/env bash
# Applies (default) or reverts the proposed expo-file-system fix in node_modules.
# Usage: scripts/patch-expo-file-system.sh [apply|revert]   then rebuild with scripts/build-install.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PATCH=patches/expo-file-system-foreign-background-sessions.diff
if [ "${1:-apply}" = revert ]; then
  patch -R -d node_modules/expo-file-system -p1 < "$PATCH"
else
  patch -d node_modules/expo-file-system -p1 < "$PATCH"
fi
