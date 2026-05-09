#!/bin/sh
set -eu

TARGET="GateLAN"
CONFIGURATION="Release"
BUILD_DIR="$(pwd)/build"
APP_PATH="$BUILD_DIR/Build/Products/$CONFIGURATION-iphoneos/$TARGET.app"
IPA_PATH="$(pwd)/GateLAN.ipa"

xcodebuild \
  -project GateLAN.xcodeproj \
  -target "$TARGET" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

rm -rf "$BUILD_DIR/Payload" "$IPA_PATH"
mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP_PATH" "$BUILD_DIR/Payload/"

(
  cd "$BUILD_DIR"
  zip -qry "$IPA_PATH" Payload
)

echo "Created $IPA_PATH"
