#!/bin/bash
# Builds an unsigned WidgetSimple.ipa for AltStore / AltServer sideloading.
# AltStore signs the IPA with the user's own Apple ID when installing, so nothing here
# is signed. Run it from the repository root on a Mac with Xcode 27.
set -euo pipefail

rm -rf build
xcodebuild \
  -project WidgetSimple.xcodeproj \
  -scheme WidgetSimple \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  -archivePath build/WidgetSimple.xcarchive \
  archive

mkdir -p build/Payload
cp -R build/WidgetSimple.xcarchive/Products/Applications/WidgetSimple.app build/Payload/

(cd build && zip -qry WidgetSimple.ipa Payload)
ls -lh build/WidgetSimple.ipa
echo "IPA ready: build/WidgetSimple.ipa"
