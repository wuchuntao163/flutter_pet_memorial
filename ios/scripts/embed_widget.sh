#!/bin/sh

/bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" embed_and_thin

APP_BUNDLE="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
RUNNER_ENTITLEMENTS="${SRCROOT}/Runner/Runner.entitlements"
WIDGET_DST="${APP_BUNDLE}/PlugIns/PetWidget.appex"
WIDGET_SRC="${TARGET_BUILD_DIR}/PetWidget.appex"
if [ ! -d "$WIDGET_SRC" ]; then
  WIDGET_SRC="${BUILT_PRODUCTS_DIR}/PetWidget.appex"
fi
if [ ! -d "$WIDGET_SRC" ]; then
  WIDGET_SRC="${TARGET_BUILD_DIR}/../UninstalledProducts/iphoneos/PetWidget.appex"
fi
WIDGET_ENTITLEMENTS="${SRCROOT}/PetWidget/PetWidget.entitlements"

if [ -z "${APP_GROUP_ID}" ]; then
  APP_GROUP_ID="$(/usr/libexec/PlistBuddy -c "Print :com.apple.security.application-groups:0" "$RUNNER_ENTITLEMENTS" 2>/dev/null || true)"
fi
if [ -z "${APP_GROUP_ID}" ] || [ "${APP_GROUP_ID#$\(}" != "${APP_GROUP_ID}" ]; then
  APP_GROUP_ID="group.com.example.flutterPetMemorial"
fi

if [ -d "$WIDGET_SRC" ]; then
  mkdir -p "${APP_BUNDLE}/PlugIns"
  rm -rf "$WIDGET_DST"
  cp -R "$WIDGET_SRC" "$WIDGET_DST"
  echo "Synced signed PetWidget.appex to PlugIns"
fi

if [ -d "$APP_BUNDLE" ] && [ -f "$RUNNER_ENTITLEMENTS" ]; then
  runner_entitlements="$(codesign -d --entitlements - "$APP_BUNDLE" 2>/dev/null || true)"
  if ! echo "$runner_entitlements" | grep -q "$APP_GROUP_ID"; then
    echo "Re-signing Runner with App Groups entitlements ($APP_GROUP_ID)"
    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" --entitlements "$RUNNER_ENTITLEMENTS" "$APP_BUNDLE"
  fi
fi

if [ ! -d "$WIDGET_DST" ]; then
  exit 0
fi

widget_entitlements="$(codesign -d --entitlements - "$WIDGET_DST" 2>/dev/null || true)"
if ! echo "$widget_entitlements" | grep -q "$APP_GROUP_ID"; then
  if [ -f "$WIDGET_ENTITLEMENTS" ]; then
    echo "Re-signing PetWidget with App Groups entitlements ($APP_GROUP_ID)"
    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" --entitlements "$WIDGET_ENTITLEMENTS" "$WIDGET_DST"
    widget_entitlements="$(codesign -d --entitlements - "$WIDGET_DST" 2>/dev/null || true)"
  fi
fi

if echo "$widget_entitlements" | grep -q "$APP_GROUP_ID"; then
  echo "PetWidget App Groups entitlement OK ($APP_GROUP_ID)"
elif [ "${EFFECTIVE_PLATFORM_NAME}" = "-iphonesimulator" ]; then
  echo "warning: PetWidget App Groups not embedded on simulator ($APP_GROUP_ID)."
else
  echo "error: PetWidget missing App Groups entitlement ($APP_GROUP_ID). Check Signing.local.xcconfig and Developer Portal."
  exit 1
fi
