#!/bin/sh
# App Store Connect rejects IPAs that embed objective_c.framework when its
# arm64 slice is tagged IOSSIMULATOR (error 91169). That binary comes from
# Dart native-assets (path_provider_foundation >= 2.6 / package:objective_c)
# and can also linger in .dart_tool/hooks_runner after a pin/downgrade.
#
# For device / Archive builds we:
# 1) wipe stale native-asset caches that would re-embed the bad framework
# 2) remove objective_c.framework from the app if Flutter still copied it
# 3) re-sign the app so the sealed resource list matches
#
# Simulator builds are left alone.

set -e

if [ "${PLATFORM_NAME}" != "iphoneos" ]; then
  echo "strip_objective_c_framework: skip (PLATFORM_NAME=${PLATFORM_NAME})"
  exit 0
fi

REPO_ROOT="${SRCROOT}/.."
for CACHE in \
  "${REPO_ROOT}/.dart_tool/hooks_runner" \
  "${REPO_ROOT}/.dart_tool/hooks" \
  "${REPO_ROOT}/build/native_assets/ios"
do
  if [ -e "${CACHE}" ]; then
    echo "strip_objective_c_framework: removing stale cache ${CACHE}"
    rm -rf "${CACHE}"
  fi
done

FW_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/objective_c.framework"
REMOVED=0
if [ -d "${FW_DIR}" ]; then
  echo "strip_objective_c_framework: removing ${FW_DIR} (ASC 91169)"
  rm -rf "${FW_DIR}"
  REMOVED=1
fi

DYLIB="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/objective_c.dylib"
if [ -f "${DYLIB}" ]; then
  rm -f "${DYLIB}"
  REMOVED=1
fi

if [ "${REMOVED}" = "0" ]; then
  echo "strip_objective_c_framework: no objective_c.framework in app — OK"
  exit 0
fi

APP_PATH="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
if [ -d "${APP_PATH}" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY}" ] && [ "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]; then
  echo "strip_objective_c_framework: re-signing ${APP_PATH}"
  /usr/bin/codesign --force --deep --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
    --timestamp=none \
    "${OTHER_CODE_SIGN_FLAGS:-}" \
    "${APP_PATH}" || true
fi

echo "strip_objective_c_framework: done"
