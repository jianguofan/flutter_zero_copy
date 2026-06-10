#!/bin/bash
# Build the cube_renderer C++ executable and copy it to the expected location.
# Run from the project root: bash build_cube_renderer.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CUBE_DIR="$SCRIPT_DIR/cube_renderer"
BUILD_DIR="$CUBE_DIR/build"

# Find cmake (may be in /Applications/CMake.app)
if command -v cmake &>/dev/null; then
    CMAKE=cmake
elif [[ -x "/Applications/CMake.app/Contents/bin/cmake" ]]; then
    CMAKE="/Applications/CMake.app/Contents/bin/cmake"
else
    echo "ERROR: cmake not found. Install via: brew install cmake"
    exit 1
fi

BUILD_TYPE="${1:-Release}"
echo "=== Building cube_renderer ($BUILD_TYPE) ==="
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
"$CMAKE" .. -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
make -j"$(sysctl -n hw.ncpu)"

echo ""
# Sign the binary (required by macOS, otherwise taskgated kills it)
echo ""
echo "=== Signing binary ==="
codesign --sign - --force "$BUILD_DIR/cube_renderer" 2>/dev/null && echo "✓ Signed with ad-hoc signature"

echo ""
echo "=== Build complete ==="
echo "Binary: $BUILD_DIR/cube_renderer"
echo ""
echo "Run the Flutter app with: cd $SCRIPT_DIR && fvm flutter run -d macos"
