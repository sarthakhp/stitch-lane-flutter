#!/usr/bin/env python3
"""Connect an Android device wirelessly via ADB, with optional scrcpy mirroring."""

from __future__ import annotations

import os
import sys

from adbw.adb import require_tool, run
from adbw.commands import (
    cmd_connect,
    cmd_disconnect,
    cmd_help,
    cmd_mirror,
    cmd_pair,
    cmd_run,
    cmd_status,
)
from adbw.ui import fail


def main() -> int:
    require_tool("adb", "brew install android-platform-tools")
    run(["adb", "start-server"])

    argv = sys.argv[1:]
    prog = os.path.basename(sys.argv[0])

    # `run` passes everything after it straight through to `flutter run`, so
    # handle it before the --mirror stripping (those are flutter's args).
    if argv and argv[0] == "run":
        return cmd_run(argv[1:])

    # Mirroring (scrcpy) is opt-in: connecting/pairing no longer launches it
    # automatically. Pass --mirror to also start scrcpy, or use the `mirror`
    # subcommand on an already-connected device.
    args = argv
    mirror = "--mirror" in args
    args = [a for a in args if a != "--mirror"]
    cmd = args[0] if args else None

    if cmd == "status":
        return cmd_status()
    if cmd == "disconnect":
        return cmd_disconnect()
    if cmd == "mirror":
        return cmd_mirror()
    if cmd == "pair":
        return cmd_pair(mirror=mirror)
    if cmd in ("help", "--help", "-h"):
        return cmd_help(prog)
    if cmd is None:
        return cmd_connect(mirror=mirror)

    fail(f"Unknown command: {cmd}")
    cmd_help(prog)
    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print()
        sys.exit(130)
