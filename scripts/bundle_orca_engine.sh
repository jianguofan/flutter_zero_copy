#!/bin/bash
# Bundle orca_engine into the macOS app during build.
set -e

ENGINE_SRC="${SRCROOT}/../../slicer-render-engine/orca_engine"
if [ -z "$SRCROOT" ]; then
  ENGINE_SRC="$(cd "$(dirname "$0")/.." && pwd)/slicer-render-engine/orca_engine"
fi

TARGET_DIR="${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"
if [ -z "$BUILT_PRODUCTS_DIR" ]; then
  TARGET_DIR="$(cd "$(dirname "$0")/../build/macos/Build/Products/Debug" && pwd)/flutter_zero_copy.app/Contents/MacOS"
fi

if [ -f "$ENGINE_SRC" ]; then
  echo "Bundling orca_engine: $ENGINE_SRC → $TARGET_DIR/"
  cp "$ENGINE_SRC" "$TARGET_DIR/orca_engine"
  chmod +x "$TARGET_DIR/orca_engine"
  echo "orca_engine bundled ($(stat -f%z "$TARGET_DIR/orca_engine") bytes)"
else
  echo "WARNING: orca_engine not found at $ENGINE_SRC"
fi
