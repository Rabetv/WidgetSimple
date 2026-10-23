# One build, one target

WidgetSimple ships to the **App Store** only. There is no second flavour any more: every
build contains the descriptor hook and the invisible Home Screen name, and sells through
StoreKit.

| | Value |
|---|---|
| Private API | **yes** — `WidgetSimpleWidget/WidgetDescriptorHook.mm` |
| Name under the icon | U+2800 (invisible) |
| Payment | StoreKit 2 auto-renewable subscription |
| Widget background | container removed by the hook; matched wallpaper is the fallback if the hook does nothing |

## The risk, written down

App Review can reject this build under **guideline 2.5.1** (private API). The binary
contains the private selectors in plain text — `setTransparent:`,
`setBackgroundRemovable:`, `setPreferredBackgroundStyle:`,
`getAllCurrentDescriptorsWithCompletion:` — and `Scripts/audit-appstore.sh` prints them on
every run. Nothing here is obfuscated.

If a rejection arrives: resubmit a build with the hook removed (matched wallpaper only),
or ship that variant from the start. Concealing the calls is not an option — it converts a
rejection into an account-level problem.

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
