# Release Checklist

This checklist covers the remaining distribution work after the local package build.

## Local Build

- Run `scripts/build_app.sh`.
- Confirm `dist/ShouldRest.app/Contents/Info.plist` contains the `shouldrest://` URL scheme.
- Confirm `dist/ShouldRest.app/Contents/Resources/ShouldRest_shouldrest.bundle` contains localization resources.
- Confirm `codesign --verify --deep --strict dist/ShouldRest.app` passes.
- Run `swift test`.

## Manual GUI Smoke

- Launch `dist/ShouldRest.app`.
- On a fresh settings directory, verify the first-run onboarding window appears.
- Open Preferences and verify the scroll view exposes scheduling, context, app exclusions, presentation, content, shortcuts, operations, and admin controls.
- Use `Take Eye Gate Now` only when ready for the strong full-screen overlay.
- Use `Take Body Break Now` to verify content, optional image, and manual finish behavior.

## Apple Distribution

- Build with Developer ID signing: `SIGN_IDENTITY="Developer ID Application: ..." HARDENED_RUNTIME=1 scripts/build_app.sh`.
- Confirm `codesign --display --verbose=2 dist/ShouldRest.app` shows the Developer ID identity and runtime option.
- Notarize and staple the app.
- Package a DMG or installer.
- Re-run GUI smoke on a clean user account.
