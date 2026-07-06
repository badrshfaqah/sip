#!/bin/bash
# =============================================================
# بناء Developer SoftPhone وإخراجه بصيغة DMG
# يدعم Apple Silicon + Intel (Universal Binary)
#
# الاستخدام:
#   ./Scripts/build_dmg.sh
#
# المتطلبات (تُثبَّت مرة واحدة):
#   brew install xcodegen
# =============================================================
set -euo pipefail

APP_NAME="Developer SoftPhone"
SCHEME="DeveloperSoftPhone"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_PATH="$DIST_DIR/DeveloperSoftPhone.dmg"

cd "$ROOT"

echo "==> 1/5 توليد مشروع Xcode"
xcodegen generate

echo "==> 2/5 أرشفة التطبيق (Universal: arm64 + x86_64)"
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"
xcodebuild archive \
  -project "$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  | tail -5

APP_PATH="$ARCHIVE_PATH/Products/Applications/$SCHEME.app"
if [ ! -d "$APP_PATH" ]; then
  # بعض إعدادات التسمية تنتج التطبيق باسم العرض
  APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
fi

echo "==> 3/5 نسخ التطبيق"
mkdir -p "$EXPORT_PATH"
cp -R "$APP_PATH" "$EXPORT_PATH/"
APP_BUNDLE="$(ls -d "$EXPORT_PATH"/*.app | head -1)"

echo "==> 4/5 إنشاء DMG"
STAGING="$BUILD_DIR/dmg-staging"
mkdir -p "$STAGING"
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG_PATH"

echo "==> 5/5 تم!"
echo "الناتج: $DMG_PATH"
echo ""
echo "لتوقيع وتوثيق DMG للتوزيع خارج App Store:"
echo "  ./Scripts/notarize.sh"
