#!/bin/bash
# Builds an Android arm64 HwD3D DXVK zip (ABI 1) for HyperWin.
#
# Modes:
#   ./build.sh upstream <tag> [repo-url]  Clone an upstream DXVK 2.1+ tag, apply patches/dxvk-android.patch, and build.
#   ./build.sh sarek <tag> [repo-url]     Clone a DXVK-Sarek tag, apply overlays/sarek + patches/sarek-android.patch, and build.
#   ./build.sh [name]                     Build a DXVK source tree checked out directly in this directory.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
if [ -z "${ANDROID_NDK:-}" ]; then
  if [ -d "$SDK/ndk/27.2.12479018" ]; then
    NDK="$SDK/ndk/27.2.12479018"
  else
    NDK=$(ls -d "$SDK"/ndk/* 2>/dev/null | sort -V | tail -n 1 || true)
  fi
else
  NDK="$ANDROID_NDK"
fi
[ -n "$NDK" ] && [ -d "$NDK" ] || { echo "Android NDK not found. Set ANDROID_NDK or ANDROID_HOME." >&2; exit 1; }

HOST_TAG=$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64
BIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin"
[ -x "$BIN/aarch64-linux-android31-clang++" ] || { echo "NDK clang not found under $BIN" >&2; exit 1; }
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

slug() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-' | sed 's/^-*//;s/-*$//'
}

apply_patch() {
  local src=$1 patchfile=$2
  git -C "$src" apply "$patchfile" 2>/dev/null \
    || git -C "$src" apply --ignore-whitespace "$patchfile" 2>/dev/null \
    || (cd "$src" && patch -p1 --forward --batch --fuzz=3 < "$patchfile")
}

MODE=${1:-}
MESON_OPTS=()

if [ "$MODE" = "upstream" ]; then
  TAG=${2:?usage: ./build.sh upstream <tag> [repo-url]}
  URL=${3:-https://github.com/doitsujin/dxvk.git}
  SAFE=$(slug "$TAG")
  SRC="$HERE/work/src-$SAFE"
  BUILD="$HERE/work/build-$SAFE${DXVK_LIB_SUFFIX:-}"
  STAGE="$HERE/work/stage-$SAFE${DXVK_LIB_SUFFIX:-}"
  DISPLAY_NAME=${DXVK_DISPLAY_NAME:-"DXVK ${TAG#v}"}
  OUT_ZIP="$HERE/out/dxvk-$SAFE${DXVK_LIB_SUFFIX:-}.zip"
  if [ ! -f "$SRC/.hyperwin-patched" ]; then
    rm -rf "$SRC"
    git clone --branch "$TAG" --depth 1 --recurse-submodules --shallow-submodules "$URL" "$SRC"
    apply_patch "$SRC" "$HERE/patches/dxvk-android.patch"
    touch "$SRC/.hyperwin-patched"
  fi
  MESON_OPTS=(-Dnative_sdl2=disabled -Dnative_sdl3=disabled -Dnative_glfw=disabled)
elif [ "$MODE" = "sarek" ]; then
  TAG=${2:?usage: ./build.sh sarek <tag> [repo-url]}
  URL=${3:-https://github.com/pythonlover02/DXVK-Sarek.git}
  SAFE="sarek-$(slug "$TAG")"
  SRC="$HERE/work/src-$SAFE"
  BUILD="$HERE/work/build-$SAFE${DXVK_LIB_SUFFIX:-}"
  STAGE="$HERE/work/stage-$SAFE${DXVK_LIB_SUFFIX:-}"
  DISPLAY_NAME=${DXVK_DISPLAY_NAME:-"DXVK-Sarek ${TAG#v}"}
  OUT_ZIP="$HERE/out/dxvk-$SAFE${DXVK_LIB_SUFFIX:-}.zip"
  if [ ! -f "$SRC/.hyperwin-patched" ]; then
    rm -rf "$SRC"
    git clone --branch "$TAG" --depth 1 --recurse-submodules --shallow-submodules "$URL" "$SRC"
    cp -a "$HERE/overlays/sarek/." "$SRC/"
    apply_patch "$SRC" "$HERE/patches/sarek-android.patch"
    touch "$SRC/.hyperwin-patched"
  fi
  if [ -n "${DXVK_LIB_SUFFIX:-}" ]; then
    MESON_OPTS+=("-Dlib_suffix=$DXVK_LIB_SUFFIX")
  fi
elif [ -f "$HERE/meson.build" ]; then
  SRC="$HERE"
  BRANCH=$(git -C "$HERE" rev-parse --abbrev-ref HEAD)
  TAG=${1:-$BRANCH}
  SAFE=$(slug "$TAG")
  BUILD="$HERE/work/build-$SAFE"
  STAGE="$HERE/work/stage-$SAFE"
  DISPLAY_NAME=${DXVK_DISPLAY_NAME:-"DXVK $TAG"}
  OUT_ZIP="$HERE/out/dxvk-$SAFE.zip"
  if [ -n "${DXVK_LIB_SUFFIX:-}" ]; then
    MESON_OPTS+=("-Dlib_suffix=$DXVK_LIB_SUFFIX")
  fi
else
  cat >&2 <<'USAGE'
usage:
  ./build.sh upstream <tag> [repo-url]   Build upstream DXVK 2.1+ (default: doitsujin/dxvk)
  ./build.sh sarek <tag> [repo-url]      Build DXVK-Sarek (default: pythonlover02/DXVK-Sarek)

examples:
  ./build.sh upstream v2.7.1
  ./build.sh sarek v1.14.1
USAGE
  exit 1
fi

[ -d "$BUILD" ] || meson setup "$BUILD" "$SRC" --cross-file "$CROSS" --buildtype release ${MESON_OPTS[@]+"${MESON_OPTS[@]}"}
meson configure "$BUILD" -Dc_link_args="$PAGES" -Dcpp_link_args="$PAGES"
ninja -C "$BUILD"

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
