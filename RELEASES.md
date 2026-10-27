# Releases

WidgetSimple ships to the **App Store** via StoreKit and uses public API only.
`Scripts/audit-appstore.sh` checks every `APPSTORE=1` build in the `Build` and
`TestFlight` workflows.

| | Value |
|---|---|
| Private API | none |
| Name under the icon | `WidgetSimple` (visible, Guideline 2.3.8) |
| Label under each widget | U+2800 (invisible, `WIDGET_SCREEN_NAME`) |
| Payment | StoreKit 2 auto-renewable subscription |
| Widget background | The matched wallpaper piece, or a photo; without either, the system background. A stored `glass` value from builds 35–37 decodes as Clear. |

## TestFlight unlock (never in the App Store build)

The subscription cannot be bought before App Review approves it, which would leave
testers stuck on the paywall. The `TestFlight` workflow therefore has a
`paywall_unlock` input (on by default) that compiles the app with `TESTFLIGHT`:

- a visible **Unlock without purchase** button on the paywall, and
- **Re-lock (test the paywall)** in Settings so the locked state can be checked again.

With `paywall_unlock` off, `TESTFLIGHT` is not defined and the App Store binary contains
no unlock code at all — it is compiled out, not hidden.
**Turn the input off for the build submitted to App Review**; the workflow's build
summary says which kind of build was uploaded.

## CI

`Build` compiles the app and widget unsigned. `TestFlight` archives, signs and uploads.
Both need GitHub-hosted minutes: on a private repo the runs fail before starting with
"recent account payments have failed or your spending limit needs to be increased" —
either raise the limit or flip the repo public for the run.
