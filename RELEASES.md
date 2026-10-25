# One build, one target

WidgetSimple ships to the **App Store** only. There is no second flavour any more: every
build contains the descriptor hook and the invisible Home Screen name, and sells through
StoreKit.

| | Value |
|---|---|
| Private API | **yes** — `WidgetSimpleWidget/WidgetDescriptorHook.mm` |
| Name under the icon | U+2800 (invisible) |
| Payment | StoreKit 2 auto-renewable subscription |
| Widget background | Clear (default) or a photo. The hook removes the container unconditionally; matched wallpaper remains the fallback if the hook does nothing. |

## Why the hook is unconditional

Build 35 gated the hook on a `clear.on` flag the app wrote at launch. That cannot work:
chronod fetches an extension's descriptors once per extension install and then caches
them, and a timeline reload does not fetch them again. The first fetch happens at install
time, before the new app has ever run, so the flag is always missing when it matters.
Builds 38+ therefore rewrite every descriptor, exactly as builds up to 34 did.

The consequence: a system-glass option cannot exist in the same build. The descriptor
that carries the container is the one the hook replaces, and it cannot be fetched again
per widget. The background picker is **Clear** and **Photo**; a stored `glass` value from
builds 35–37 decodes as Clear.



## TestFlight unlock (never in the App Store build)

The subscription cannot be bought before App Review approves it, which would leave
testers stuck on the paywall. The `TestFlight` workflow therefore has a
`paywall_unlock` input (on by default) that compiles the app with `TESTFLIGHT`:

- a visible **Unlock without purchase** button on the paywall, and
- **Re-lock (test the paywall)** in Settings so the locked state can be checked again.

With `paywall_unlock` off, `TESTFLIGHT` is not defined and the App Store binary contains
no unlock code at all — it is compiled out, not hidden. **Turn the input off for the
build submitted to App Review**; the workflow's build summary says which kind of build
was uploaded.

## CI

`Build` compiles the app and widget unsigned. `TestFlight` archives, signs and uploads.
Both need GitHub-hosted minutes: on a private repo the runs fail before starting with
"recent account payments have failed or your spending limit needs to be increased" —
either raise the limit or flip the repo public for the run.
