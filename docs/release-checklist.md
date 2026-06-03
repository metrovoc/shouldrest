# Release Checklist

This checklist covers local verification plus the remaining Developer ID distribution work.

## Local Verification

- Run `scripts/verify_release_local.sh /path/to/stretchly/app/utils/defaultSettings.js`.
- This verifies Stretchly settings-key coverage, `git diff --check`, `swift test`, app build, `shouldrest://` URL scheme, bundle identifier, localization and sound resources, strict app codesign, first-run GUI smoke against a temporary support directory, ad-hoc DMG creation, and `hdiutil verify`.
- On machines without Developer ID credentials, the script uses `ALLOW_ADHOC=1` by default for the local DMG dry run.

## Manual GUI Smoke

- Launch `dist/ShouldRest.app`.
- On a clean user account, verify the first-run onboarding window appears.
- Open Preferences and verify the scroll view exposes scheduling, context, app exclusions, presentation, content, shortcuts, operations, and admin controls.
- Use `Take Eye Gate Now` only when ready for the strong full-screen overlay.
- Use `Take Body Break Now` to verify content, optional image, and manual finish behavior.

## Apple Distribution

- Store notarization credentials once, for example:
  `xcrun notarytool store-credentials shouldrest-notary --apple-id <apple-id> --team-id <team-id>`.
- Build a signed DMG without notarization:
  `SIGN_IDENTITY="Developer ID Application: ..." scripts/release_app.sh`.
- Or let the script select the first installed Developer ID Application identity:
  `scripts/release_app.sh`.
- Verify the release packaging flow on a machine without Developer ID credentials:
  `ALLOW_ADHOC=1 scripts/release_app.sh`.
- Confirm `codesign --display --verbose=2 dist/ShouldRest.app` shows the Developer ID identity and runtime option.
- Notarize and staple the DMG:
  `NOTARIZE=1 NOTARY_KEYCHAIN_PROFILE=shouldrest-notary scripts/release_app.sh`.
- Alternatively notarize with direct CI secrets:
  `NOTARIZE=1 APPLE_ID=<apple-id> APPLE_TEAM_ID=<team-id> APPLE_APP_SPECIFIC_PASSWORD=<password> scripts/release_app.sh`.
- Confirm `xcrun stapler validate dist/ShouldRest-<version>.dmg` passes after notarization.
- Re-run GUI smoke on a clean user account.
