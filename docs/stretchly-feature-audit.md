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
| CLI/custom title injection for Mini breaks. | Eye Gate command starts the visual rest but does not accept custom readable title/body content. Body Break keeps custom title/body injection. | Eye Gate should not turn into an on-screen reading task. |
| Regular/focusable break windows. | Enforced breaks use native overlay windows, not ordinary document-like windows. | Ordinary windows lose stacking authority and invite interaction. |
| Percentage-sized active break windows (`breakWindowWidth` / `breakWindowHeight`). | Enforced rests cover the targeted display area; Body Break instead supports display targeting, content-display selection, and secondary blanking. | Partial active windows leave enough visual access to continue working. |
| Tray/menu actions during strict mini breaks (`showTrayMenuInStrictMode`). | Eye Gate exposes only a frictional emergency override while active. | Ordinary menu actions collapse strict mode back into habitual dismissal. |
| Monochrome/inverted tray icon variants. | ShouldRest uses Mac-native status text styles: default, time-to-break, and progress. | Brand/status clarity is more useful than copying Stretchly's icon-color matrix. |
| Configurable app-exclusion polling interval. | ShouldRest evaluates context on a fixed low-latency native loop. | This avoids exposing a performance tuning knob that is not part of the rest behavior. |
| DND/Focus globally pauses all breaks. | Focus defers Body Break by default, not Eye Gate. | Meetings should not erase the frequent eye-rest constraint. |
| Contributor-only preferences. | No paywall or contributor gate for core controls. | The safety-critical control surface should be coherent and available. |
| Account-based sync as a core feature. | Local JSON settings are core; sync is optional integration later. | The core app should remain local and deterministic. |
| Electron-first implementation. | Mac-first native AppKit implementation. | Native window levels are required for a strong overlay on macOS. |
| Stretchly's full translation catalog. | ShouldRest ships its own localization set, currently English and Simplified Chinese. | Translation breadth is brand/content rollout, not a copied rest-mechanism capability. |

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

## Stretchly Settings-Key Coverage

This table is a mechanical coverage pass over every key in Stretchly's `app/utils/defaultSettings.js`.
It is intended to catch gaps that are easy to miss when a behavior is exposed only through the JSON settings file or Contributor Preferences.

| Stretchly setting key | ShouldRest coverage |
| --- | --- |
| `microbreakDuration` | Implemented as Eye Gate duration. |
| `microbreakInterval` | Implemented as Eye Gate interval. |
| `breakDuration` | Implemented as Body Break duration. |
| `breakInterval` | Implemented as `bodyBreakAfterEyeGates`. |
| `breakNotification` | Implemented as Body Break pre-rest notification enablement. |
| `microbreakNotification` | Implemented as Eye Gate pre-rest notification enablement. |
| `breakNotificationInterval` | Implemented as Body Break notification lead time. |
| `microbreakNotificationInterval` | Implemented as Eye Gate notification lead time. |
| `microbreak` | Implemented as Eye Gate enablement, with a guard preventing both rest kinds from being disabled at once. |
| `break` | Implemented as Body Break enablement, with a guard preventing both rest kinds from being disabled at once. |
| `microbreakStrictMode` | Strengthened: Eye Gate is strict by design and has no ordinary skip/postpone path. |
| `breakStrictMode` | Implemented through Body Break ordinary-skip policy; when ordinary skip is disabled, active Body Break also blocks quit/reset bypasses. |
| `morningHour` | Implemented as configurable pause-until-morning hour, plus sunrise mode. |
| `microbreakPostpone` | Explicit divergence: Eye Gate has no ordinary postpone. |
| `breakPostpone` | Implemented as Body Break postpone enablement. |
| `microbreakPostponeTime` | Explicit divergence for Eye Gate; Body Break keeps configurable postpone duration. |
| `breakPostponeTime` | Implemented as Body Break postpone duration. |
| `microbreakPostponesLimit` | Explicit divergence for Eye Gate; Body Break keeps configurable limits. |
| `microbreakPostponableDurationPercent` | Explicit divergence for Eye Gate; Body Break keeps configurable postpone window. |
| `breakPostponesLimit` | Implemented as Body Break maximum postpones per cycle. |
| `breakPostponableDurationPercent` | Implemented as Body Break postpone-window percent. |
| `mainColor` | Implemented as Body Break color. |
| `miniBreakColor` | Implemented as Eye Gate color, while preserving opaque full-screen enforcement. |
| `transparentMode` | Explicit divergence for enforced rests: Eye Gate and enforced Body Break remain opaque. |
| `blurredBackground` | Explicit divergence for enforced rests: no blur/transparent surface that allows continued screen work. |
| `opacity` | Explicit divergence for enforced rests; opacity remains `1` for decisive overlays. |
| `longBreakAudio` | Implemented as Body Break finish sound, with Stretchly-compatible built-in sound assets. |
| `miniBreakAudio` | Implemented as Eye Gate finish sound, with Stretchly-compatible built-in sound assets. |
| `volume` | Implemented as shared sound volume. |
| `fullscreen` | Strengthened: enforced rests use native display coverage instead of a window/fullscreen toggle. |
| `ideas` | Implemented for Body Break; Eye Gate intentionally avoids rich on-screen ideas. |
| `naturalBreaks` | Implemented as idle-time natural rest credit. |
| `naturalBreaksInactivityResetTime` | Implemented as configurable natural idle threshold. |
| `allScreens` | Implemented for Body Break display coverage; Eye Gate always covers all displays. |
| `useIdeasFromSettings` | Implemented for Body Break through custom idea JSON; Eye Gate custom ideas are intentionally omitted. |
| `language` | Implemented as an in-app language override for bundled translations, currently System, English, and Simplified Chinese. Stretchly's full translation catalog is not copied because ShouldRest has its own localization rollout. |
| `notifyNewVersion` | Implemented as update notification enablement. |
| `isFirstRun` | Implemented as onboarding completion plus "show welcome on next launch". |
| `posLatitude` | Implemented for sunrise-based pause-until-morning. |
| `posLongitude` | Implemented for sunrise-based pause-until-morning. |
| `useMonochromeTrayIcon` | Explicit divergence: ShouldRest uses Mac-native menu-bar text/status styles instead of Stretchly icon variants. |
| `useMonochromeInvertedTrayIcon` | Explicit divergence: same as `useMonochromeTrayIcon`. |
| `silentNotifications` | Implemented across rest notifications, update notifications, and configured start/finish sounds. |
| `monitorDnd` | Implemented as Focus/DND monitoring, with Eye Gate not globally cancelled by default. |
| `miniBreakStartSound` | Implemented as Eye Gate start sound. |
| `longBreakStartSound` | Implemented as Body Break start sound. |
| `themeSource` | Implemented as system/light/dark appearance. |
| `endBreakShortcut` | Implemented as the active rest finish shortcut, defaulting to `CmdOrCtrl+X`, active only while compatible rest surfaces are active. |
| `breakWindowWidth` | Explicit divergence: enforced rests do not use partial percentage-sized windows. |
| `breakWindowHeight` | Explicit divergence: enforced rests do not use partial percentage-sized windows. |
| `checkNewVersion` | Implemented as launch and periodic update checks, plus manual check. |
| `breakIdeas` | Implemented as Body Break custom ideas with sanitized rich text and safe local images. |
| `microbreakIdeas` | Explicit divergence for Eye Gate; custom readable Eye Gate content is not supported. |
| `showBreaksAsRegularWindows` | Explicit divergence: enforced rests use native overlay windows, not regular focusable windows. |
| `appExclusions` | Implemented and strengthened with multiple rules plus per-rest-kind targeting. |
| `appExclusionsCheckInterval` | Explicit divergence: ShouldRest uses a fixed native context evaluation loop instead of exposing a tuning knob. |
| `pauseForSuspendOrLock` | Implemented for sleep/lock behavior. |
| `pauseBreaksToggleShortcut` | Implemented as pause/resume shortcut. |
| `pauseBreaksFor30MinutesShortcut` | Implemented. |
| `pauseBreaksFor1HourShortcut` | Implemented. |
| `pauseBreaksFor2HoursShortcut` | Implemented. |
| `pauseBreaksFor5HoursShortcut` | Implemented. |
| `pauseBreaksUntilMorningShortcut` | Implemented, sharing fixed-hour/sunrise pause-until-morning logic. |
| `screen` | Implemented for Body Break display targeting; Eye Gate forces all-display coverage. |
| `breakContentScreen` | Implemented for Body Break content display and secondary blanking. |
| `trayIconStyle` | Implemented as menu-bar default, time-to-break, and progress styles. |
| `currentTimeInBreaks` | Implemented for Body Break only; Eye Gate intentionally avoids screen-reading content. |
| `showTrayIcon` | Implemented as optional menu-bar item visibility. |
| `skipToNextScheduledBreakShortcut` | Implemented as "take next scheduled rest now". |
| `skipToNextMiniBreakShortcut` | Implemented as "take Eye Gate now"; ordinary Eye Gate skip remains unavailable. |
| `skipToNextLongBreakShortcut` | Implemented as "take Body Break now". |
| `resetBreaksShortcut` | Implemented, with strict active-rest bypass protection. |
| `showTrayMenuInStrictMode` | Explicit divergence: Eye Gate does not expose ordinary tray/menu actions while active. |
| `customPreferencesMessage` | Implemented as an admin preferences message. |
| `disableAppUpdateFeatures` | Implemented as an admin switch that hides update UI and suppresses update checks. |
| `hidePreferencesFileLocation` | Strengthened: admin path hiding removes settings, log, support, and Body Break image paths from debug and CLI path output. |
| `hideStrictModePreferences` | Implemented for strict/override-related preference rows. |
| `miniBreakManualFinish` | Implemented as optional completed Eye Gate manual-finish phase, without enabling early skip/postpone. |
| `longBreakManualFinish` | Implemented as Body Break manual-finish phase. |
| `breakHealthMode` | Implemented and visible in menu/debug surfaces. |
| `openAtLogin` | Implemented through macOS ServiceManagement when bundled. |
| `_migratedOpenAtLogin` | Not a product capability; Stretchly migration sentinel only. |

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
- Manual-finish support for Body Break and optional completed Eye Gate.
- Strict active rests prevent application termination and reset bypasses.

### Context

- Natural rest credit from idle time.
- Suspend/lock correction.
- Focus/DND awareness.
- App exclusions with pause and resume-only semantics, including active Body Break interruption for matching pause rules.
- Working-hours gating.

### Controls

- Menu bar status item.
- Pause for 30 minutes, 1 hour, 2 hours, 5 hours, until morning, or indefinitely.
- Global shortcuts.
- Stretchly default `CmdOrCtrl+X` active-rest finish shortcut semantics, registered only while a compatible rest is active.
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
- First-run onboarding plus an option to show the welcome window on the next launch.
- About/learn-more surface with app version, product positioning, and a debug-info path.
- Open at login.
- Update checks with disable switch.
- Debug info: settings path, logs path, support path, Body Break image paths, runtime state, timer state.
- Admin controls for update UI, strict preferences, settings/log/support/image paths, and custom preferences message.

## Current Implementation Checkpoint

Implemented now:

- Swift package and git repository.
- Core settings model matching the audited capability groups.
- Pure rest engine for schedule/evaluate/start/complete/postpone/skip/override/pause/resume/reset.
- Eye Gate default: opaque, screen-saver-level, all-displays, no ordinary skip/postpone.
- Body Break default: rich content allowed, bounded postpone, ordinary skip, manual finish flag.
- Natural rest credit.
- Focus/DND policy: Body Break defers by default; Eye Gate does not.
- App exclusions with per-kind targeting and pause/resume-only semantics, including Stretchly-style closure of an active Body Break when a matching pause exclusion appears. Eye Gate is not interrupted by app exclusions.
- JSON settings store.
- Built-in Eye Gate and Body Break idea library.
- Native menu bar app skeleton.
- Native AppKit overlay windows at `.screenSaver` level with all-spaces/full-screen auxiliary behavior.
- IOKit idle-time reader.
- NSWorkspace running-app matching for exclusions.
- UserNotifications-based pre-break notifications.
- Start/finish sound playback.
- Copyable debug snapshot from the menu and CLI/URL automation.
- Native preferences window for core cadence, enablement, Focus policy, and tray style.
- Expanded preferences for notification lead times, overlay colors, sounds, Body Break interval/postpone/skip policy, natural break settings, working hours, primary app exclusion, custom Body Break idea, shortcuts, update settings, and admin controls.
- CLI command surface for help, version, settings/log paths, pause/resume/reset, take-now, preferences, and debug requests; the settings-path command respects admin path hiding.
- Stretchly-compatible `toggle`, `mini`, and `long` command aliases, delayed take-now automation, and `body`/`long` one-shot Body Break title, text, wait, and noskip options.
- App-level CLI/URL parser tests for Stretchly-style durations, `mini`/`long` aliases, wait, noskip, pause URLs, and invalid URL rejection.
- Distributed notification bridge for CLI-to-running-app automation.
- CLI and URL automation requests now start ShouldRest and execute after launch when no existing app instance is running; with an existing instance they are forwarded to it.
- Local log file.
- Custom rich-text sanitizer for Body Break content.
- Settings-store round-trip coverage.
- Open-at-login setting and ServiceManagement integration when running as a bundled app.
- Sleep, wake, lock, and unlock correction hooks.
- Stretchly-compatible `pauseForSuspendOrLock` preference: enabled by default, with an opt-out path that preserves schedule state and lets natural rest credit absorb sleep/lock idle time.
- Debug panel with runtime state, timer state, settings/log/support paths, and Body Break image paths; admin path hiding removes all of those filesystem paths from copied/panel debug output and CLI path commands.
- Global shortcut registration for pause, pause durations, take-now, Body Break skip-to-next, and reset.
- Stretchly-style active rest finish shortcut: default `CmdOrCtrl+X`, registered only while a rest is active. For Body Break, after the required duration it finishes, during the postpone window it postpones, and otherwise it uses the Body Break skip policy. For Eye Gate, it can only finish an already-completed manual-finish phase and never acts as early skip/postpone.
- Stretchly-style strict break bypass guard: active Eye Gate and strict Body Break disable Quit/Reset menu items, cancel `applicationShouldTerminate`, and reject reset requests from shortcuts or automation, preserving the overlay instead of letting app termination or reset bypass the rest.
- URL-style automation parser plus Apple Event URL handler for bundled app registration.
- Body Break manual-finish phase that lowers overlay level after the required duration and waits for user completion.
- Optional Eye Gate manual-finish phase that waits after the required duration without allowing early skip/postpone; its overlay remains at native screen-saver level and can be completed from the menu or active finish shortcut.
- Configurable active working-hours windows, including overnight windows.
- Update feed checks with manual menu action, launch-time and 48-hour repeat checks, admin disable switch that hides normal update controls, automatic update notifications that open the release page when clicked, and explicit manual-check feedback even when automatic update notifications are disabled.
- SwiftPM localization resource bundle with English and Simplified Chinese strings for core menu, notification, status, debug, preferences, and overlay surfaces.
- Preference-level language selector for System language, English, and Simplified Chinese; unknown legacy locale identifiers fall back to System language instead of persisting an invalid override.
- Safe local image Body Break content path support and overlay renderer.
- Reproducible `.app` packaging script with `shouldrest://` URL-scheme Info.plist registration and localization resource bundling.
- Advanced app-exclusion JSON editor for multi-rule configurations, plus primary-rule form controls for common cases.
- Localized preference labels and CLI help in the SwiftPM resource bundle.
- First-run onboarding window that lets users accept the scientific defaults or open preferences, plus an Operations preference to show the welcome window on the next launch.
- Stretchly-style Welcome/About surface: first-run onboarding includes a learn-more action, and the menu exposes an About panel with version, product design notes, and a direct path into debug info.
- Restore Defaults asks for confirmation, then uses product defaults without reopening first-run onboarding, matching Stretchly's restore behavior.
- Packaged-app GUI smoke check using CoreGraphics window enumeration; verified `Welcome to ShouldRest` appears on-screen in `dist/ShouldRest.app`.
- Automated packaged-app GUI smoke script runs the app against a temporary support directory and verifies first-run onboarding through both window enumeration and smoke-run logs.
- Unified local release verification script covers Stretchly settings-key coverage, whitespace checks, tests, app metadata/resources, strict codesign, first-run GUI smoke, ad-hoc DMG creation, and DMG checksum verification.
- Floating/all-spaces presentation for onboarding, preferences, and debug utility windows.
- AppKit theme application for system/light/dark preferences, admin preferences message display, and optional current time during Body Break.
- Stretchly-compatible menu bar visibility preference: visible by default, hideable for CLI/URL-managed setups.
- Language override setting for bundled translations, while defaulting to the macOS system language. Current bundled translations are English and Simplified Chinese; additional languages are an expansion path, not a current claim.
- Packaged app build with default ad-hoc signing, optional Developer ID signing hook, optional hardened runtime hook, and strict `codesign` verification.
- Release packaging automation for Developer ID identity selection, hardened-runtime app signing, DMG creation, optional DMG signing, optional Apple notarization, and stapling validation.
- Continuous context-deferral state for Focus, working-hours, and app-exclusion gates: first deferral raises break-health danger, repeated ticks do not double-count, and the due rest starts immediately when context clears.
- Natural rest credit is bounded to one credited rest per idle episode, then resets only after user activity resumes, matching Stretchly's natural-break lifecycle while preserving ShouldRest's short Eye Gate credit.
- Stretchly-style display targeting for Body Break: all displays or a selected single display, primary/cursor/configured-display selection, separate content-display selection, optional secondary-display blanking, and backward-compatible settings decoding. Eye Gate still forces all-display coverage.
- Sanitized Body Break rich-text rendering with remote/inline HTML images stripped; images remain available through the explicit safe local-image channel.
- Preference surface for enabling/disabling built-in rest ideas while preserving custom Body Break ideas.
- Preference surface for editing multiple custom Body Break ideas through a sanitized advanced JSON array, matching Stretchly's settings-file idea customization while keeping Eye Gate content minimal.
- Advanced JSON preference editors validate non-empty input and stop saving on parse errors instead of silently falling back to simplified form fields; single-rule/single-idea configurations stay editable through the simplified form instead of being shadowed by auto-filled JSON.
- Separate preference controls for Eye Gate and Body Break start/finish sounds, with shared configurable sound volume.
- Stretchly-compatible built-in sound resources (`crystal-glass`, `wind-chime`, `tic-toc`, `reverie`, `silence`) with preference-level selectors, preview buttons, and third-party attribution notices bundled in app resources.
- Complete global-shortcut preference surface for pause toggle, pause durations, pause until morning, immediate rests, Body Break skip-to-next, active rest finish, and reset; pause-until-morning shortcut is registered at runtime.
- Stretchly-style skip-to-next-scheduled menu action and shortcut: it immediately starts whichever rest kind is currently scheduled next, while separate Eye Gate now and Body Break now actions remain available.
- Preferences, settings persistence, and engine entry points prevent configurations with both rest types disabled, matching Stretchly's schedule guard while closing file and automation bypasses.
- Configurable pause-until-morning hour, shared by menu/global-shortcut and CLI/URL automation; early-morning pauses now resume the same morning instead of always tomorrow.
- Stretchly-style sunrise pause-until-morning mode with configurable latitude/longitude, shared by menu/global-shortcut and CLI/URL automation, with fixed-hour fallback when sunrise cannot be calculated.
- Silent-notifications policy honors Stretchly semantics across pre-break/update notifications and configured rest start/finish sounds.
- Stretchly-style automatic resume notification is shown when a timed user pause or pause-until-morning expires; explicit manual resume paths stay quiet.
- Break-health danger is visible in the menu status surface, not only in debug output.
- Menu status uses localized rest-kind names and shows the Stretchly-style Body Break countdown in Eye Gate units when both rest kinds are enabled.
- Menu bar tooltip mirrors the Stretchly tray tooltip structure: product header plus dynamic status lines.
- Disabling break-health mode resets accumulated danger, matching Stretchly's runtime setting behavior.
- Eye Gate emergency override is frictional in core and app surfaces: minimum hold duration and required confirmation steps are enforced before the override is counted as a missed Eye Gate, with a configurable global shortcut for screen-covering situations.
- Admin strict-preference hiding now removes both the Body Break ordinary-skip control and the Eye Gate emergency-override shortcut row from Preferences while preserving their stored values.

Still to perform for public release:
- Run `scripts/release_app.sh` with real Developer ID and Apple notarization credentials, then repeat GUI smoke on a clean user account.
