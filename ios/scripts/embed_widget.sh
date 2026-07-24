#!/bin/sh

/bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" embed_and_thin

APP_BUNDLE="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
RUNNER_ENTITLEMENTS="${SRCROOT}/Runner/Runner.entitlements"
WIDGET_DST="${APP_BUNDLE}/PlugIns/PetWidget.appex"
WIDGET_ENTITLEMENTS="${SRCROOT}/PetWidget/PetWidget.entitlements"
if [ "${CONFIGURATION}" = "Debug" ] && [ -f "${SRCROOT}/PetWidget/PetWidgetDebug.entitlements" ]; then
  WIDGET_ENTITLEMENTS="${SRCROOT}/PetWidget/PetWidgetDebug.entitlements"
fi
PLATFORM_NAME="${EFFECTIVE_PLATFORM_NAME#-}"

if [ -z "${PLATFORM_NAME}" ]; then
  PLATFORM_NAME="iphoneos"
fi

# Resolve APP_GROUP_ID: build setting → Signing.xcconfig → entitlements → remote default
resolve_app_group_id() {
  if [ -n "${APP_GROUP_ID}" ] && [ "${APP_GROUP_ID#\$\(}" = "${APP_GROUP_ID}" ]; then
    printf '%s\n' "${APP_GROUP_ID}"
    return 0
  fi
  if [ -f "${SRCROOT}/Config/Signing.xcconfig" ]; then
    from_config="$(grep -E '^[[:space:]]*APP_GROUP_ID[[:space:]]*=' "${SRCROOT}/Config/Signing.xcconfig" | tail -1 | sed 's/.*=[[:space:]]*//;s/[[:space:]]*$//')"
    if [ -n "${from_config}" ] && [ "${from_config#\$\(}" = "${from_config}" ]; then
      printf '%s\n' "${from_config}"
      return 0
    fi
  fi
  from_plist="$(/usr/libexec/PlistBuddy -c "Print :com.apple.security.application-groups:0" "$RUNNER_ENTITLEMENTS" 2>/dev/null || true)"
  if [ -n "${from_plist}" ] && [ "${from_plist#\$\(}" = "${from_plist}" ]; then
    printf '%s\n' "${from_plist}"
    return 0
  fi
  printf '%s\n' "group.com.jnr.flutterPetMemorial"
}

APP_GROUP_ID="$(resolve_app_group_id)"
echo "Using APP_GROUP_ID=${APP_GROUP_ID}"

# codesign 不会展开 $(APP_GROUP_ID)，需生成已展开的临时 entitlements
make_expanded_entitlements() {
  out="$1"
  /usr/bin/plutil -create xml1 "$out"
  /usr/libexec/PlistBuddy -c "Add :com.apple.security.application-groups array" "$out" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :com.apple.security.application-groups:0 string ${APP_GROUP_ID}" "$out"
}

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

resolve_intents_src() {
  for candidate in \
    "${TARGET_BUILD_DIR}/PetWidgetIntents.appex" \
    "${BUILT_PRODUCTS_DIR}/PetWidgetIntents.appex" \
    "${CONFIGURATION_BUILD_DIR}/PetWidgetIntents.appex" \
    "${TARGET_BUILD_DIR}/../UninstalledProducts/${PLATFORM_NAME}/PetWidgetIntents.appex" \
    "${TARGET_BUILD_DIR}/../../IntermediateBuildFilesPath/UninstalledProducts/${PLATFORM_NAME}/PetWidgetIntents.appex" \
    "${BUILT_PRODUCTS_DIR}/../IntermediateBuildFilesPath/UninstalledProducts/${PLATFORM_NAME}/PetWidgetIntents.appex"; do
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

INTENTS_DST="${APP_BUNDLE}/PlugIns/PetWidgetIntents.appex"
INTENTS_SRC="$(resolve_intents_src || true)"

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

if [ -n "${INTENTS_SRC}" ] && [ -d "${INTENTS_SRC}" ]; then
  mkdir -p "${APP_BUNDLE}/PlugIns"
  rm -rf "${INTENTS_DST}"
  ditto "${INTENTS_SRC}" "${INTENTS_DST}"
  echo "Synced PetWidgetIntents.appex to ${INTENTS_DST}"
fi

TMP_ENTITLEMENTS="$(mktemp -t petwidget_entitlements).plist"
trap 'rm -f "$TMP_ENTITLEMENTS"' EXIT
make_expanded_entitlements "$TMP_ENTITLEMENTS"

if [ -d "$APP_BUNDLE" ]; then
  runner_entitlements="$(codesign -d --entitlements - "$APP_BUNDLE" 2>/dev/null || true)"
  if ! echo "$runner_entitlements" | grep -q "$APP_GROUP_ID"; then
    echo "Re-signing Runner with App Groups entitlements ($APP_GROUP_ID)"
    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" --entitlements "$TMP_ENTITLEMENTS" "$APP_BUNDLE"
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
  echo "Re-signing PetWidget with App Groups entitlements ($APP_GROUP_ID)"
  codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" --entitlements "$TMP_ENTITLEMENTS" "$WIDGET_DST"
  widget_entitlements="$(codesign -d --entitlements - "$WIDGET_DST" 2>/dev/null || true)"
fi

if echo "$widget_entitlements" | grep -q "$APP_GROUP_ID"; then
  echo "PetWidget App Groups entitlement OK ($APP_GROUP_ID)"
elif [ "${EFFECTIVE_PLATFORM_NAME}" = "-iphonesimulator" ]; then
  echo "warning: PetWidget App Groups not embedded on simulator ($APP_GROUP_ID)."
else
  echo "error: PetWidget missing App Groups entitlement ($APP_GROUP_ID). Check Signing.xcconfig and Developer Portal."
  exit 1
fi

if [ -d "$INTENTS_DST" ]; then
  intents_entitlements="$(codesign -d --entitlements - "$INTENTS_DST" 2>/dev/null || true)"
  if ! echo "$intents_entitlements" | grep -q "$APP_GROUP_ID"; then
    echo "Re-signing PetWidgetIntents with App Groups entitlements ($APP_GROUP_ID)"
    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" --entitlements "$TMP_ENTITLEMENTS" "$INTENTS_DST"
  fi
fi
