#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

configuration="${CONFIGURATION:-release}"
identity="${SIGNING_IDENTITY:--}"
app="$PWD/build/Stop Stutter.app"
# SwiftPM's Swift Build engine can otherwise stamp the minimum OS as the linked SDK.
# Correct SDK metadata is required for native Liquid Glass's linked-on-or-after behavior.
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
build_args=(-c "$configuration" -Xlinker -platform_version -Xlinker macos -Xlinker 14.0 -Xlinker "$sdk_version")
if [[ "${UNIVERSAL:-0}" == 1 ]]; then build_args+=(--arch arm64 --arch x86_64); fi

swift build "${build_args[@]}"
bin_dir="$(swift build "${build_args[@]}" --show-bin-path)"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Library/LaunchDaemons"
cp "$bin_dir/StopStutter" "$app/Contents/MacOS/StopStutter"
cp "$bin_dir/StopStutterHelper" "$app/Contents/MacOS/StopStutterHelper"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/io.github.burakgon.StopStutter.Helper.plist "$app/Contents/Library/LaunchDaemons/"
swift scripts/make-icon.swift "$app/Contents/Resources"

sign_options=(--force --sign "$identity" --options runtime)
if [[ "$identity" != "-" ]]; then sign_options+=(--timestamp); fi
codesign "${sign_options[@]}" --identifier io.github.burakgon.StopStutter.Helper "$app/Contents/MacOS/StopStutterHelper"
codesign "${sign_options[@]}" --identifier io.github.burakgon.StopStutter "$app"
codesign --verify --deep --strict --verbose=2 "$app"
printf '\nBuilt: %s\n' "$app"
if [[ "$identity" == "-" ]]; then
    printf 'Ad-hoc preview build: privileged helper access is intentionally unavailable.\n'
fi
