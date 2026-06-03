# Stretchly Feature Audit

Reference baseline: `hovancik/stretchly` trunk at commit `f14012cc51e7944f4a6c93a75147f994e08b1f6e`, version `1.21.0`.

Upstream refresh on 2026-06-03 confirmed `origin/trunk` is still `f14012cc51e7944f4a6c93a75147f994e08b1f6e`.

Inspected source areas:

- `app/utils/defaultSettings.js`
- `app/breaksPlanner.js`
- `app/main.js`
- `app/utils/naturalBreaksManager.js`
- `app/utils/dndManager.js`
- `app/utils/appExclusionsManager.js`
- `app/utils/displayManager.js`
- `app/utils/breakShortcuts.js`
- `app/utils/commands.js`
- `app/break-renderer.js`
- `app/microbreak-renderer.js`
- `app/preferences.html`
- `app/contributor-preferences.html`

## Stretchly Mechanism

Stretchly is organized around two timer classes:

- Mini break: default 20 seconds every 10 minutes.
- Long break: default 5 minutes after two mini breaks, effectively at the third 10-minute slot.

The planner is a timeout-based state machine. It schedules notifications, starts break windows, postpones the current scheduled break, skips to mini/long break, pauses, resumes, resets, and corrects timers after suspend/resume.

The window layer uses Electron `BrowserWindow`. In non-regular mode it creates borderless, transparent, always-on-top windows, optionally across all displays. On macOS it uses `setVisibleOnAllWorkspaces(true)`, `setAlwaysOnTop(true, 'pop-up-menu')`, and kiosk/fullscreen handling, but not the native `.screenSaver` window level used by `../shouldsleep`.

The context layer monitors natural idle time, DND/Focus, and process-based app exclusions. Those context states can clear or reset the break scheduler.

The product surface includes tray menu controls, global shortcuts, CLI commands, notifications, sounds, break ideas, custom ideas, language support, update checks, local settings, debug/preferences info, contributor preferences, and sync preferences.

## Explicitly Not Copied

These Stretchly behaviors are design divergences, not missing features.

| Stretchly behavior | ShouldRest decision | Reason |
| --- | --- | --- |
| Mini breaks can be ordinarily postponed. | Eye Gate cannot be ordinarily postponed. Body Break keeps bounded postpone. | A 20-second rest is too short; postpone becomes muscle memory. |
| Mini breaks can be ordinarily skipped unless strict mode blocks it. | Eye Gate cannot be ordinarily skipped. Emergency override is separate and frictional. | Skip trains dismissal, not rest. |
| Strict mode defaults off. | Eye Gate is strict by default. | The biologically important unit is compliance, not reminder delivery. |
| Transparent and blurred break surfaces. | Eye Gate is opaque full-screen. Body Break may use styling, but enforced surfaces remain visually decisive. | Partial visibility invites continued screen work. |
| Rich mini-break ideas on screen. | Eye Gate avoids rich readable content. Rich ideas belong to Body Break. | Reading instructions is still near-screen visual work. |
| Regular/focusable break windows. | Enforced breaks use native overlay windows, not ordinary document-like windows. | Ordinary windows lose stacking authority and invite interaction. |
| DND/Focus globally pauses all breaks. | Focus defers Body Break by default, not Eye Gate. | Meetings should not erase the frequent eye-rest constraint. |
| Contributor-only preferences. | No paywall or contributor gate for core controls. | The safety-critical control surface should be coherent and available. |
| Account-based sync as a core feature. | Local JSON settings are core; sync is optional integration later. | The core app should remain local and deterministic. |
| Electron-first implementation. | Mac-first native AppKit implementation. | Native window levels are required for a strong overlay on macOS. |

## Re-scoped, Not Removed

| Stretchly feature | ShouldRest equivalent |
| --- | --- |
| Mini break ideas | Removed from Eye Gate, retained for Body Break or pre-break education. |
| Skip/postpone | Removed from Eye Gate, retained with limits for Body Break. |
| DND monitoring | Used as context, defaulting to Body Break deferral only. |
| App exclusions | Supported with per-rest-kind targeting, so rules can pause Body Break without weakening Eye Gate. |
| Current time during breaks | Body Break only by default. |
| Break health/danger | Kept and strengthened: Eye Gate overrides increase danger; completed/natural rests reduce it. |
| Custom HTML/rich text | Body Break only, sanitized before rendering. |
| Fullscreen/all screens/content screen | Kept, but implemented with native multi-display overlays. |

## Required Superset Surface

ShouldRest must implement or exceed these Stretchly capabilities except where explicitly diverged above.

### Scheduling

- Independent enablement of Eye Gate and Body Break.
- Configurable interval and duration for both rest kinds.
- Body Break after a configurable number of Eye Gates.
- Pre-rest notification lead times.
- Manual take-now controls for both rest kinds.
- Reset, pause, resume, and Body Break skip-to-next.

### Enforcement

- Full-screen multi-display overlays.
- Native macOS `.screenSaver` level for enforced overlays.
- Screen topology reconciliation.
- Primary/content display selection with secondary-display blanking.
- Default strict Eye Gate.
- Bounded Body Break postpone and skip.
- Manual-finish support for Body Break.

### Context

- Natural rest credit from idle time.
- Suspend/lock correction.
- Focus/DND awareness.
- App exclusions with pause and resume-only semantics.
- Working-hours gating.

### Controls

- Menu bar status item.
- Pause for 30 minutes, 1 hour, 2 hours, 5 hours, until morning, or indefinitely.
- Global shortcuts.
- CLI or URL-style automation.
- Debug/status command.

### Presentation And Content

- System/light/dark theme.
- Configurable colors.
- Start/finish sounds and volume.
- Tray style: default, time-to-break, progress.
- Built-in Body Break ideas.
- Custom Body Break text and local images.
- Localization-ready strings.

### Operations And Administration

- Local JSON settings.
- Restore defaults.
- Open at login.
- Update checks with disable switch.
- Debug info: settings path, logs path, runtime state, timer state.
- Admin controls for update UI, strict preferences, settings path, and custom preferences message.

## Current Implementation Checkpoint

Implemented now:

- Swift package and git repository.
- Core settings model matching the audited capability groups.
- Pure rest engine for schedule/evaluate/start/complete/postpone/skip/override/pause/resume/reset.
- Eye Gate default: opaque, screen-saver-level, all-displays, no ordinary skip/postpone.
- Body Break default: rich content allowed, bounded postpone, ordinary skip, manual finish flag.
- Natural rest credit.
- Focus/DND policy: Body Break defers by default; Eye Gate does not.
- App exclusions with per-kind targeting and pause/resume-only semantics.
- JSON settings store.
- Built-in Eye Gate and Body Break idea library.
- Native menu bar app skeleton.
- Native AppKit overlay windows at `.screenSaver` level with all-spaces/full-screen auxiliary behavior.
- IOKit idle-time reader.
- NSWorkspace running-app matching for exclusions.
- UserNotifications-based pre-break notifications.
- Start/finish sound playback.
- Copyable debug snapshot from the menu.
- Native preferences window for core cadence, enablement, Focus policy, and tray style.
- Expanded preferences for notification lead times, overlay colors, sounds, Body Break postpone policy, natural break settings, working hours, primary app exclusion, custom Body Break idea, shortcuts, update settings, and admin controls.
- CLI command surface for help, version, settings/log paths, pause/resume/reset, take-now, preferences, and debug requests.
- Distributed notification bridge for CLI-to-running-app automation.
- Local log file.
- Custom rich-text sanitizer for Body Break content.
- Settings-store round-trip coverage.
- Open-at-login setting and ServiceManagement integration when running as a bundled app.
- Sleep, wake, lock, and unlock correction hooks.
- Debug panel with runtime state and paths.
- Global shortcut registration for pause, pause durations, take-now, Body Break skip-to-next, and reset.
- URL-style automation parser plus Apple Event URL handler for bundled app registration.
- Body Break manual-finish phase that lowers overlay level after the required duration and waits for user completion.
- Configurable active working-hours windows, including overnight windows.
- Update feed checks with manual menu action, launch-time checks, admin disable switch, and update notifications.
- SwiftPM localization resource bundle with English and Simplified Chinese strings for core menu, notification, status, debug, preferences, and overlay surfaces.
- Safe local image Body Break content path support and overlay renderer.
- Reproducible `.app` packaging script with `shouldrest://` URL-scheme Info.plist registration and localization resource bundling.
- Advanced app-exclusion JSON editor for multi-rule configurations, plus primary-rule form controls for common cases.
- Localized preference labels and CLI help in the SwiftPM resource bundle.
- First-run onboarding window that lets users accept the scientific defaults or open preferences.
- Packaged-app GUI smoke check using CoreGraphics window enumeration; verified `Welcome to ShouldRest` appears on-screen in `dist/ShouldRest.app`.
- Floating/all-spaces presentation for onboarding, preferences, and debug utility windows.
- AppKit theme application for system/light/dark preferences, admin preferences message display, and optional current time during Body Break.
- Packaged app build with default ad-hoc signing, optional Developer ID signing hook, optional hardened runtime hook, and strict `codesign` verification.
- Continuous context-deferral state for Focus, working-hours, and app-exclusion gates: first deferral raises break-health danger, repeated ticks do not double-count, and the due rest starts immediately when context clears.
- Stretchly-style display targeting for Body Break: all displays or a selected single display, primary/cursor/configured-display selection, separate content-display selection, optional secondary-display blanking, and backward-compatible settings decoding. Eye Gate still forces all-display coverage.
- Sanitized Body Break rich-text rendering with remote/inline HTML images stripped; images remain available through the explicit safe local-image channel.
- Complete global-shortcut preference surface for pause toggle, pause durations, pause until morning, immediate rests, Body Break skip-to-next, and reset; pause-until-morning shortcut is registered at runtime.
- Notification sound policy honors the silent-notifications setting for both pre-break and update notifications.
- Break-health danger is visible in the menu status surface, not only in debug output.
- Eye Gate emergency override is frictional in core and app surfaces: minimum hold duration and required confirmation steps are enforced before the override is counted as a missed Eye Gate, with a configurable global shortcut for screen-covering situations.

Still to implement:
- Developer ID signing identity selection, notarization, and installer/distribution polish.
