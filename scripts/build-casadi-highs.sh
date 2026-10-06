#!/bin/bash
# Build libhighs + libcasadi_conic_highs as a drop-in replacement for the pair
# bundled in the CasADi abi3 wheels. Uses CasADi's own HiGHS build
# (WITH_BUILD_HIGHS), so only the HiGHS version differs from the official wheel.
#
# Run inside quay.io/pypa/manylinux_2_28_<arch>, or for win_amd64 inside the MXE
# image CasADi builds its wheels with: the plugin links the wheel's libstdc++.
set -euo pipefail

HIGHS_VERSION="${HIGHS_VERSION:-v1.15.1}"
CASADI_VERSION="${CASADI_VERSION:-3.8.1}"
BUILD_DIR="${BUILD_DIR:-build-casadi}"
OUT_DIR="${OUT_DIR:-dist/casadi-${CASADI_VERSION}-highs-${HIGHS_VERSION}}"
patch_dir="$(cd "$(dirname "$0")/../patches" && pwd)"

src="$BUILD_DIR/casadi-src"
if [[ ! -d "$src" ]]; then
  git clone --depth 1 --branch "$CASADI_VERSION" https://github.com/casadi/casadi.git "$src"
fi
git -C "$src" checkout -- .
git -C "$src" apply "$patch_dir"/*.patch

# MXE targets the Windows XP API, which lacks the processor-group calls newer HiGHS makes
[[ "${CXX:-}" == *mingw* ]] && export CXXFLAGS="${CXXFLAGS:-} -D_WIN32_WINNT=0x0601"

# The thread flags must match the wheel's include/casadi/config.h, or class layouts differ.
cmake -S "$src" -B "$BUILD_DIR/casadi-build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_HIGHS=ON \
  -DWITH_BUILD_HIGHS=ON \
  -DWITH_THREAD=ON \
  -DWITH_THREADSAFE_SYMBOLICS=ON \
  -DBUILD_HIGHS_VERSION="$HIGHS_VERSION"
cmake --build "$BUILD_DIR/casadi-build" --target casadi_conic_highs -j"$(nproc)"

build="$BUILD_DIR/casadi-build"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
if [[ -f "$build/libcasadi_conic_highs.dll" ]]; then
  cp "$build/external_projects/bin/libhighs.dll" "$build/libcasadi_conic_highs.dll" "$OUT_DIR/"
else
  cp -P "$build"/external_projects/lib/libhighs.so* "$build"/lib/libcasadi_conic_highs.so* "$OUT_DIR/"
  # The wheel resolves libhighs.so.1 from the plugin's own directory.
  patchelf --set-rpath '$ORIGIN' "$OUT_DIR"/libcasadi_conic_highs.so.*
fi
ls -la "$OUT_DIR"
