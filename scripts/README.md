# Scripts

## build-apk.sh

Build a release APK and copy it somewhere easy to sideload (we install
manually because `adb install` over USB is flaky on the tablet).

```bash
./build-apk.sh            # universal release APK (all ABIs)
./build-apk.sh --arm64    # arm64-only — ~3x smaller (OnePlus Pad 2, most phones)
```

Output defaults to `~/Desktop/StitchGenie-release-{universal,arm64}.apk`.
Override with `OUT_DIR=<dir>`, or pass `NO_COPY=1` to just build and print the
path. To build **and** install/run on a connected device instead, use
`./run.sh`.

## Setup

```bash
cd scripts
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Point your IDE's Python interpreter to `scripts/.venv/bin/python` so imports and
type hints resolve.

## adb-wireless.py

Connect an Android device to the Mac via wireless ADB, with optional `scrcpy`
screen mirroring.

```bash
./adb-wireless.py              # auto-connect (mDNS) + mirror, USB fallback
./adb-wireless.py pair         # one-time pairing (Android 11+ Wireless debugging)
./adb-wireless.py status       # show connected devices
./adb-wireless.py disconnect   # drop all wireless connections
./adb-wireless.py mirror       # start scrcpy on an already-connected device
./adb-wireless.py help
```

**First-time setup (one manual step):**

```bash
./adb-wireless.py pair
```

Android shows a 6-digit pairing code on the phone — you type it once. This is
an Android security requirement; there is no API to read the code
programmatically.

**Every other time (fully automatic, cable-free):**

```bash
./adb-wireless.py
```

This uses mDNS (`adb mdns services`) to find your already-paired phone on the
network, connects, and launches scrcpy. No USB cable, no prompts.

If no paired device is found via mDNS, the script falls back to the legacy
`adb tcpip` flow (requires USB and drops on unplug) so first-time users still
get a working connection.

Prerequisites: `adb` (Android platform-tools) and `scrcpy` for the mirror
command. Install both with `brew install android-platform-tools scrcpy`.
