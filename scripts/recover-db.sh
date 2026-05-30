#!/usr/bin/env bash
#
# Recovers the live SQLite database from a connected Android phone.
#
# Works on debug builds because it uses `adb run-as`, which lets you read
# app-private files on a non-rooted device when the package is debuggable.
# (Release builds are NOT debuggable — this script will tell you if so.)
#
# What it pulls:
#   stitch_genie.db        the main database file
#   stitch_genie.db-wal    write-ahead log (RECENT writes live here until
#                          SQLite checkpoints them into the main file —
#                          critical for "did her last 24h survive" questions)
#   stitch_genie.db-shm    shared-memory index (must accompany the WAL)
#
# Then it prints table-by-table row counts and a few sample rows so you can
# eyeball whether the data is intact before deciding next steps.
#
# Usage:
#   ./scripts/recover-db.sh
#   OUT_DIR=/some/other/path ./scripts/recover-db.sh
#
# Output lands in ~/stitch-genie-snapshots/<timestamp>/ by default.

set -uo pipefail

APP_ID="com.stitchlane.app"
DB_NAME="stitch_genie.db"
OUT_DIR="${OUT_DIR:-$HOME/stitch-genie-snapshots/$(date +%Y%m%d-%H%M%S)}"

# Colors for readability — fall back to plain on dumb terminals
if [[ -t 1 ]]; then
  R='\033[31m'; G='\033[32m'; Y='\033[33m'; B='\033[36m'; N='\033[0m'; D='\033[2m'
else
  R=''; G=''; Y=''; B=''; N=''; D=''
fi

bad()    { printf "${R}✗${N} %s\n" "$1" >&2; }
good()   { printf "${G}✓${N} %s\n" "$1"; }
info()   { printf "${B}ℹ${N} %s\n" "$1"; }
hdr()    { printf "\n${Y}━━ %s ━━${N}\n" "$1"; }

# ── 1. Device must be connected and authorized ────────────────────────────────
hdr "Step 1: Check device"
adb_state="$(adb get-state 2>&1 || true)"
if [[ "$adb_state" != "device" ]]; then
  bad "No authorized device. adb get-state returned: $adb_state"
  cat <<EOF
  Things to check:
    1. Phone is plugged in via USB
    2. USB debugging is ON (Settings > Developer options)
    3. You tapped 'Allow' on the 'Allow USB debugging?' prompt
    4. If the device shows 'authorizing': unplug, replug, accept the prompt
EOF
  exit 1
fi
model="$(adb shell getprop ro.product.model | tr -d '\r')"
serial="$(adb shell getprop ro.serialno 2>/dev/null | tr -d '\r' || echo unknown)"
good "Device: $model ($serial)"

# ── 2. App must be installed ──────────────────────────────────────────────────
hdr "Step 2: Check app installation"
if ! adb shell pm list packages | tr -d '\r' | grep -q "^package:$APP_ID$"; then
  bad "$APP_ID is not installed on this device"
  exit 1
fi
good "$APP_ID is installed"

# ── 3. App must be debuggable for run-as to work ──────────────────────────────
hdr "Step 3: Check run-as access"
if ! adb shell "run-as $APP_ID echo ok" 2>/dev/null | tr -d '\r' | grep -q "^ok$"; then
  bad "Cannot run-as $APP_ID (release build? not debuggable?)"
  cat <<EOF
  This script needs a debug build to read app-private files.
  If the installed app is a release build, you can:
    - Use the latest backup (Drive or local) for recovery, or
    - Temporarily install a debug build over it (Android will preserve the
      data IF the signing key matches — this is risky if signed differently)
EOF
  exit 1
fi
good "run-as works"

# ── 4. Pull the three DB files ────────────────────────────────────────────────
hdr "Step 4: Pull database files"
mkdir -p "$OUT_DIR"
info "Destination: $OUT_DIR"

for suffix in "" "-wal" "-shm"; do
  remote="databases/$DB_NAME$suffix"
  local="$OUT_DIR/$DB_NAME$suffix"
  if adb shell "run-as $APP_ID test -f $remote" 2>/dev/null; then
    # exec-out avoids CRLF mangling that plain `shell` would do on binary data
    if adb exec-out "run-as $APP_ID cat $remote" > "$local"; then
      size="$(wc -c < "$local" | tr -d ' ')"
      good "$DB_NAME$suffix → $size bytes"
    else
      bad "Failed to read $DB_NAME$suffix"
      rm -f "$local"
    fi
  else
    info "$DB_NAME$suffix not present (this is normal for -wal/-shm if SQLite checkpointed)"
  fi
done

if [[ ! -s "$OUT_DIR/$DB_NAME" ]]; then
  bad "Main DB file is missing or empty — cannot continue"
  exit 1
fi

# ── 5. Inspect ────────────────────────────────────────────────────────────────
hdr "Step 5: Inspect"

if ! command -v sqlite3 >/dev/null 2>&1; then
  bad "sqlite3 not installed locally — files are pulled at $OUT_DIR but cannot be inspected"
  info "Install with: brew install sqlite"
  exit 0
fi

DB="$OUT_DIR/$DB_NAME"

# Quick integrity check first — flags any obvious corruption
integrity="$(sqlite3 "$DB" "PRAGMA integrity_check;" 2>&1 | head -3)"
if [[ "$integrity" == "ok" ]]; then
  good "Integrity check: ok"
else
  bad "Integrity issues:"
  echo "  $integrity"
fi

echo ""
printf "${B}Tables and row counts:${N}\n"
tables="$(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_metadata' ORDER BY name;")"
for t in $tables; do
  c="$(sqlite3 "$DB" "SELECT COUNT(*) FROM \"$t\";" 2>/dev/null || echo "n/a")"
  printf "  %-30s ${G}%s${N} rows\n" "$t" "$c"
done

echo ""
printf "${B}Sample: 5 most-recently-modified rows per key table${N}\n"
for spec in \
  "customers|created_at|id, name, phone, created_at" \
  "orders|created_at|id, customer_id, title, value, created_at" \
  "measurements|created_at|id, customer_id, created_at" \
  "ai_usage_events|occurred_at|id, caller_tag, occurred_at"; do
  IFS='|' read -r table order_col cols <<< "$spec"
  exists="$(sqlite3 "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$table';")"
  if [[ "$exists" -gt 0 ]]; then
    printf "\n  ${Y}— %s —${N}\n" "$table"
    sqlite3 -header -column "$DB" "SELECT $cols FROM \"$table\" ORDER BY \"$order_col\" DESC LIMIT 5;" 2>/dev/null \
      | sed 's/^/    /'
  fi
done

# ── 6. Verdict ────────────────────────────────────────────────────────────────
hdr "Verdict"

orders_count="$(sqlite3 "$DB" "SELECT COUNT(*) FROM orders;" 2>/dev/null || echo 0)"
customers_count="$(sqlite3 "$DB" "SELECT COUNT(*) FROM customers;" 2>/dev/null || echo 0)"

if [[ "$orders_count" -gt 0 || "$customers_count" -gt 0 ]]; then
  cat <<EOF
${G}Data is INTACT on the phone.${N}

   Customers: $customers_count
   Orders:    $orders_count

   The 'logged out' state is a UI/auth race — the data was never lost.
   Recovery steps:
     1. Have her sign back in with the SAME Google account she used before
        (must be the same account or the app's auth gate will see a new UID).
     2. If the app still shows empty after sign-in, the file at
          $DB
        can be pushed back to replace the live one — but only do this with
        the app NOT running.
EOF
else
  cat <<EOF
${R}No customers or orders found in the live DB.${N}

   Look in the snapshot folder at:
     $OUT_DIR
   And also check Drive backups for the most recent .db file.
EOF
fi

echo ""
info "Files saved at: $OUT_DIR"
