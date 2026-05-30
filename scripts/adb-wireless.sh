#!/usr/bin/env bash
#
# adb-wireless.sh — connect an Android phone to adb over WiFi, the painless way.
#
# What makes this better than `adb tcpip 5555 && adb connect <ip>`:
#   - Detects the REAL reason a USB device isn't usable: 'authorizing',
#     'unauthorized', and 'offline' are diagnosed with phone-specific fixes
#     instead of a misleading "No USB device found".
#   - Auto-recovers a stuck handshake by restarting the adb server (the thing
#     that actually un-sticks an 'authorizing' device most of the time).
#   - Warns when the same phone is connected over BOTH USB and WiFi, which
#     makes plain `adb`/`flutter run` fail with "more than one device".
#
# Commands:
#   (none)       Connect the USB-attached phone over WiFi
#   status       Show all devices with their connection state
#   disconnect   Drop all wireless connections
#   reset        Restart the adb server (fixes most 'authorizing'/'offline' hangs)
#   help         Show usage

set -uo pipefail   # NOTE: intentionally NOT -e. We handle errors explicitly;
                   # -e + arithmetic/read/grep is a footgun in interactive scripts.

PORT=5555
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[info]${NC}  $1"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $1"; }
fail()  { echo -e "${RED}[fail]${NC}  $1"; }
step()  { echo -e "\n${BOLD}$1${NC}"; }

if ! command -v adb &>/dev/null; then
    fail "adb not found. Install Android SDK platform-tools:"
    fail "  brew install android-platform-tools"
    exit 1
fi

adb start-server &>/dev/null || true

# ── Device enumeration ────────────────────────────────────────────────────────
# A wireless serial looks like 192.168.x.y:5555. A USB serial does not contain
# a ':<port>'. We parse `adb devices` into "<serial>\t<state>" rows so callers
# can reason about state (device / authorizing / unauthorized / offline / ...).

_device_rows() {
    # Skip the "List of devices attached" header and blank lines.
    adb devices 2>/dev/null | tail -n +2 | awk 'NF >= 2 {print $1"\t"$2}'
}

is_wireless_serial() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; }

# Echoes USB serials in 'device' (usable) state, one per line.
usb_ready_serials() {
    while IFS=$'\t' read -r serial state; do
        [[ -z "$serial" ]] && continue
        is_wireless_serial "$serial" && continue
        [[ "$state" == "device" ]] && echo "$serial"
    done < <(_device_rows)
}

# Echoes "<serial>\t<state>" for USB serials NOT in 'device' state (the
# problem cases: authorizing / unauthorized / offline / no permissions).
usb_problem_rows() {
    while IFS=$'\t' read -r serial state; do
        [[ -z "$serial" ]] && continue
        is_wireless_serial "$serial" && continue
        [[ "$state" != "device" ]] && echo -e "$serial\t$state"
    done < <(_device_rows)
}

# Echoes "<serial>\t<state>" for wireless serials (any state).
wireless_rows() {
    while IFS=$'\t' read -r serial state; do
        [[ -z "$serial" ]] && continue
        is_wireless_serial "$serial" && echo -e "$serial\t$state"
    done < <(_device_rows)
}

wireless_ready_serials() {
    wireless_rows | awk -F'\t' '$2 == "device" {print $1}'
}

get_device_ips() {
    local serial="$1"
    adb -s "$serial" shell ip -4 addr 2>/dev/null \
        | grep 'inet ' \
        | grep -v '127.0.0.1' \
        | awk '{print $2}' \
        | cut -d/ -f1
}

get_mac_gateway() {
    route -n get default 2>/dev/null | grep 'gateway' | awk '{print $2}' || true
}

# Safe numeric picker. Echoes the chosen 1-based index on stdout, returns
# non-zero on bad/empty input.
pick_index() {
    local max="$1" prompt="${2:-   Pick}" pick
    read -rp "$prompt [1-$max]: " pick || return 1
    [[ "$pick" =~ ^[0-9]+$ ]] || { fail "Not a number: '$pick'"; return 1; }
    if (( pick < 1 || pick > max )); then
        fail "Out of range: $pick"
        return 1
    fi
    echo "$pick"
}

# ── 'authorizing'/'offline' recovery ──────────────────────────────────────────
# Restarting the adb server re-sends the RSA auth request, which is what
# actually makes the phone show the "Allow USB debugging?" prompt again.
restart_adb_server() {
    info "Restarting adb server to re-arm the auth handshake..."
    adb kill-server &>/dev/null || true
    sleep 1
    adb start-server &>/dev/null || true
    sleep 2
}

# Prints fix guidance for a phone that's plugged in but not in 'device' state,
# then optionally restarts the adb server and reports whether it recovered.
diagnose_usb_problem() {
    local rows="$1"
    warn "A phone is plugged in but not ready for adb:"
    echo "$rows" | while IFS=$'\t' read -r serial state; do
        echo "       $serial  ->  ${state}"
    done
    echo ""

    if echo "$rows" | grep -qiE "authorizing|unauthorized"; then
        echo "   This means adb is waiting for you to authorize the computer."
        echo "   On OnePlus / Oppo / ColorOS the prompt is easy to miss:"
        echo "     1. UNLOCK the phone and keep the screen on (prompt only shows when unlocked)."
        echo "     2. Pull down the notification shade -> tap the USB notification"
        echo "        -> choose 'File transfer' (charging-only mode hides the prompt)."
        echo "     3. Tap 'Allow' (check 'Always allow from this computer')."
        echo "     4. If no prompt ever appears: Developer Options ->"
        echo "        'Revoke USB debugging authorizations', then toggle USB debugging off/on."
        echo ""
    elif echo "$rows" | grep -qi "offline"; then
        echo "   'offline' usually means a stale connection or a flaky cable/port."
        echo "     1. Unplug and replug the cable (try a different port / known-data cable)."
        echo "     2. We'll restart the adb server below to clear the stale state."
        echo ""
    elif echo "$rows" | grep -qi "no permissions"; then
        echo "   'no permissions' is a host-side USB access issue."
        echo "     1. Try a different USB port."
        echo "     2. Ensure no other tool (Android Studio, scrcpy) is holding the device."
        echo ""
    fi

    read -rp "   Restart the adb server and re-check now? [Y/n] " ans || ans="n"
    if [[ ! "$ans" =~ ^[Nn] ]]; then
        restart_adb_server
        if [[ -n "$(usb_ready_serials)" ]]; then
            ok "Recovered — device is now authorized."
            return 0
        fi
        warn "Still not ready after restart. Do the on-phone steps above, then re-run."
    fi
    return 1
}

# ── Dual-transport warning ─────────────────────────────────────────────────────
# If a phone is reachable over BOTH USB and WiFi, plain `adb` / `flutter run`
# fail with "more than one device/emulator". Tell the user how to disambiguate.
warn_if_dual_transport() {
    local usb wireless
    usb=$(usb_ready_serials)
    wireless=$(wireless_ready_serials)
    if [[ -n "$usb" && -n "$wireless" ]]; then
        echo ""
        warn "This phone is connected over BOTH USB and WiFi."
        echo "   Plain 'adb' and 'flutter run' will fail with 'more than one device'."
        echo "   Fix it by EITHER:"
        echo "     - Unplugging the USB cable (keep the wireless link), or"
        echo "     - export ANDROID_SERIAL=$(echo "$wireless" | head -1)"
    fi
}

# ── Subcommands ────────────────────────────────────────────────────────────────
case "${1:-}" in
    status)
        step "ADB device status"
        rows=$(_device_rows)
        if [[ -z "$rows" ]]; then
            warn "No devices connected at all."
            exit 0
        fi
        echo "$rows" | while IFS=$'\t' read -r serial state; do
            kind="USB"
            is_wireless_serial "$serial" && kind="WiFi"
            case "$state" in
                device)        marker="${GREEN}ready${NC}" ;;
                authorizing)   marker="${YELLOW}authorizing — tap Allow on phone${NC}" ;;
                unauthorized)  marker="${YELLOW}unauthorized — tap Allow on phone${NC}" ;;
                offline)       marker="${RED}offline — replug / run: $(basename "$0") reset${NC}" ;;
                *)             marker="${RED}$state${NC}" ;;
            esac
            echo -e "   [$kind] $serial  ->  $marker"
        done
        warn_if_dual_transport
        exit 0
        ;;
    disconnect)
        step "Disconnecting all wireless devices"
        adb disconnect &>/dev/null || true
        ok "All wireless connections dropped."
        exit 0
        ;;
    reset)
        step "Resetting adb server"
        restart_adb_server
        ok "adb server restarted."
        "$0" status
        exit 0
        ;;
    help|--help|-h)
        echo -e "${BOLD}Usage:${NC} $(basename "$0") [command]"
        echo ""
        echo "Commands:"
        echo "  (none)       Connect the USB-attached phone over WiFi"
        echo "  status       Show all devices and their connection state"
        echo "  disconnect   Drop all wireless connections"
        echo "  reset        Restart the adb server (fixes most 'authorizing'/'offline' hangs)"
        echo "  help         Show this help"
        exit 0
        ;;
    "")
        : # fall through to main flow
        ;;
    *)
        fail "Unknown command: $1"
        echo "   Run '$(basename "$0") help' for usage."
        exit 1
        ;;
esac

# ── Main flow: connect over WiFi ───────────────────────────────────────────────

step "1. Checking for existing wireless connections"
existing=$(wireless_ready_serials)
if [[ -n "$existing" ]]; then
    ok "Already connected wirelessly:"
    echo "$existing" | while read -r s; do echo "       $s"; done
    echo ""
    read -rp "   Reconnect anyway? [y/N] " answer || answer="n"
    if [[ ! "$answer" =~ ^[Yy] ]]; then
        info "Keeping existing connection."
        warn_if_dual_transport
        exit 0
    fi
    adb disconnect &>/dev/null || true
fi

step "2. Looking for a USB device"
usb_ready=$(usb_ready_serials)

if [[ -z "$usb_ready" ]]; then
    problems=$(usb_problem_rows)
    if [[ -n "$problems" ]]; then
        # Plugged in but not authorized/offline — diagnose and maybe recover.
        if diagnose_usb_problem "$problems"; then
            usb_ready=$(usb_ready_serials)
        fi
    fi
fi

if [[ -z "$usb_ready" ]]; then
    if [[ -z "$(usb_problem_rows)" ]]; then
        fail "No USB device found at all."
        echo ""
        echo "   Checklist:"
        echo "   1. Is the phone plugged in via USB?"
        echo "   2. Is USB debugging ON? (Settings > Developer Options)"
        echo "   3. Set the USB connection to 'File transfer' (not charge-only)."
        echo "   4. Try a different cable/port — charge-only cables won't work."
    fi
    exit 1
fi

# Pick a USB device if there are several.
count=$(echo "$usb_ready" | wc -l | tr -d ' ')
if (( count > 1 )); then
    warn "Multiple USB devices found:"
    mapfile -t serials <<< "$usb_ready"
    for i in "${!serials[@]}"; do
        echo "   [$((i+1))] ${serials[$i]}"
    done
    echo ""
    pick=$(pick_index "${#serials[@]}" "   Pick a device") || exit 1
    serial="${serials[$((pick-1))]}"
else
    serial="$usb_ready"
fi
ok "Using device: $serial"

step "3. Getting device IP"
all_ips=$(get_device_ips "$serial")
gateway=$(get_mac_gateway)

if [[ -z "$all_ips" ]]; then
    fail "Could not read any IP from the device."
    echo ""
    echo "   Checklist:"
    echo "   1. Is WiFi (or hotspot) turned ON on the phone?"
    echo "   2. Phone and computer must be on the same network."
    exit 1
fi

# Prefer the IP on the same /24 as the Mac's gateway.
ip=""
if [[ -n "$gateway" ]]; then
    gateway_subnet=$(echo "$gateway" | cut -d. -f1-3)
    while IFS= read -r candidate; do
        [[ "$(echo "$candidate" | cut -d. -f1-3)" == "$gateway_subnet" ]] && { ip="$candidate"; break; }
    done <<< "$all_ips"
fi

if [[ -z "$ip" ]]; then
    ip_count=$(echo "$all_ips" | wc -l | tr -d ' ')
    if (( ip_count == 1 )); then
        ip="$all_ips"
    else
        warn "Multiple IPs found; couldn't auto-pick the one on your Mac's network:"
        mapfile -t ip_list <<< "$all_ips"
        for i in "${!ip_list[@]}"; do
            echo "   [$((i+1))] ${ip_list[$i]}"
        done
        [[ -n "$gateway" ]] && info "Mac's gateway: $gateway"
        echo ""
        pick=$(pick_index "${#ip_list[@]}" "   Pick the IP on your Mac's network") || exit 1
        ip="${ip_list[$((pick-1))]}"
    fi
fi

ok "Using device IP: $ip"
[[ -n "$gateway" ]] && info "Mac's gateway: $gateway"

step "4. Switching device to TCP/IP mode (port $PORT)"
if ! output=$(adb -s "$serial" tcpip "$PORT" 2>&1); then
    fail "Failed to switch to TCP/IP mode."
    echo "   adb output: $output"
    exit 1
fi
ok "TCP/IP mode enabled."
sleep 1

step "5. Connecting wirelessly to $ip:$PORT"
output=$(adb connect "$ip:$PORT" 2>&1)
if echo "$output" | grep -qi "connected"; then
    ok "$output"
else
    fail "Connection failed: $output"
    echo ""
    echo "   Checklist:"
    echo "   1. Are phone and computer on the SAME WiFi network?"
    echo "   2. Is a firewall blocking port $PORT?"
    echo "   3. Try: adb disconnect && adb connect $ip:$PORT"
    exit 1
fi

step "6. Verifying wireless connection"
sleep 1
if wireless_ready_serials | grep -q "^$ip:"; then
    ok "Wireless connection verified!"
else
    warn "Connected but verification unclear. Run: $(basename "$0") status"
fi

echo ""
echo -e "${GREEN}${BOLD}Done!${NC} You can unplug the USB cable now."
warn_if_dual_transport
echo ""
echo "   Reconnect later:  adb connect $ip:$PORT"
echo "   Check status:     $(basename "$0") status"
echo "   Disconnect:       $(basename "$0") disconnect"
