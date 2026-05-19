#!/usr/bin/env bash
set -euo pipefail

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
    fail "adb not found. Install Android SDK platform-tools."
    fail "  brew install android-platform-tools"
    exit 1
fi

adb start-server 2>/dev/null

wireless_devices() {
    adb devices 2>/dev/null | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+.*device$" || true
}

usb_devices() {
    adb devices 2>/dev/null | grep -E "^\S+\s+device$" | grep -v -E "^[0-9]+\.[0-9]+\." || true
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

# --- Handle arguments ---
case "${1:-}" in
    status)
        step "ADB device status"
        usb=$(usb_devices)
        wireless=$(wireless_devices)
        if [[ -z "$usb" && -z "$wireless" ]]; then
            warn "No devices connected at all."
        fi
        if [[ -n "$usb" ]]; then
            ok "USB devices:"
            echo "$usb" | while read -r line; do echo "       $line"; done
        fi
        if [[ -n "$wireless" ]]; then
            ok "Wireless devices:"
            echo "$wireless" | while read -r line; do echo "       $line"; done
        fi
        exit 0
        ;;
    disconnect)
        step "Disconnecting all wireless devices"
        adb disconnect 2>/dev/null || true
        ok "All wireless connections dropped."
        exit 0
        ;;
    help|--help|-h)
        echo -e "${BOLD}Usage:${NC} $(basename "$0") [command]"
        echo ""
        echo "Commands:"
        echo "  (none)       Connect a USB device wirelessly"
        echo "  status       Show connected USB and wireless devices"
        echo "  disconnect   Drop all wireless connections"
        echo "  help         Show this help"
        exit 0
        ;;
esac

# --- Main flow: connect wirelessly ---

step "1. Checking for existing wireless connections"
existing=$(wireless_devices)
if [[ -n "$existing" ]]; then
    ok "Already connected wirelessly:"
    echo "$existing" | while read -r line; do echo "       $line"; done
    echo ""
    read -rp "   Reconnect anyway? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy] ]]; then
        info "Keeping existing connection. Done."
        exit 0
    fi
    adb disconnect 2>/dev/null || true
fi

step "2. Looking for USB devices"
usb=$(usb_devices)
if [[ -z "$usb" ]]; then
    count=0
else
    count=$(echo "$usb" | wc -l | tr -d ' ')
fi

if [[ "$count" -eq 0 ]]; then
    fail "No USB device found."
    echo ""
    echo "   Checklist:"
    echo "   1. Is the phone plugged in via USB?"
    echo "   2. Is USB debugging ON? (Settings > Developer Options)"
    echo "   3. Did you tap 'Allow' on the phone's USB debugging prompt?"
    echo "   4. Try: unplug, replug, then run this script again."
    exit 1
fi

serial=""
if [[ "$count" -gt 1 ]]; then
    warn "Multiple USB devices found:"
    i=1
    declare -a serials=()
    while IFS= read -r line; do
        s=$(echo "$line" | awk '{print $1}')
        serials+=("$s")
        echo "   [$i] $s"
        ((i++))
    done <<< "$usb"
    echo ""
    read -rp "   Pick a device [1-${#serials[@]}]: " pick
    if [[ "$pick" -lt 1 || "$pick" -gt "${#serials[@]}" ]] 2>/dev/null; then
        fail "Invalid choice."
        exit 1
    fi
    serial="${serials[$((pick-1))]}"
else
    serial=$(echo "$usb" | awk '{print $1}')
fi

ok "Using device: $serial"

step "3. Getting device IP"
all_ips=$(get_device_ips "$serial")
gateway=$(get_mac_gateway)

if [[ -z "$all_ips" ]]; then
    fail "Could not get any IP from device."
    echo ""
    echo "   Checklist:"
    echo "   1. Is WiFi or hotspot turned ON?"
    echo "   2. Phone and computer must be on the same network."
    exit 1
fi

ip=""
if [[ -n "$gateway" ]]; then
    gateway_subnet=$(echo "$gateway" | cut -d. -f1-3)
    while IFS= read -r candidate; do
        candidate_subnet=$(echo "$candidate" | cut -d. -f1-3)
        if [[ "$candidate_subnet" == "$gateway_subnet" ]]; then
            ip="$candidate"
            break
        fi
    done <<< "$all_ips"
fi

if [[ -z "$ip" ]]; then
    ip_count=$(echo "$all_ips" | wc -l | tr -d ' ')
    if [[ "$ip_count" -eq 1 ]]; then
        ip="$all_ips"
    else
        warn "Multiple IPs found, couldn't auto-detect which one matches your Mac's network:"
        i=1
        declare -a ip_list=()
        while IFS= read -r candidate; do
            ip_list+=("$candidate")
            echo "   [$i] $candidate"
            ((i++))
        done <<< "$all_ips"
        if [[ -n "$gateway" ]]; then
            info "Mac's gateway: $gateway"
        fi
        echo ""
        read -rp "   Pick the IP on the same network as your Mac [1-${#ip_list[@]}]: " pick
        if [[ "$pick" -lt 1 || "$pick" -gt "${#ip_list[@]}" ]] 2>/dev/null; then
            fail "Invalid choice."
            exit 1
        fi
        ip="${ip_list[$((pick-1))]}"
    fi
fi

ok "Using device IP: $ip"
if [[ -n "$gateway" ]]; then
    info "Mac's gateway: $gateway (same subnet = good)"
fi

step "4. Switching device to TCP/IP mode (port $PORT)"
output=$(adb -s "$serial" tcpip "$PORT" 2>&1) || {
    fail "Failed to switch to TCP/IP mode."
    echo "   adb output: $output"
    exit 1
}
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
verify=$(wireless_devices)
if echo "$verify" | grep -q "$ip"; then
    ok "Wireless connection verified!"
else
    warn "Connected but verification unclear. Run: adb devices"
fi

echo ""
echo -e "${GREEN}${BOLD}Done!${NC} You can unplug the USB cable now."
echo ""
echo "   Reconnect later:  adb connect $ip:$PORT"
echo "   Check status:     $(basename "$0") status"
echo "   Disconnect:       $(basename "$0") disconnect"
