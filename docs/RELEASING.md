# Releasing

Use Xcode 26+, an installed **Developer ID Application** certificate, and a Keychain profile created with `xcrun notarytool store-credentials`. Never put a signing identity export, password, App Store Connect key, or notarization credentials in this repository.

1. Update the version/build number in `Resources/Info.plist`, the Settings version text, and `CHANGELOG.md`.
2. Complete `docs/TESTING.md`, including a real helper install and restoration check.
3. Build and notarize:

   ```bash
   SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
   NOTARYTOOL_PROFILE="your-keychain-profile" \
     ./scripts/release.sh
   ```

4. The script runs tests, builds Apple Silicon + Intel, signs the helper and app with hardened runtime and a secure timestamp, submits to Apple, staples the accepted ticket, validates it, and checks Gatekeeper.
5. Review the resulting `dist/StopStutter-VERSION-universal.zip` and `dist/SHA256SUMS` before attaching them to a GitHub release. The script does not publish automatically.

Do not publish an unnotarized helper build as a supported end-user download. Ad-hoc preview artifacts are for CI and interface development only. Validate both architectures with `lipo -archs` on **both** executables.

## Updating an installed helper

For the initial release, updates are manual. In the installed version, turn boost off, remove the helper in Settings, and quit before replacing the app. Open the new version and enable its helper again. This follows Apple's requirement to re-register after the daemon executable or plist changes. Do not replace a live bundle during enforcement.

CI intentionally has no signing credentials. A maintainer performs signing and notarization on a trusted Mac. Contributions never run privileged network commands in CI.
