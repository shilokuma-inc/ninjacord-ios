#!/bin/sh
set -eu

# iPhone 6.5inch（1284x2778 / 1242x2688）向けに Simulator でスクリーンショットを撮る。
# 出力先: SCREENSHOT_DIR（未指定なら ./fastlane/screenshots/ja）

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# 広告なしの専用 Scheme / Configuration を使う（スクリーンショットに AdMob の広告を写さない）
SCHEME="${SCHEME:-NinjacordApp-Screenshot}"
CONFIGURATION="${CONFIGURATION:-NinjacordApp-Screenshot}"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$ROOT_DIR/fastlane/screenshots/ja}"
# DerivedData はリポジトリ外に置く。リポジトリ内に置くと、ビルドフェーズの
# SwiftLint が SPM 依存のソース（DerivedData/SourcePackages/checkouts）まで
# lint してしまい、大量の violation でビルドが失敗する。
DERIVED_DATA="${DERIVED_DATA:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/NinjacordScreenshotDerivedData}"

mkdir -p "$SCREENSHOT_DIR"

device_type_id_for_name() {
    name="$1"
    xcrun simctl list -j devicetypes | python3 -c "
import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
for item in data.get('devicetypes', []):
    if item.get('name') == name:
        print(item['identifier'])
        sys.exit(0)
sys.exit(1)
" "$name"
}

latest_ios_runtime() {
    xcrun simctl list -j runtimes | python3 -c "
import json, sys
data = json.load(sys.stdin)
runtimes = [
    r for r in data.get('runtimes', [])
    if r.get('isAvailable') and str(r.get('name', '')).startswith('iOS')
]
if not runtimes:
    sys.exit(1)
runtimes.sort(key=lambda r: r.get('version', ''), reverse=True)
print(runtimes[0]['identifier'])
"
}

if ! RUNTIME_ID="$(latest_ios_runtime)"; then
    echo "iOS Simulator runtime が見つからないためダウンロードします"
    xcodebuild -downloadPlatform iOS
    RUNTIME_ID="$(latest_ios_runtime)"
fi
echo "Using runtime: $RUNTIME_ID"

SIM_NAME="Ninjacord-6.5-Screenshot"
EXISTING_UDID="$(xcrun simctl list -j devices | python3 -c "
import json, sys
name = sys.argv[1]
runtime = sys.argv[2]
data = json.load(sys.stdin)
for runtime_name, devices in data.get('devices', {}).items():
    if runtime not in runtime_name:
        continue
    for device in devices:
        if device.get('name') == name and device.get('isAvailable'):
            print(device['udid'])
            sys.exit(0)
" "$SIM_NAME" "$RUNTIME_ID")"

UDID=""
if [ -n "$EXISTING_UDID" ]; then
    UDID="$EXISTING_UDID"
else
    for candidate in \
        "iPhone 14 Plus" \
        "iPhone 15 Plus" \
        "iPhone 13 Pro Max" \
        "iPhone 12 Pro Max" \
        "iPhone 11 Pro Max" \
        "iPhone XS Max" \
        "iPhone 16 Plus" \
        "iPhone 17 Pro Max"
    do
        if DEVICE_TYPE_ID=$(device_type_id_for_name "$candidate"); then
            echo "Trying device type: $candidate ($DEVICE_TYPE_ID)"
            if UDID=$(xcrun simctl create "$SIM_NAME" "$DEVICE_TYPE_ID" "$RUNTIME_ID"); then
                break
            fi
            UDID=""
        fi
    done
fi

if [ -z "$UDID" ]; then
    echo "6.5inch 向けの Simulator を作成できませんでした。" >&2
    xcrun simctl list devicetypes | grep -i iphone >&2 || true
    xcrun simctl list runtimes >&2 || true
    exit 1
fi

echo "Simulator UDID: $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --dataNetwork wifi \
    --wifiMode active \
    --wifiBars 3 \
    --cellularMode active \
    --cellularBars 4 \
    --batteryState charged \
    --batteryLevel 100 \
    --operatorName "" || true

echo "Building $SCHEME for Simulator..."
xcodebuild build \
    -project NinjacordApp.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED_DATA"

SETTINGS="$(xcodebuild -showBuildSettings \
    -project NinjacordApp.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED_DATA")"

BUILT_DIR="$(printf '%s\n' "$SETTINGS" | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')"
APP_NAME="$(printf '%s\n' "$SETTINGS" | awk -F' = ' '/ FULL_PRODUCT_NAME /{print $2; exit}')"
BUNDLE_ID="$(printf '%s\n' "$SETTINGS" | awk -F' = ' '/ PRODUCT_BUNDLE_IDENTIFIER /{print $2; exit}')"
APP_PATH="$BUILT_DIR/$APP_NAME"

echo "APP_PATH=$APP_PATH"
echo "BUNDLE_ID=$BUNDLE_ID"

xcrun simctl install "$UDID" "$APP_PATH"

capture_screen() {
    extra_args="$1"
    output_file="$2"
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    # shellcheck disable=SC2086
    xcrun simctl launch "$UDID" "$BUNDLE_ID" $extra_args
    sleep 8
    xcrun simctl io "$UDID" screenshot "$output_file"
}

capture_screen "-screenshot-demo" "$SCREENSHOT_DIR/01_send_message.png"
capture_screen "-screenshot-demo -screenshot-settings" "$SCREENSHOT_DIR/02_settings.png"

python3 - "$SCREENSHOT_DIR" <<'PY'
import os
import subprocess
import sys

directory = sys.argv[1]
accepted = {(1284, 2778), (1242, 2688)}
for name in sorted(os.listdir(directory)):
    if not name.lower().endswith(".png"):
        continue
    path = os.path.join(directory, name)
    info = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", path], text=True)
    width = height = None
    for line in info.splitlines():
        if "pixelWidth" in line:
            width = int(line.split()[-1])
        if "pixelHeight" in line:
            height = int(line.split()[-1])
    print(f"{name}: {width}x{height}")
    if (width, height) not in accepted:
        print(f"Resizing {name} to 1284x2778 for App Store 6.5inch")
        subprocess.check_call(["sips", "-z", "2778", "1284", path])
PY

echo "Screenshots saved to $SCREENSHOT_DIR"
ls -la "$SCREENSHOT_DIR"
