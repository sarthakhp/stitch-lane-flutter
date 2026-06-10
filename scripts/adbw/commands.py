"""Subcommands for adb-wireless."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

from adbw.adb import (
    best_device_ip,
    device_models,
    get_device_ips,
    get_mac_gateway,
    is_responsive,
    mdns_connect_targets,
    require_tool,
    run,
    usb_devices,
    wireless_devices,
)
from adbw.ui import BOLD, GREEN, NC, fail, info, ok, pick_from_list, step, warn

PORT = 5555

# Paths (mirror the old run.sh layout): scripts/ holds the cache + skip list,
# the Flutter app is the sibling app/ dir.
_SCRIPTS_DIR = Path(__file__).resolve().parent.parent
_APP_DIR = _SCRIPTS_DIR.parent / "app"
_CACHE_FILE = _SCRIPTS_DIR / ".last-wireless-device"
_USB_SKIP_FILE = _SCRIPTS_DIR / ".usb-skip"
_RECOVER_DB = _SCRIPTS_DIR / "recover-db.sh"
_WIRELESS_RE = re.compile(r"^\d+\.\d+\.\d+\.\d+:\d+$")


def _start_mirror(target: str, mirror: bool) -> int:
    """Launch scrcpy against `target` (ip:port) and replace this process."""
    if not mirror:
        return 0
    if shutil.which("scrcpy") is None:
        print()
        warn("scrcpy not installed — skipping screen mirror.")
        info("Install with: brew install scrcpy")
        return 0
    step("Starting screen mirror (scrcpy)")
    info("Press Ctrl+C to stop mirroring.")
    os.execvp("scrcpy", ["scrcpy", "-s", target])
    return 0  # unreachable


def cmd_status() -> int:
    step("ADB device status")
    usb = usb_devices()
    wifi = wireless_devices()
    if not usb and not wifi:
        warn("No devices connected at all.")
    if usb:
        ok("USB devices:")
        for s in usb:
            print(f"       {s}")
    if wifi:
        ok("Wireless devices:")
        for s in wifi:
            print(f"       {s}")
    return 0


def cmd_disconnect() -> int:
    step("Disconnecting all wireless devices")
    run(["adb", "disconnect"])
    ok("All wireless connections dropped.")
    return 0


def cmd_mirror() -> int:
    """Start scrcpy screen mirroring over the current wireless connection."""
    require_tool("scrcpy", "brew install scrcpy")
    wifi = wireless_devices()
    if not wifi:
        fail("No wireless device connected. Run this script (without args) first.")
        return 1
    target = wifi[0] if len(wifi) == 1 else pick_from_list(wifi, "Pick a device")
    if target is None:
        return 1
    ok(f"Starting scrcpy for {target}")
    return _start_mirror(target, mirror=True)


def cmd_help(prog: str) -> int:
    print(f"{BOLD}Usage:{NC} {prog} [command] [--no-mirror]")
    print()
    print("Commands:")
    print("  (none)       Detect connected devices (USB + wireless); if more than")
    print("               one, ask which to use; set up wireless if it's USB; mirror.")
    print("               Falls back to mDNS lookup when nothing is connected.")
    print("  run [args]   flutter run against the phone (USB-first, wireless")
    print("               fallback); extra args pass to flutter (e.g. --release).")
    print("               Env: PORT, WIFI=1, SNAPSHOT=1; skip USB via .usb-skip")
    print("  pair         One-time pairing via Android 11+ Wireless debugging")
    print("               (after this, the default command works fully cable-free)")
    print("  status       Show connected USB and wireless devices")
    print("  disconnect   Drop all wireless connections")
    print("  mirror       Start screen mirroring (scrcpy) on an already-connected device")
    print("  help         Show this help")
    print()
    print("Flags:")
    print("  --no-mirror  Skip the automatic scrcpy launch after connecting")
    return 0


def cmd_pair(mirror: bool = True) -> int:
    """Pair using Android 11+ Wireless debugging. Persists across USB unplug and reboots."""
    step("Android 11+ Wireless debugging pairing")
    print("   This pairs your Mac to the phone over wifi only — no USB needed,")
    print("   and the pairing survives unplug, reboot, and wifi reconnect.")
    print()
    print(f"   {BOLD}On your phone:{NC}")
    print("   1. Settings > Developer options > Wireless debugging  (turn ON)")
    print("   2. Tap 'Pair device with pairing code'")
    print("   3. The phone shows an IP:port and a 6-digit code")
    print()

    try:
        pair_addr = input("   Enter pairing IP:port (e.g. 192.168.1.5:37123): ").strip()
        code = input("   Enter 6-digit pairing code: ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        return 1

    if not pair_addr or not code:
        fail("Pairing IP:port and code are both required.")
        return 1

    step(f"Pairing with {pair_addr}")
    res = run(["adb", "pair", pair_addr, code], timeout=30)
    output = (res.stdout + res.stderr).strip()
    if res.returncode != 0 or "successfully paired" not in output.lower():
        fail(f"Pairing failed: {output}")
        print()
        print("   Common causes:")
        print("   1. Wrong pairing code (it expires fast — try again)")
        print("   2. Wrong IP:port (use the one from the *pairing* screen,")
        print("      NOT the main 'IP address & Port' on the Wireless debugging screen)")
        print("   3. Phone and Mac not on the same wifi network")
        return 1
    ok(output)

    print()
    print(f"   {BOLD}Now back on your phone:{NC}")
    print("   Go back to the Wireless debugging main screen and note")
    print("   'IP address & Port' — this is DIFFERENT from the pairing port.")
    print()
    try:
        connect_addr = input("   Enter connection IP:port: ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        return 1
    if not connect_addr:
        fail("Connection IP:port is required.")
        return 1

    step(f"Connecting to {connect_addr}")
    res = run(["adb", "connect", connect_addr], timeout=15)
    output = (res.stdout + res.stderr).strip()
    if "connected" not in output.lower():
        fail(f"Connection failed: {output}")
        return 1
    ok(output)

    print()
    print(f"{GREEN}{BOLD}Done!{NC} This connection persists across unplug and reboots.")
    print()
    print(f"   Reconnect later:  adb connect {connect_addr}")
    print(f"   Check status:     {sys.argv[0]} status")
    print(f"   Disconnect:       {sys.argv[0]} disconnect")

    return _start_mirror(connect_addr, mirror)


def _device_label(kind: str, serial: str, models: dict[str, str]) -> str:
    tag = "USB" if kind == "usb" else "Wireless"
    model = models.get(serial, "")
    return f"{tag}: {model or serial}  [{serial}]"


def cmd_connect(mirror: bool = True) -> int:
    step("1. Detecting connected devices (USB + wireless)")
    usb = usb_devices()
    wifi = wireless_devices()
    models = device_models()

    # Unified candidate list so a freshly-plugged USB phone and a stale
    # wireless connection to a different phone both show up — and you pick.
    # (Previously the script grabbed any live wireless connection first, so it
    # kept reconnecting to the old phone after you swapped the USB cable.)
    candidates: list[tuple[str, str]] = (
        [("usb", s) for s in usb] + [("wifi", w) for w in wifi]
    )

    if candidates:
        if len(candidates) == 1:
            kind, serial = candidates[0]
            ok(f"One device connected — {_device_label(kind, serial, models)}")
        else:
            ok(f"Found {len(candidates)} connected devices:")
            labels = [_device_label(k, s, models) for k, s in candidates]
            chosen = pick_from_list(labels, "Pick the device to connect")
            if chosen is None:
                return 1
            kind, serial = candidates[labels.index(chosen)]

        if kind == "wifi":
            ok(f"Mirroring wireless device: {serial}")
            return _start_mirror(serial, mirror)
        return _connect_usb_device(serial, mirror)

    step("2. No devices connected — looking for paired devices (mDNS)")
    info("This finds devices you've previously paired via Wireless debugging.")
    targets = mdns_connect_targets()
    if targets:
        ok(f"Found {len(targets)} paired device(s):")
        for t in targets:
            print(f"       {t}")
        target = targets[0] if len(targets) == 1 else pick_from_list(targets, "Pick a device")
        if target is None:
            return 1
        step(f"Connecting to {target}")
        res = run(["adb", "connect", target], timeout=15)
        output = (res.stdout + res.stderr).strip()
        if "connected" in output.lower() and "failed" not in output.lower():
            ok(output)
            return _start_mirror(target, mirror)
        warn(f"mDNS connect failed: {output}")
    else:
        info("No paired devices found via mDNS.")

    fail("No device found (no USB, no live wireless, no paired device).")
    print()
    print("   Checklist:")
    print("   1. Plug the phone in via USB, OR turn on Wireless debugging.")
    print("   2. Is USB debugging ON? (Settings > Developer Options)")
    print("   3. Did you tap 'Allow' on the phone's USB debugging prompt?")
    print(f"   4. First time wireless? Run: {sys.argv[0]} pair")
    return 1


def _wireless_connect(target: str, attempts: int = 5, delay: float = 1.5) -> bool:
    """Connect to `ip:port`, clearing any stale connection first and retrying.

    `adb tcpip` restarts adbd on the device, so the first connect usually
    races the new listener coming up ("Connection refused"), and an old
    wireless entry to the same address goes offline. We `adb disconnect` the
    target before each attempt and retry a few times — no manual steps needed.
    """
    for attempt in range(1, attempts + 1):
        run(["adb", "disconnect", target])  # drop any stale/offline entry
        res = run(["adb", "connect", target], timeout=15)
        output = (res.stdout + res.stderr).strip()
        low = output.lower()
        if "connected" in low and "failed" not in low and "refused" not in low:
            ok(output)
            return True
        if attempt < attempts:
            warn(f"connect attempt {attempt}/{attempts}: {output} — retrying in {delay:g}s…")
            time.sleep(delay)
        else:
            fail(f"Connection failed after {attempts} attempts: {output}")
    return False


def _connect_usb_device(serial: str, mirror: bool) -> int:
    """Switch a USB-connected device to wireless ADB (tcpip), then mirror it."""
    ok(f"Setting up wireless for USB device: {serial}")

    step("Getting device IP")
    all_ips = get_device_ips(serial)
    gateway = get_mac_gateway()

    if not all_ips:
        fail("Could not get any IP from device.")
        print()
        print("   Checklist:")
        print("   1. Is WiFi or hotspot turned ON?")
        print("   2. Phone and computer must be on the same network.")
        return 1

    ip: str | None = None
    if gateway:
        gw_subnet = ".".join(gateway.split(".")[:3])
        for candidate in all_ips:
            if ".".join(candidate.split(".")[:3]) == gw_subnet:
                ip = candidate
                break

        if ip is None:
            # None of the device's IPs are on the Mac's subnet — wireless
            # ADB cannot reach the phone. Bail out with a clear diagnostic.
            fail("Phone and Mac are NOT on the same network.")
            print()
            print(f"   Mac's network:   {gw_subnet}.x  (gateway {gateway})")
            print("   Phone's IPs:")
            for candidate in all_ips:
                print(f"     - {candidate}")
            print()
            print("   Wireless ADB needs both devices on the same LAN.")
            print("   Fix one of these and try again:")
            print("   1. Connect the phone to the same WiFi as the Mac, OR")
            print("   2. Turn on the phone's hotspot and connect the Mac to it, OR")
            print("   3. Disconnect from VPN if either device is on one.")
            return 1

    if ip is None:
        # No gateway detected (no network on Mac?). Fall back to user pick.
        if len(all_ips) == 1:
            ip = all_ips[0]
        else:
            warn("Could not detect your Mac's network. Pick the phone's IP manually:")
            choice = pick_from_list(all_ips, "Pick the IP on the same network as your Mac")
            if choice is None:
                return 1
            ip = choice

    ok(f"Using device IP: {ip}")
    if gateway:
        info(f"Mac's gateway: {gateway} (same subnet = good)")

    step(f"Switching device to TCP/IP mode (port {PORT})")
    res = run(["adb", "-s", serial, "tcpip", str(PORT)])
    if res.returncode != 0:
        fail("Failed to switch to TCP/IP mode.")
        print(f"   adb output: {res.stderr.strip() or res.stdout.strip()}")
        return 1
    ok("TCP/IP mode enabled.")
    time.sleep(1)

    step(f"Connecting wirelessly to {ip}:{PORT}")
    if not _wireless_connect(f"{ip}:{PORT}"):
        print()
        print("   Checklist:")
        print("   1. Are phone and computer on the SAME WiFi network?")
        print(f"   2. Is a firewall blocking port {PORT}?")
        print("   3. Make sure Wireless debugging is allowed for this network.")
        return 1

    step("Verifying wireless connection")
    time.sleep(1)
    verify = wireless_devices()
    if any(ip in v for v in verify):
        ok("Wireless connection verified!")
    else:
        warn("Connected but verification unclear. Run: adb devices")

    print()
    print(f"{GREEN}{BOLD}Done!{NC} You can unplug the USB cable now.")
    print()
    warn("Heads up: on many Android builds this 'adb tcpip' connection")
    warn("drops the moment you unplug USB (adbd restarts and kills the listener).")
    warn(f"For a connection that survives unplug + reboot, run: {sys.argv[0]} pair")
    print()
    print(f"   Reconnect later:  adb connect {ip}:{PORT}")
    print(f"   Check status:     {sys.argv[0]} status")
    print(f"   Disconnect:       {sys.argv[0]} disconnect")

    return _start_mirror(f"{ip}:{PORT}", mirror)


def _usb_install_blocked(serial: str, models: dict[str, str]) -> bool:
    """Whether `serial` is listed in scripts/.usb-skip (by serial OR model
    substring). Those devices hang on USB `adb install`, so `run` prefers
    wireless for them. See that file's header for the rationale."""
    if not _USB_SKIP_FILE.exists():
        return False
    model = models.get(serial, "")
    for raw in _USB_SKIP_FILE.read_text().splitlines():
        entry = raw.split("#", 1)[0].strip()
        if not entry:
            continue
        if serial == entry:
            return True
        if model and entry.lower() in model.lower():
            return True
    return False


def cmd_run(flutter_args: list[str]) -> int:
    """`flutter run` against the phone with zero device fiddling — USB-first
    (fast), with wireless fallback and USB->wireless bootstrap. Reuses the
    shared adb helpers so there's one source of truth for device resolution.
    Env: PORT (adb tcp port), WIFI=1 (force wireless), SNAPSHOT=1 (pre-run DB
    pull). Extra args pass straight to `flutter run`."""
    require_tool("flutter", "flutter not found in PATH")
    port = os.environ.get("PORT", str(PORT))
    force_wifi = os.environ.get("WIFI", "0") == "1"

    serial = ""

    # 1. USB fast path — fastest install + hot reload, most stable link.
    if not force_wifi:
        step("1. Looking for a USB device (fast path)")
        usb_serial = next((s for s in usb_devices() if is_responsive(s)), None)
        if usb_serial and _usb_install_blocked(usb_serial, device_models()):
            info(f"USB device {usb_serial} is in .usb-skip (USB install hangs "
                 f"here) — using wireless.")
        elif usb_serial:
            ok(f"Using USB device: {usb_serial}")
            # Drop any wireless transport to the same device — both bound at
            # once is what makes adb installs hang mid-transfer.
            dupes = wireless_devices()
            if dupes:
                warn("Disconnecting wireless duplicate(s) to avoid dual-transport hangs:")
                for w in dupes:
                    info(f"  adb disconnect {w}")
                    run(["adb", "disconnect", w])
            serial = usb_serial
        else:
            info("No healthy USB device — falling back to wireless.")
    else:
        info("WIFI=1 set — skipping USB, resolving a wireless device.")

    # 2. An already-connected wireless device.
    if not serial:
        step("2. Looking for an existing wireless device")
        w = next((s for s in wireless_devices() if is_responsive(s)), None)
        if w:
            ok(f"Using wireless device: {w}")
            serial = w

    # 3. The IP cached from a previous run.
    if not serial and _CACHE_FILE.exists():
        cached = _CACHE_FILE.read_text().strip()
        if cached:
            step(f"3. Reconnecting to cached device ({cached})")
            run(["adb", "connect", cached], timeout=15)
            time.sleep(1)
            if is_responsive(cached):
                serial = cached
                ok(f"Reconnected: {serial}")
            else:
                warn("Cached device didn't answer — will try USB bootstrap.")

    # 4. Bootstrap wireless from a USB cable (read IP, tcpip, connect).
    if not serial:
        step("4. Bootstrapping wireless from USB")
        usb = usb_devices()
        if not usb:
            fail("No wireless or USB device available.")
            print()
            print("   To bootstrap WiFi, plug the phone in via USB once with debugging on:")
            print("     - USB mode = File Transfer (not charge-only)")
            print("     - Tap 'Allow' on the USB-debugging prompt")
            print("   Then re-run. After that, future runs reconnect over WiFi with no cable.")
            return 1
        usb_serial = usb[0]
        ok(f"USB device: {usb_serial}")

        ip = best_device_ip(usb_serial)
        if not ip:
            fail("Couldn't read the phone's WiFi IP. Is WiFi on, same network as the Mac?")
            return 1
        info(f"Phone WiFi IP: {ip}")

        info(f"Switching phone to TCP/IP mode (port {port})...")
        # tcpip can hang on a flaky USB link even though it takes effect on the
        # phone — time-box it and connect anyway.
        try:
            run(["adb", "-s", usb_serial, "tcpip", port], timeout=6)
        except subprocess.TimeoutExpired:
            warn("tcpip command didn't return cleanly — trying to connect anyway.")
        time.sleep(2)

        target = f"{ip}:{port}"
        if not _wireless_connect(target):
            fail(f"Could not establish a wireless connection to {target}.")
            return 1
        serial = target

    # Cache wireless serials so the next run reconnects with no cable.
    if _WIRELESS_RE.match(serial):
        _CACHE_FILE.write_text(serial + "\n")

    # Optional pre-run DB snapshot (data safety) — opt in via SNAPSHOT=1.
    if os.environ.get("SNAPSHOT", "0") == "1" and os.access(_RECOVER_DB, os.X_OK):
        step("Pulling a pre-run DB snapshot")
        rc = subprocess.run(
            ["bash", str(_RECOVER_DB)],
            env={**os.environ, "ANDROID_SERIAL": serial},
        ).returncode
        if rc != 0:
            warn("Snapshot failed — continuing with run anyway.")

    extra = " ".join(flutter_args)
    step(f"Launching: flutter run -d {serial} {extra}".rstrip())
    os.chdir(_APP_DIR)
    os.execvp("flutter", ["flutter", "run", "-d", serial, *flutter_args])
    return 0  # unreachable (execvp replaces this process)
