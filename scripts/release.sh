#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to your Developer ID Application certificate}"
: "${NOTARYTOOL_PROFILE:?Set NOTARYTOOL_PROFILE to your saved Keychain profile name}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then printf 'Release builds require Developer ID signing.\n' >&2; exit 1; fi

swift test
UNIVERSAL=1 CONFIGURATION=release scripts/build.sh
app="$PWD/build/Stop Stutter.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
mkdir -p dist
submission="$PWD/build/StopStutter-notarization.zip"
ditto -c -k --keepParent "$app" "$submission"
xcrun notarytool submit "$submission" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
archive="$PWD/dist/StopStutter-$version-universal.zip"
ditto -c -k --keepParent "$app" "$archive"
(cd dist && shasum -a 256 "$(basename "$archive")" > SHA256SUMS)
printf '\nSigned, notarized release: %s\n' "$archive"
