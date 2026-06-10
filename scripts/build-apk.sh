#!/usr/bin/env bash
#
# build-apk.sh — build a release APK and drop it somewhere easy to sideload.
#
# We sideload manually (the USB link to the tablet is flaky for `adb install`),
# so this just builds and copies the APK to a predictable spot.
#
#   ./scripts/build-apk.sh            # universal release APK (all ABIs)
#   ./scripts/build-apk.sh --arm64    # arm64-only — ~3x smaller, OnePlus Pad 2 etc.
#
# Output (default): ~/Desktop/StitchGenie-release-{universal,arm64}.apk
#
# Env:
#   OUT_DIR=<dir>   copy the APK here instead of ~/Desktop
#   NO_COPY=1       don't copy — just build and print the build-output path
#
# To build AND install/run on a connected device instead, use ./scripts/run.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../app"
BUILT_APK="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
OUT_DIR="${OUT_DIR:-$HOME/Desktop}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info() { echo -e "${CYAN}[info]${NC}  $1"; }
ok()   { echo -e "${GREEN}[ok]${NC}    $1"; }
warn() { echo -e "${YELLOW}[warn]${NC}  $1"; }
fail() { echo -e "${RED}[fail]${NC}  $1"; }
step() { echo -e "\n${BOLD}$1${NC}"; }

command -v flutter &>/dev/null || { fail "flutter not found in PATH"; exit 1; }

# Args: only --arm64 is recognized.
VARIANT="universal"
BUILD_FLAGS=()
for arg in "$@"; do
  case "$arg" in
    --arm64)
      VARIANT="arm64"
      BUILD_FLAGS+=(--target-platform android-arm64)
      ;;
    *)
      fail "Unknown argument: $arg (supported: --arm64)"
      exit 1
      ;;
  esac
done

cd "$APP_DIR" || { fail "Cannot cd to app dir: $APP_DIR"; exit 1; }

step "Building $VARIANT release APK (flutter build apk --release ${BUILD_FLAGS[*]:-})"
# `${arr[@]+...}` guards against macOS bash 3.2 treating an empty array as an
# unbound variable under `set -u`.
if ! flutter build apk --release "${BUILD_FLAGS[@]+"${BUILD_FLAGS[@]}"}"; then
  fail "Build failed."
  exit 1
fi

if [[ ! -f "$BUILT_APK" ]]; then
  fail "Build reported success but APK not found at: $BUILT_APK"
  exit 1
fi

SIZE="$(du -h "$BUILT_APK" | cut -f1 | tr -d ' ')"

if [[ "${NO_COPY:-0}" == "1" ]]; then
  ok "Built ($SIZE): $BUILT_APK"
  exit 0
fi

mkdir -p "$OUT_DIR" 2>/dev/null
DEST="$OUT_DIR/StitchGenie-release-$VARIANT.apk"

# -f: replace any existing file (even read-only) rather than failing. Check the
# result — a silent cp failure must NOT be reported as success.
if ! cp -f "$BUILT_APK" "$DEST" 2>/dev/null; then
  fail "Built OK ($SIZE) but could NOT copy it to: $DEST"
  echo ""
  echo "   The APK itself is fine — grab it directly from:"
  echo "      $BUILT_APK"
  echo ""
  echo "   The copy was blocked (usually macOS Privacy: your terminal isn't"
  echo "   allowed to write to that folder). Fix any one of these, then re-run:"
  echo "   1. System Settings > Privacy & Security > Files and Folders (or Full"
  echo "      Disk Access) -> enable it for your terminal app."
  echo "   2. Use an allowed folder:  OUT_DIR=~/stitch-apks ./scripts/build-apk.sh"
  echo "   3. Skip the copy:          NO_COPY=1 ./scripts/build-apk.sh"
  exit 1
fi
ok "Built ($SIZE) and copied to:"
echo "      $DEST"
echo ""
info "Sideload: transfer it to the tablet (Drive/USB/email) and tap to install."
info "It's an in-place update (same release key) — the data stays."
