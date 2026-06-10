#!/usr/bin/env bash
#
# run.sh — thin shim. The logic now lives in the `adbw` Python package, so adb
# device resolution has ONE source of truth (shared with adb-wireless.py)
# instead of being duplicated here in bash. See: adbw/commands.py -> cmd_run().
#
# Same interface as before — extra args pass straight to `flutter run`:
#   ./scripts/run.sh                 # debug, USB-first (wireless fallback)
#   WIFI=1 ./scripts/run.sh          # force wireless (skip USB)
#   ./scripts/run.sh --release       # release
#   ./scripts/run.sh -t lib/foo.dart # custom entrypoint
#
# Env:  PORT (adb tcp port, default 5555), WIFI=1, SNAPSHOT=1
# Files: scripts/.usb-skip — serials/models whose USB install hangs (auto-wifi)
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/.venv/bin/python3"
[[ -x "$PY" ]] || PY="python3"
exec "$PY" "$SCRIPT_DIR/adb-wireless.py" run "$@"
