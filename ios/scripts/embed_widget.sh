#!/bin/sh

/bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" embed_and_thin

APP_BUNDLE="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
RUNNER_ENTITLEMENTS="${SRCROOT}/Runner/Runner.entitlements"
WIDGET_DST="${APP_BUNDLE}/PlugIns/PetWidget.appex"
WIDGET_ENTITLEMENTS="${SRCROOT}/PetWidget/PetWidget.entitlements"
PLATFORM_NAME="${EFFECTIVE_PLATFORM_NAME#-}"

if [ -z "${PLATFORM_NAME}" ]; then
  PLATFORM_NAME="iphoneos"
fi

if [ -z "${APP_GROUP_ID}" ]; then
  APP_GROUP_ID="$(/usr/libexec/PlistBuddy -c "Print :com.apple.security.application-groups:0" "$RUNNER_ENTITLEMENTS" 2>/dev/null || true)"
fi
if [ -z "${APP_GROUP_ID}" ] || [ "${APP_GROUP_ID#$\(}" != "${APP_GROUP_ID}" ]; then
  APP_GROUP_ID="group.com.example.flutterPetMemorial"
fi

resolve_widget_src() {
  for candidate in \
    "${TARGET_BUILD_DIR}/PetWidget.appex" \
    "${BUILT_PRODUCTS_DIR}/PetWidget.appex" \
    "${CONFIGURATION_BUILD_DIR}/PetWidget.appex" \
    "${TARGET_BUILD_DIR}/../UninstalledProducts/${PLATFORM_NAME}/PetWidget.appex" \
    "${TARGET_BUILD_DIR}/../../IntermediateBuildFilesPath/UninstalledProducts/${PLATFORM_NAME}/PetWidget.appex" \
    "${BUILT_PRODUCTS_DIR}/../IntermediateBuildFilesPath/UninstalledProducts/${PLATFORM_NAME}/PetWidget.appex"; do
    if [ -e "${candidate}" ]; then
      if [ -L "${candidate}" ]; then
        python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "${candidate}"
      else
        printf '%s\n' "${candidate}"
      fi
      return 0
    fi
  done
  return 1
}

WIDGET_SRC="$(resolve_widget_src || true)"

if [ -n "${WIDGET_SRC}" ] && [ -d "${WIDGET_SRC}" ]; then
  mkdir -p "${APP_BUNDLE}/PlugIns"
  rm -rf "${WIDGET_DST}"
  # Copy real files; never leave a symlink in PlugIns (breaks archive validation).
  ditto "${WIDGET_SRC}" "${WIDGET_DST}"
  echo "Synced PetWidget.appex to ${WIDGET_DST}"
elif [ "${DEPLOYMENT_POSTPROCESSING}" = "YES" ]; then
  echo "error: PetWidget.appex not found for archive embed (platform=${PLATFORM_NAME})."
  exit 1
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

if [ ! -f "$WIDGET_DST/Info.plist" ]; then
  echo "error: PetWidget.appex missing Info.plist at $WIDGET_DST"
  exit 1
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
  echo "error: PetWidget missing App Groups entitlement ($APP_GROUP_ID). Check Signing.xcconfig and Developer Portal."
  exit 1
fi
