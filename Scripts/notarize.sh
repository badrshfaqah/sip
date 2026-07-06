#!/bin/bash
# =============================================================
# توقيع (Code Signing) وتوثيق (Notarization) ملف DMG
#
# قبل التشغيل، جهّز ملف Scripts/notarization.env (غير مُتتبَّع في git):
#   SIGNING_IDENTITY="Developer ID Application: Your Company (TEAMID)"
#   APPLE_ID="you@company.com"
#   TEAM_ID="TEAMID"
#   APP_PASSWORD="app-specific-password"   # من appleid.apple.com
#
# الاستخدام:
#   ./Scripts/notarize.sh
# =============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="$ROOT/dist/DeveloperSoftPhone.dmg"
ENV_FILE="$ROOT/Scripts/notarization.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "خطأ: أنشئ الملف $ENV_FILE أولاً (انظر التعليمات أعلى هذا السكربت)."
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

if [ ! -f "$DMG_PATH" ]; then
  echo "خطأ: لم يتم العثور على $DMG_PATH — شغّل ./Scripts/build_dmg.sh أولاً."
  exit 1
fi

APP_BUNDLE="$(ls -d "$ROOT"/build/export/*.app | head -1)"

echo "==> توقيع التطبيق"
codesign --force --deep --options runtime \
  --sign "$SIGNING_IDENTITY" \
  "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "==> إعادة بناء DMG بعد التوقيع"
STAGING="$ROOT/build/dmg-staging-signed"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Developer SoftPhone" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"

echo "==> توقيع DMG"
codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"

echo "==> إرسال للتوثيق (Notarization) — قد يستغرق دقائق"
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_PASSWORD" \
  --wait

echo "==> ختم التوثيق (Stapling)"
xcrun stapler staple "$DMG_PATH"

echo "==> تم! الملف جاهز للتوزيع: $DMG_PATH"
