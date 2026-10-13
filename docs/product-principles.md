# ShouldRest Product Principles

ShouldRest is a Mac-first rest system, not a generic timer. Its core job is to make biologically meaningful rest actually happen while preserving deliberate user control.

## First Principles

1. Eye rest is an execution problem, not an information problem.
2. Frequent short eye rests beat rare large rests for screen-driven eye strain.
3. A 20-second rest is too short for ordinary skip/postpone controls; those controls train muscle memory.
4. A transparent or partial overlay does not stop near-screen visual work.
5. Short eye rests and longer body rests need different governance.

## Break Classes

### Eye Gate

Eye Gate is the short, frequent, high-integrity rest.

- Default cadence: 20 minutes of active screen time, 20 seconds away from the screen.
- It must block all displays with an opaque overlay.
- It must not expose ordinary skip or postpone actions.
- It may expose an emergency override only through deliberate friction.
- It should avoid rich text, images, or instructions that become new visual work.

### Body Break

Body Break is the longer, lower-frequency, negotiable rest.

- It may include stretches, breathing, movement prompts, or custom messages.
- It may support postpone, manual finish, and richer content.
- It may be softened during meetings or presentation contexts.
- It should remain harder to dismiss than a notification.

## Rest Timing

- Rest debt follows screen exposure, not wall-clock time. Input, video playback, and calls count as exposure; idle time stays provisional until the user returns (exposure) or the away threshold passes (rest).
- A verified screen-off period (sleep, lock, display sleep) counts as rest once it lasts as long as the rest itself.
- A due rest starts at the first natural pause in input, or slightly early during a clear pause, and never later than its deadline.
- Rests due within a few minutes of each other share one interruption.
- Body Breaks wait for calls, for at most one more Body Break interval; Eye Gates do not.

## Capability Rule

Except for explicit design divergences, ShouldRest should implement or exceed Stretchly's user-facing capabilities. When a Stretchly capability conflicts with Eye Gate integrity, ShouldRest keeps the capability for Body Break or replaces it with a stronger deliberate-control variant.

