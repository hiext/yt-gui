#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <path-to-app> <output-zip>" >&2
  exit 64
fi

APP_PATH="$1"
OUTPUT_ZIP="$2"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 66
fi

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 65
  fi
}

decode_base64() {
  if printf '' | base64 --decode >/dev/null 2>&1; then
    base64 --decode
  else
    base64 -D
  fi
}

require_env MACOS_CERTIFICATE_P12_BASE64
require_env MACOS_CERTIFICATE_PASSWORD
require_env MACOS_CODESIGN_IDENTITY

RUNNER_TEMP="${RUNNER_TEMP:-/tmp}"
KEYCHAIN_PASSWORD="${MACOS_KEYCHAIN_PASSWORD:-$(uuidgen)}"
KEYCHAIN_PATH="$RUNNER_TEMP/hiext-signing.keychain-db"
CERTIFICATE_PATH="$RUNNER_TEMP/developer-id-application.p12"
NOTARY_ZIP="$RUNNER_TEMP/hiext-yt-gui-notary.zip"
ASC_KEY_PATH="$RUNNER_TEMP/AuthKey.p8"

cleanup() {
  security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
  rm -f "$CERTIFICATE_PATH" "$NOTARY_ZIP" "$ASC_KEY_PATH"
}
trap cleanup EXIT

printf '%s' "$MACOS_CERTIFICATE_P12_BASE64" | decode_base64 > "$CERTIFICATE_PATH"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERTIFICATE_PATH" \
  -P "$MACOS_CERTIFICATE_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12 \
  -k "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | tr -d '"')
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

xattr -cr "$APP_PATH" || true

sign_code() {
  codesign --force --timestamp --options runtime --sign "$MACOS_CODESIGN_IDENTITY" "$1"
}

while IFS= read -r -d '' candidate; do
  if file "$candidate" | grep -q 'Mach-O'; then
    sign_code "$candidate"
  fi
done < <(find "$APP_PATH" -type f -print0)

if [[ -d "$APP_PATH/Contents/Frameworks" ]]; then
  while IFS= read -r -d '' framework; do
    sign_code "$framework"
  done < <(find "$APP_PATH/Contents/Frameworks" -type d -name '*.framework' -prune -print0)
fi

codesign \
  --force \
  --timestamp \
  --options runtime \
  --entitlements macos/Runner/Release.entitlements \
  --sign "$MACOS_CODESIGN_IDENTITY" \
  "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

notary_args=(--wait)
if [[ -n "${APP_STORE_CONNECT_API_KEY_BASE64:-}" && -n "${APP_STORE_CONNECT_API_KEY_ID:-}" && -n "${APP_STORE_CONNECT_API_KEY_ISSUER_ID:-}" ]]; then
  printf '%s' "$APP_STORE_CONNECT_API_KEY_BASE64" | decode_base64 > "$ASC_KEY_PATH"
  notary_args+=(--key "$ASC_KEY_PATH" --key-id "$APP_STORE_CONNECT_API_KEY_ID" --issuer "$APP_STORE_CONNECT_API_KEY_ISSUER_ID")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  notary_args+=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD")
else
  echo "Missing notarization credentials. Provide App Store Connect API key secrets or APPLE_ID/APPLE_TEAM_ID/APPLE_APP_SPECIFIC_PASSWORD." >&2
  exit 65
fi

ditto -c -k --keepParent "$APP_PATH" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" "${notary_args[@]}"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

mkdir -p "$(dirname "$OUTPUT_ZIP")"
ditto -c -k --keepParent "$APP_PATH" "$OUTPUT_ZIP"
