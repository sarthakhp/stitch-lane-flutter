"""ADB process helpers and device/network discovery."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import time

from adbw.ui import fail


def run(cmd: list[str], check: bool = False, timeout: int = 10) -> subprocess.CompletedProcess:
    """Run a command, capturing output."""
    return subprocess.run(
        cmd,
        check=check,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def require_tool(name: str, install_hint: str) -> None:
    if shutil.which(name) is None:
        fail(f"{name} not found.")
        fail(f"  {install_hint}")
        sys.exit(1)


def adb_devices_raw() -> str:
    res = run(["adb", "devices"])
    return res.stdout if res.returncode == 0 else ""


def wireless_devices() -> list[str]:
    """Return list of wireless device serials (IP:PORT format)."""
    pattern = re.compile(r"^(\d+\.\d+\.\d+\.\d+:\d+)\s+device$")
    return [
        m.group(1)
        for line in adb_devices_raw().splitlines()
        if (m := pattern.match(line.strip()))
    ]


def usb_devices() -> list[str]:
    """Return list of USB device serials (non-IP)."""
    out = []
    for line in adb_devices_raw().splitlines():
        line = line.strip()
        if not line or line.startswith("List of devices"):
            continue
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "device":
            serial = parts[0]
            # Exclude wireless (IP:port) serials
            if not re.match(r"^\d+\.\d+\.\d+\.\d+:\d+$", serial):
                out.append(serial)
    return out


def device_models() -> dict[str, str]:
    """Map device serial -> human model name from `adb devices -l`.

    Used to label the device picker so you can tell phones apart (e.g.
    "CPH2691" vs "OPD2480") instead of staring at raw serials/IPs.
    """
    res = run(["adb", "devices", "-l"])
    models: dict[str, str] = {}
    for line in res.stdout.splitlines():
        line = line.strip()
        if not line or line.startswith("List of devices"):
            continue
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "device":
            model = next(
                (
                    p.split(":", 1)[1].replace("_", " ")
                    for p in parts[2:]
                    if p.startswith("model:")
                ),
                "",
            )
            models[parts[0]] = model
    return models


def mdns_connect_targets(retries: int = 3, delay: float = 0.7) -> list[str]:
    """Find already-paired Android devices broadcasting via mDNS.

    Returns list of "ip:port" strings for _adb-tls-connect._tcp services.
    Retries briefly because mDNS discovery can be slow on the first scan.
    """
    pattern = re.compile(r"_adb-tls-connect\._tcp")
    # ip:port (colon-joined) or "ip port" (whitespace) — adb varies by version.
    ip_port = re.compile(r"(\d+\.\d+\.\d+\.\d+)[:\s]+(\d+)")
    for attempt in range(retries):
        res = run(["adb", "mdns", "services"], timeout=5)
        targets = []
        for line in res.stdout.splitlines():
            if not pattern.search(line):
                continue
            m = ip_port.search(line)
            if m:
                targets.append(f"{m.group(1)}:{m.group(2)}")
        if targets:
            return targets
        if attempt < retries - 1:
            time.sleep(delay)
    return []


def mdns_pairing_targets() -> list[tuple[str, str]]:
    """Find phones currently in QR pairing mode.

    When a phone scans a pairing QR code it briefly advertises an
    `_adb-tls-pairing._tcp` mDNS service whose instance name is the name we
    embedded in the QR payload. Returns a list of (instance_name, "ip:port").
    """
    # ip:port (colon-joined) or "ip port" (whitespace) — adb varies by version.
    ip_port = re.compile(r"(\d+\.\d+\.\d+\.\d+)[:\s]+(\d+)")
    res = run(["adb", "mdns", "services"], timeout=5)
    out: list[tuple[str, str]] = []
    for line in res.stdout.splitlines():
        if "_adb-tls-pairing._tcp" not in line:
            continue
        m = ip_port.search(line)
        if not m:
            continue
        parts = line.split()
        instance = parts[0] if parts else ""
        out.append((instance, f"{m.group(1)}:{m.group(2)}"))
    return out


def get_device_ips(serial: str) -> list[str]:
    """Get all IPv4 addresses on the device, excluding loopback."""
    res = run(["adb", "-s", serial, "shell", "ip", "-4", "addr"])
    ips = []
    for line in res.stdout.splitlines():
        line = line.strip()
        if not line.startswith("inet "):
            continue
        # Format: "inet 192.168.1.5/24 brd ..."
        addr = line.split()[1].split("/")[0]
        if addr != "127.0.0.1":
            ips.append(addr)
    return ips


def get_mac_gateway() -> str | None:
    """Get the default gateway on macOS."""
    res = run(["route", "-n", "get", "default"])
    for line in res.stdout.splitlines():
        line = line.strip()
        if line.startswith("gateway:"):
            return line.split(":", 1)[1].strip()
    return None


def is_responsive(serial: str) -> bool:
    """True if the device actually answers (a prop read returns), not just
    listed as 'device' in `adb devices`."""
    res = run(["adb", "-s", serial, "shell", "getprop", "ro.product.model"])
    return bool(res.stdout.strip())


def best_device_ip(serial: str) -> str | None:
    """Pick the device's WiFi IP for wireless ADB: prefer the one on the Mac's
    subnet (so it's reachable), else the first IP, else None."""
    ips = get_device_ips(serial)
    if not ips:
        return None
    gateway = get_mac_gateway()
    if gateway:
        gw_subnet = ".".join(gateway.split(".")[:3])
        for ip in ips:
            if ".".join(ip.split(".")[:3]) == gw_subnet:
                return ip
    return ips[0]
