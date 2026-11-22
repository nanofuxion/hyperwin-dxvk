#!/bin/bash
# Builds an Android arm64 HwD3D DXVK zip (ABI 1) for HyperWin.
#
# Modes:
#   ./build.sh [name]                     Build the DXVK source tree in this branch (e.g. sarek).
#   ./build.sh upstream <tag> [repo-url]  Clone an upstream DXVK 2.1+ tag, apply patches/dxvk-android.patch, and build.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
NDK=${ANDROID_NDK:-${ANDROID_HOME:-$HOME/Library/Android/sdk}/ndk/27.2.12479018}
HOST_TAG=$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64
BIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin"
PAGES=-Wl,-z,max-page-size=16384

mkdir -p "$HERE/work" "$HERE/out"

CROSS="$HERE/work/android-arm64.ini"
cat > "$CROSS" <<EOF
[binaries]
c = '$BIN/aarch64-linux-android31-clang'
cpp = '$BIN/aarch64-linux-android31-clang++'
ar = '$BIN/llvm-ar'
strip = '$BIN/llvm-strip'

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
EOF

if [ "${1:-}" = "upstream" ]; then
  TAG=${2:?usage: ./build.sh upstream <tag> [repo-url]}
  URL=${3:-https://github.com/doitsujin/dxvk.git}
  SAFE=$(echo "$TAG" | tr -c 'A-Za-z0-9.\n' '-')
  SRC="$HERE/work/src-$SAFE"
  BUILD="$HERE/work/build-$SAFE"
  DISPLAY_NAME="DXVK ${TAG#v}"
  OUT_ZIP="$HERE/out/dxvk-$SAFE.zip"
  if [ ! -d "$SRC" ]; then
    git clone --branch "$TAG" --depth 1 --recurse-submodules --shallow-submodules "$URL" "$SRC"
    git -C "$SRC" apply "$HERE/patches/dxvk-android.patch" || \
      git -C "$SRC" apply --3way --ignore-whitespace "$HERE/patches/dxvk-android.patch"
  fi
  MESON_OPTS=(-Dnative_sdl2=disabled -Dnative_sdl3=disabled -Dnative_glfw=disabled)
else
  SRC="$HERE"
  BRANCH=$(git -C "$HERE" rev-parse --abbrev-ref HEAD)
  TAG=${1:-$BRANCH}
  SAFE=$(echo "$TAG" | tr -c 'A-Za-z0-9._-\n' '-')
  BUILD="$HERE/work/build-$SAFE"
  DISPLAY_NAME=${DXVK_DISPLAY_NAME:-"DXVK $TAG"}
  OUT_ZIP="$HERE/out/dxvk-$SAFE.zip"
  MESON_OPTS=()
fi

[ -d "$BUILD" ] || meson setup "$BUILD" "$SRC" --cross-file "$CROSS" --buildtype release "${MESON_OPTS[@]}"
meson configure "$BUILD" -Dc_link_args="$PAGES" -Dcpp_link_args="$PAGES"
ninja -C "$BUILD"

STAGE="$HERE/work/stage-$SAFE"
rm -rf "$STAGE"
mkdir -p "$STAGE"
for p in d3d11 dxgi d3d10 d3d9 d3d8; do
  for f in "$BUILD"/src/$p/libdxvk_*.so; do
    [ -f "$f" ] || continue
    "$BIN/llvm-strip" -o "$STAGE/$(basename "$f")" "$f"
  done
done
printf '{"name": "%s", "dxvk": "%s", "abi": 1}\n' "$DISPLAY_NAME" "$TAG" > "$STAGE/meta.json"
rm -f "$OUT_ZIP"
(cd "$STAGE" && zip -q -j "$OUT_ZIP" meta.json libdxvk_*.so)
echo "Built: $OUT_ZIP"
ls -lh "$OUT_ZIP"
