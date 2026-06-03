# ShouldRest

ShouldRest is a Mac-first rest reminder built around short, frequent, hard-to-ignore Eye Gates and configurable Body Breaks.

The product keeps Stretchly-compatible scheduling, automation, update, debug, and preference capabilities where they support real rest behavior. It intentionally diverges from weak 20-second skip/postpone flows by making Eye Gate opaque, full-screen, and strict by default.

## Release Status

Current release: `0.1.21`

The public DMG is ad-hoc signed because this project is currently released without a paid Apple Developer account. That means the app is not notarized by Apple. On macOS, first launch may require using Finder's Open action or approving the app in Privacy & Security.

## Local Verification

Run:

```bash
scripts/verify_release_local.sh /tmp/stretchly-research/app/utils/defaultSettings.js
```

This checks Stretchly settings and command coverage, localization key coverage, tests, app bundle metadata, packaged resources, strict codesign verification, GUI smoke, local DMG creation, and `hdiutil verify`.
