# Stretchly Capability Contract

This document is the implementation contract for being a Stretchly capability superset while preserving ShouldRest's design divergences.

Reference baseline: `hovancik/stretchly` trunk at commit `f14012cc51e7944f4a6c93a75147f994e08b1f6e`, version `1.21.0`.

## Explicit Divergences

These Stretchly-compatible behaviors are intentionally not copied as-is.

- No ordinary skip for Eye Gate.
- No ordinary postpone for Eye Gate.
- No transparent or partial Eye Gate overlay.
- No rich Eye Gate content that asks the user to read the screen.
- No CLI/API injection of rich Eye Gate title/body content.
- No regular/focusable break window mode for enforced breaks.
- No percentage-sized partial active break windows for enforced rests; Body Break uses display targeting and optional secondary blanking instead.
- No ordinary tray/menu actions during Eye Gate beyond the frictional emergency override.
- No Stretchly icon-color variants as a core setting; the Mac app uses brand/status text styles instead.
- No user-tunable app-exclusion polling interval; the native app uses a fixed low-latency context evaluation loop.
- Do Not Disturb does not globally cancel Eye Gate.
- No contributor-gated preferences.
- No third-party account-based sync in the core product.
- No Electron-first implementation for the Mac app.

## Required Superset Capabilities

### Scheduling

- Enable or disable Eye Gate and Body Break independently.
- Configure intervals and durations.
- Support a Body Break after a configurable number of Eye Gates.
- Support pre-break notifications.
- Support manual "take break now" actions.
- Support reset, pause, resume, and skip-to-next commands for non-Eye-Gate flows.

### Enforcement

- Full-screen multi-display overlays.
- Strong Mac overlay level for enforced breaks.
- Display topology reconciliation for added, removed, moved, or reordered screens.
- Main-display content with secondary-display blanking.
- Strict behavior for Eye Gate by default.
- Body Break postpone and skip policies with limits.
- Manual-finish mode for Body Break and optional completed Eye Gate.
- Application termination and reset bypasses are blocked during strict active rests.

### Context Awareness

- Natural break detection using idle time.
- Suspend, lock, resume, and unlock correction.
- Configurable pause-on-suspend-or-lock behavior.
- Do Not Disturb / Focus awareness.
- App exclusion rules with pause and resume semantics, including closing an active Body Break when a matching pause exclusion appears.
- Configurable active working hours.

### Controls

- Menu bar status item.
- Optional hidden menu bar item for CLI/URL-managed setups.
- Open at login.
- Pause durations: 30 minutes, 1 hour, 2 hours, 5 hours, until morning, indefinitely.
- Pause-until-morning supports both a fixed hour and sunrise from configured coordinates.
- Global shortcuts for pause/resume, immediate break, next scheduled rest, active rest finish, and reset; the default active finish shortcut matches Stretchly's `CmdOrCtrl+X`, is registered only while a compatible rest is active, and never ends Eye Gate early.
- CLI or URL-style automation surface, including Stretchly-style `mini`/`long` aliases, pause toggle, delayed take-now, and one-shot Body Break title/body/wait/noskip customization.

### Presentation

- Light, dark, and system appearance.
- System language with optional in-app language override for bundled translations.
- Configurable colors for rest surfaces.
- Optional sounds at start and finish.
- Configurable sound volume.
- Tray/menu-bar status styles: default, time-to-break, and progress.
- Optional current time during Body Break.
- Break health / danger indicator that escalates after deferrals and relaxes after completed rests.

### Content

- Built-in rest ideas.
- Custom Body Break ideas.
- Safe local images for Body Break content.
- Sanitized rich text for Body Break content.
- Localization-ready strings.

### Operations

- Local JSON settings.
- Restore defaults.
- First-run onboarding plus an option to show the welcome window on the next launch.
- Version/update checks with disable switch.
- Debug panel or command with settings path, log path, support path, Body Break image paths, runtime state, and timer state.
- Corporate/admin controls: hide update UI, hide strict preferences, hide settings/log/support/image paths, custom preferences message.
