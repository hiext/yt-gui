#!/usr/bin/env bash
set -euo pipefail

# macOS FFmpeg 自建签名+Notarize 发布流程模板
# 需要 Xcode 14+、Developer ID Application 证书、notarytool 可用。

# 配置项：请根据你的环境修改以下值。
FFMPEG_VERSION="8.1.1"
FFMPEG_SRC_DIR="$PWD/ffmpeg-src"
FFMPEG_BUILD_DIR="$PWD/ffmpeg-build"
FFMPEG_DIST_DIR="$PWD/ffmpeg-dist"
OUTPUT_DIR="$PWD/release"
SIGN_IDENTITY="Developer ID Application: Your Company Name (TEAMID)"
NOTARY_PROFILE="notarytool-password"
NOTARIZE_FILE_NAME="ffmpeg-${FFMPEG_VERSION}-macos.zip"
NOTARIZE_BUNDLE_NAME="ffmpeg-${FFMPEG_VERSION}-macos"

# 如果你想使用 DMG 分发，可以改为 ffmpeg-${FFMPEG_VERSION}-macos.dmg
NOTARIZE_ARTIFACT="$OUTPUT_DIR/$NOTARIZE_FILE_NAME"

# 下面两个值仅在你没有将凭证存到本地 keychain 时才需要
APPLE_ID=""
TEAM_ID=""

function ensure_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    exit 1
  fi
}

function info() {
  echo "[info] $*"
}

function build_ffmpeg() {
  info "Preparing directories"
  mkdir -p "$FFMPEG_SRC_DIR" "$FFMPEG_BUILD_DIR" "$FFMPEG_DIST_DIR" "$OUTPUT_DIR"

  if [ ! -d "$FFMPEG_SRC_DIR/.git" ]; then
    info "Cloning FFmpeg source"
    git clone https://git.ffmpeg.org/ffmpeg.git "$FFMPEG_SRC_DIR"
  fi

  pushd "$FFMPEG_SRC_DIR" >/dev/null
  git fetch --tags --prune
  git checkout "n${FFMPEG_VERSION}" || git checkout "release/${FFMPEG_VERSION}" || true
  git pull --ff-only || true
  popd >/dev/null

  cd "$FFMPEG_SRC_DIR"
  info "Configuring FFmpeg"
  ./configure \
    --prefix=/usr/local/ffmpeg \
    --disable-debug \
    --enable-gpl \
    --enable-nonfree \
    --enable-static \
    --disable-shared \
    --disable-doc \
    --disable-ffplay \
    --disable-ffprobe \
    --disable-avdevice \
    --disable-postproc \
    --enable-libx264 \
    --enable-libx265 \
    --extra-cflags='-mmacosx-version-min=10.13' \
    --extra-ldflags='-mmacosx-version-min=10.13'

  info "Building FFmpeg"
  make -j"$(sysctl -n hw.ncpu)"
  make install DESTDIR="$FFMPEG_DIST_DIR"
}

function sign_ffmpeg() {
  local binary="$FFMPEG_DIST_DIR/usr/local/ffmpeg/bin/ffmpeg"
  if [ ! -f "$binary" ]; then
    echo "ERROR: ffmpeg binary not found at $binary" >&2
    exit 1
  fi

  info "Signing ffmpeg executable"
  codesign --force --timestamp --options runtime \
    --sign "$SIGN_IDENTITY" \
    "$binary"

  info "Verifying signature"
  codesign -vvv --strict "$binary"
  spctl -a -vv "$binary"
}

function package_artifact() {
  local staging="$OUTPUT_DIR/$NOTARIZE_BUNDLE_NAME"
  rm -rf "$staging"
  mkdir -p "$staging"
  cp "$FFMPEG_DIST_DIR/usr/local/ffmpeg/bin/ffmpeg" "$staging/"

  info "Creating ZIP archive for notarization"
  pushd "$OUTPUT_DIR" >/dev/null
  ditto -c -k --keepParent "$NOTARIZE_BUNDLE_NAME" "$NOTARIZE_FILE_NAME"
  popd >/dev/null

  if [ ! -f "$NOTARIZE_ARTIFACT" ]; then
    echo "ERROR: artifact creation failed" >&2
    exit 1
  fi
}

function notarize_artifact() {
  info "Submitting artifact to Apple notary service"

  local submit_cmd=(
    xcrun notarytool submit "$NOTARIZE_ARTIFACT"
    --keychain-profile "$NOTARY_PROFILE"
    --wait
  )

  if [ -n "$APPLE_ID" ]; then
    submit_cmd+=(--apple-id "$APPLE_ID")
  fi
  if [ -n "$TEAM_ID" ]; then
    submit_cmd+=(--team-id "$TEAM_ID")
  fi

  "${submit_cmd[@]}"
}

function main() {
  ensure_tool git
  ensure_tool make
  ensure_tool xcrun
  ensure_tool codesign
  ensure_tool spctl
  ensure_tool ditto
  ensure_tool shasum

  build_ffmpeg
  sign_ffmpeg
  package_artifact
  notarize_artifact

  info "Notarization finished. Artifact: $NOTARIZE_ARTIFACT"
  info "Compute SHA256 for release metadata"
  shasum -a 256 "$NOTARIZE_ARTIFACT"
}

main "$@"
