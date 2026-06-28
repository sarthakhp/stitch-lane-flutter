"""ADB process helpers and device/network discovery."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

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


_IP_PORT_RE = re.compile(r"^\d+\.\d+\.\d+\.\d+:\d+$")


def is_wireless_serial(serial: str) -> bool:
    """True for adb wireless transports. These come in two forms:
      - tcpip:        192.168.29.151:34787
      - Wireless dbg: adb-f56e0b55-YO5sRu._adb-tls-connect._tcp  (mDNS name)
    USB serials are plain device IDs, so anything matching either wireless
    form is treated as wireless (and excluded from the USB list)."""
    return bool(_IP_PORT_RE.match(serial)) or "_adb-tls-" in serial or serial.endswith("._tcp")


def _devices_where(keep_wireless: bool) -> list[str]:
    """Serials listed as 'device', filtered to wireless or USB transports."""
    out = []
    for line in adb_devices_raw().splitlines():
        line = line.strip()
        if not line or line.startswith("List of devices"):
            continue
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "device":
            if is_wireless_serial(parts[0]) == keep_wireless:
                out.append(parts[0])
    return out


def wireless_devices() -> list[str]:
    """Return wireless device serials (ip:port or the mDNS _adb-tls name)."""
    return _devices_where(keep_wireless=True)


def usb_devices() -> list[str]:
    """Return USB device serials (anything not a wireless transport)."""
    return _devices_where(keep_wireless=False)


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


_ALIASES_FILE = Path(__file__).resolve().parent.parent / ".device-aliases"


def _load_aliases() -> dict[str, str]:
    """Read scripts/.device-aliases → {key: friendly_name}. Keys are matched
    case-insensitively against serials and model names."""
    if not _ALIASES_FILE.exists():
        return {}
    aliases: dict[str, str] = {}
    for raw in _ALIASES_FILE.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if "=" not in line:
            continue
        key, _, name = line.partition("=")
        key, name = key.strip().lower(), name.strip()
        if key and name:
            aliases[key] = name
    return aliases


def friendly_name(serial: str, models: dict[str, str] | None = None) -> str:
    """Human-readable label for a device serial.

    Priority: alias-by-serial → alias-by-model → model name → serial.
    The mDNS serial form (`adb-xxx._adb-tls-connect._tcp`) is also matched
    against the alias file, and the model lookup is used as a tiebreaker.
    """
    aliases = _load_aliases()
    # Try serial directly.
    if serial.lower() in aliases:
        return aliases[serial.lower()]
    # Try looking up the model for this serial and alias by model.
    if models is None:
        models = device_models()
    model = models.get(serial, "")
    if model and model.lower() in aliases:
        return aliases[model.lower()]
    # Fall back: model name if known, else raw serial.
    return model or serial


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
