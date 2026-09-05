#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="AwakeCat"
BUNDLE_ID="com.kuiyu.awakecat"
CONFIGURATION="${CONFIGURATION:-debug}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
ASSET_CATALOG="$ROOT_DIR/Resources/Assets.xcassets"
ASSET_PARTIAL_PLIST="$DIST_DIR/.AssetCatalogGeneratedInfo.plist"

case "$MODE" in
  run|--build-only|build-only|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify) ;;
  *)
    echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
case "$CONFIGURATION" in
  debug|release) ;;
  *) echo "CONFIGURATION must be debug or release" >&2; exit 2 ;;
esac

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build --package-path "$ROOT_DIR" --configuration "$CONFIGURATION"
BUILD_BINARY="$(swift build --package-path "$ROOT_DIR" --configuration "$CONFIGURATION" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$ROOT_DIR/Config/Info.plist" "$APP_CONTENTS/Info.plist"
cp "$ROOT_DIR/LICENSE" "$APP_RESOURCES/LICENSE"
chmod +x "$APP_BINARY"

xcrun actool "$ASSET_CATALOG" \
  --compile "$APP_RESOURCES" \
  --platform macosx \
  --minimum-deployment-target 15.0 \
  --target-device mac \
  --app-icon AppIcon \
  --standalone-icon-behavior all \
  --output-partial-info-plist "$ASSET_PARTIAL_PLIST" \
  --warnings \
  --notices \
  --errors \
  --output-format human-readable-text

# Pass file paths as arguments instead of embedding them in PlistBuddy syntax.
for icon_key in CFBundleIconName CFBundleIconFile; do
  icon_value="$(/usr/bin/plutil -extract "$icon_key" raw -expect string -o - "$ASSET_PARTIAL_PLIST")"
  /usr/bin/plutil -insert "$icon_key" -string "$icon_value" "$APP_CONTENTS/Info.plist"
done
rm -f "$ASSET_PARTIAL_PLIST"
test -s "$APP_RESOURCES/Assets.car"
test -s "$APP_RESOURCES/AppIcon.icns"

codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --build-only|build-only)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
