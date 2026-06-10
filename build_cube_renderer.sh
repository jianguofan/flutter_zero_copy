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

echo "=== Building cube_renderer ==="
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
"$CMAKE" .. -DCMAKE_BUILD_TYPE=Release
make -j"$(sysctl -n hw.ncpu)"

echo ""
echo "=== Build complete ==="
echo "Binary: $BUILD_DIR/cube_renderer"
echo ""
echo "Run the Flutter app with: cd $SCRIPT_DIR && fvm flutter run -d macos"
