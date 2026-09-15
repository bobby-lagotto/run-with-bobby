#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/AppStore/screenshots/iphone-6.9"
RAW_UI="$ROOT/AppStore/screenshots/raw"
DEVICE_NAME="${APPSTORE_SIMULATOR:-Bobby App Store}"
BUNDLE_ID="com.runwithbobby.app"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"

mkdir -p "$OUT_DIR" "$RAW_UI"

cd "$ROOT"

if xcrun simctl list devices | grep -q "$DEVICE_NAME ("; then
  UDID="$(xcrun simctl list devices | awk -v name="$DEVICE_NAME" '
    index($0, name "(") {
      if (match($0, /\(([A-F0-9-]{36})\)/)) {
        print substr($0, RSTART+1, RLENGTH-2)
        exit
      }
    }')"
else
  UDID="$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE")"
fi

if [[ -z "${UDID}" ]]; then
  echo "Could not resolve UDID for $DEVICE_NAME" >&2
  exit 1
fi

echo "Using simulator $DEVICE_NAME ($UDID)"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

xcodebuild \
  -project RunWithBobby.xcodeproj \
  -scheme RunWithBobby \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$ROOT/build/AppStoreDerivedData" \
  build

APP_PATH="$(find "$ROOT/build/AppStoreDerivedData/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name 'RunWithBobby.app' | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
  echo "RunWithBobby.app not found after build" >&2
  exit 1
fi

xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl privacy "$UDID" grant notifications "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$UDID" override \
  --time "9:41" \
  --dataNetwork wifi \
  --wifiBars 3 \
  --cellularMode active \
  --cellularBars 4 \
  --batteryState charged \
  --batteryLevel 100

capture_screen() {
  local screen="$1"
  local dest="$2"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -AppStoreScreenshots -AppStoreScreenshotScreen "$screen"
  sleep 5
  xcrun simctl io "$UDID" screenshot "$RAW_UI/$dest"
}

capture_screen chat 06-chat-raw.png
capture_screen oggi 07-oggi-raw.png
capture_screen piani 08-piani-raw.png

python3 - <<'PY'
from pathlib import Path
from PIL import Image

root = Path.cwd()
raw = root / "AppStore" / "screenshots" / "raw"
out_69 = root / "AppStore" / "screenshots" / "iphone-6.9"
out_65 = root / "AppStore" / "screenshots" / "iphone-6.5"
out_69.mkdir(parents=True, exist_ok=True)
out_65.mkdir(parents=True, exist_ok=True)
mapping = {
    "06-chat-raw.png": "06-chat.png",
    "07-oggi-raw.png": "07-oggi.png",
    "08-piani-raw.png": "08-piani.png",
}
for src_name, dst_name in mapping.items():
    image = Image.open(raw / src_name).convert("RGB")
    if image.size != (1320, 2868):
        image = image.resize((1320, 2868), Image.Resampling.LANCZOS)
    dest_69 = out_69 / dst_name
    image.save(dest_69, format="PNG", optimize=True)
    print(f"wrote {dest_69} {image.size}")
    image_65 = image.resize((1284, 2778), Image.Resampling.LANCZOS)
    dest_65 = out_65 / dst_name
    image_65.save(dest_65, format="PNG", optimize=True)
    print(f"wrote {dest_65} {image_65.size}")
PY

echo "UI screenshots saved in $OUT_DIR"
