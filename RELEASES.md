# One build, one target

WidgetSimple ships to the **App Store** only. There is one build: public API only, the
blank Home Screen name, and StoreKit for the subscription.

| | Value |
|---|---|
| Private API | **none.** The descriptor hook was removed (see CHANGES.md); CI fails if a private symbol appears in the sources or the binaries. |
| Name under the icon | one U+0020 space (`HOME_SCREEN_NAME`), as MD Blank ships; fallback `WidgetSimple` |
| Payment | StoreKit 2 auto-renewable subscription |
| Widget background | Clear (default: the widget's matched piece of the wallpaper) or a photo. iOS always draws its container and rim; nothing public removes them. |

## Why there is no hook any more

The earlier builds swizzled a private WidgetKit method to rewrite the widget descriptor
and remove the system container. That is a guideline 2.5.1 rejection waiting to happen
and it was never needed for the product: on a blue or purple wallpaper the container
edge measures +71 to +85 luminance against the bare wallpaper with *or* without any
trick an app may legally use, and on pure black it measures 0. The transparency comes
from drawing the right wallpaper pixels inside the container (`Shared/SeeThrough.swift`).

Do not bring it back, on any branch. `Scripts/audit-appstore.sh` and the **Build**
workflow check for it.

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

`Build` compiles the app and widget unsigned with warnings as errors, greps the sources
for private symbols, and audits the built binaries. `TestFlight` archives, signs, audits
and uploads; a failed audit stops the upload. Both need GitHub-hosted minutes: on a
private repo the runs fail before starting with "recent account payments have failed or
your spending limit needs to be increased" — either raise the limit or flip the repo
public for the run.
