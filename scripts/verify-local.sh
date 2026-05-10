#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CORE_DIR="$ROOT_DIR/BodyCoachCore"

cd "$ROOT_DIR"

echo "== Whitespace check =="
git diff --check

echo
echo "== Swift package tests =="
(
  cd "$CORE_DIR"
  CLANG_MODULE_CACHE_PATH="$CORE_DIR/.clang-module-cache" \
    swift test --disable-sandbox --scratch-path .build
)

echo
echo "== iOS build =="
xcodebuild \
  -project BodyCoachApp/BodyCoachApp.xcodeproj \
  -scheme BodyCoachApp \
  -destination 'generic/platform=iOS' \
  -derivedDataPath BodyCoachApp/.build/iOSDerived \
  CODE_SIGNING_ALLOWED=NO \
  build

echo
echo "== watchOS build =="
xcodebuild \
  -project BodyCoachApp/BodyCoachApp.xcodeproj \
  -scheme BodyCoachWatch \
  -destination 'generic/platform=watchOS' \
  -derivedDataPath BodyCoachApp/.build/WatchDerived \
  CODE_SIGNING_ALLOWED=NO \
  build

echo
echo "Local verification passed."
