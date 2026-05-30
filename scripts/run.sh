#!/usr/bin/env bash
#
# run.sh — `flutter run` against the phone over WiFi, with zero device fiddling.
#
# Resolution order (first that works wins):
#   1. A wireless device already in 'device' state            -> use it
#   2. The cached IP from a previous run (adb connect)         -> use it
#   3. A USB device: read its WiFi IP, switch to tcpip, connect -> use it, cache IP
#
# After step 3 happens once, every later run is pure WiFi (step 2) — no cable,
# no 'authorizing' dance. Any extra args are passed straight to flutter run:
#
#   ./scripts/run.sh                 # debug
#   ./scripts/run.sh --release       # release
#   ./scripts/run.sh -t lib/foo.dart # custom entrypoint
#
# Env:
#   PORT       adb tcp port (default 5555)
#   SNAPSHOT=1 pull a DB snapshot off the phone before running (data safety)

set -uo pipefail

PORT="${PORT:-5555}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../app"
CACHE_FILE="$SCRIPT_DIR/.last-wireless-device"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info() { echo -e "${CYAN}[info]${NC}  $1"; }
ok()   { echo -e "${GREEN}[ok]${NC}    $1"; }
warn() { echo -e "${YELLOW}[warn]${NC}  $1"; }
fail() { echo -e "${RED}[fail]${NC}  $1"; }
step() { echo -e "\n${BOLD}$1${NC}"; }

command -v adb     &>/dev/null || { fail "adb not found (brew install android-platform-tools)"; exit 1; }
command -v flutter &>/dev/null || { fail "flutter not found in PATH"; exit 1; }

adb start-server &>/dev/null || true

is_wireless() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; }

_rows() { adb devices 2>/dev/null | tail -n +2 | awk 'NF >= 2 {print $1"\t"$2}'; }

first_wireless_ready() {
    while IFS=$'\t' read -r serial state; do
        [[ -z "$serial" ]] && continue
        is_wireless "$serial" && [[ "$state" == "device" ]] && { echo "$serial"; return; }
    done < <(_rows)
}

first_usb_ready() {
    while IFS=$'\t' read -r serial state; do
        [[ -z "$serial" ]] && continue
        is_wireless "$serial" && continue
        [[ "$state" == "device" ]] && { echo "$serial"; return; }
    done < <(_rows)
}

# Run a command with a timeout (macOS has no `timeout`). Returns the command's
# exit code, or 124 if it was killed for taking too long.
with_timeout() {
    local secs="$1"; shift
    "$@" &
    local cmd_pid=$!
    ( sleep "$secs"; kill -TERM "$cmd_pid" 2>/dev/null ) &
    local killer=$!
    wait "$cmd_pid" 2>/dev/null
    local rc=$?
    kill "$killer" 2>/dev/null; wait "$killer" 2>/dev/null
    return "$rc"
}

# Best WiFi IP for a USB serial: prefer the one on the Mac's subnet.
device_wifi_ip() {
    local serial="$1"
    local ips gateway gw_subnet
    ips=$(adb -s "$serial" shell ip -4 addr 2>/dev/null \
          | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1)
    [[ -z "$ips" ]] && return 1
    gateway=$(route -n get default 2>/dev/null | awk '/gateway/{print $2}')
    if [[ -n "$gateway" ]]; then
        gw_subnet=$(echo "$gateway" | cut -d. -f1-3)
        while IFS= read -r ip; do
            [[ "$(echo "$ip" | cut -d. -f1-3)" == "$gw_subnet" ]] && { echo "$ip"; return; }
        done <<< "$ips"
    fi
    echo "$ips" | head -1   # fallback: first IP
}

# Verify a serial is actually responsive (props readable), not just listed.
is_responsive() {
    local serial="$1" model
    model=$(adb -s "$serial" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    [[ -n "$model" ]]
}

SERIAL=""

step "1. Looking for an existing wireless device"
SERIAL="$(first_wireless_ready)"
if [[ -n "$SERIAL" ]] && is_responsive "$SERIAL"; then
    ok "Using wireless device: $SERIAL"
else
    SERIAL=""
fi

if [[ -z "$SERIAL" && -f "$CACHE_FILE" ]]; then
    cached="$(cat "$CACHE_FILE" 2>/dev/null)"
    if [[ -n "$cached" ]]; then
        step "2. Reconnecting to cached device ($cached)"
        adb connect "$cached" &>/dev/null || true
        sleep 1
        if is_responsive "$cached"; then
            SERIAL="$cached"
            ok "Reconnected: $SERIAL"
        else
            warn "Cached device didn't answer — will try USB bootstrap."
        fi
    fi
fi

if [[ -z "$SERIAL" ]]; then
    step "3. Bootstrapping wireless from USB"
    usb="$(first_usb_ready)"
    if [[ -z "$usb" ]]; then
        fail "No wireless or USB device available."
        echo ""
        echo "   To bootstrap WiFi, plug the phone in via USB once with debugging on:"
        echo "     - USB mode = File Transfer (not charge-only)"
        echo "     - Tap 'Allow' on the USB-debugging prompt"
        echo "   Then re-run. After that, future runs reconnect over WiFi with no cable."
        exit 1
    fi
    ok "USB device: $usb"

    ip="$(device_wifi_ip "$usb")"
    if [[ -z "$ip" ]]; then
        fail "Couldn't read the phone's WiFi IP. Is WiFi on, same network as the Mac?"
        exit 1
    fi
    info "Phone WiFi IP: $ip"

    # `adb tcpip` can hang on a flaky USB link even though it takes effect on
    # the phone — so we time-box it and proceed to connect regardless.
    info "Switching phone to TCP/IP mode (port $PORT)..."
    with_timeout 6 adb -s "$usb" tcpip "$PORT" &>/dev/null || \
        warn "tcpip command didn't return cleanly — trying to connect anyway."
    sleep 2

    target="$ip:$PORT"
    adb connect "$target" &>/dev/null || true
    sleep 1
    if is_responsive "$target"; then
        SERIAL="$target"
        ok "Wireless connected: $SERIAL"
    else
        fail "Could not establish a wireless connection to $target."
        echo "   Try: adb connect $target"
        exit 1
    fi
fi

# Cache the IP for next time (only wireless serials are worth caching).
if is_wireless "$SERIAL"; then
    echo "$SERIAL" > "$CACHE_FILE"
fi

# Optional pre-run DB snapshot (data safety). Pulls the app DB off the phone
# into ~/stitch-genie-snapshots/ before launching. Opt-in via SNAPSHOT=1.
if [[ "${SNAPSHOT:-0}" == "1" && -x "$SCRIPT_DIR/recover-db.sh" ]]; then
    step "Pulling a pre-run DB snapshot"
    ANDROID_SERIAL="$SERIAL" "$SCRIPT_DIR/recover-db.sh" || \
        warn "Snapshot failed — continuing with run anyway."
fi

step "Launching: flutter run -d $SERIAL ${*:-}"
cd "$APP_DIR" || { fail "Cannot cd to app dir: $APP_DIR"; exit 1; }
exec flutter run -d "$SERIAL" "$@"
