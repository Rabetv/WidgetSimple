# WidgetSimple

Your apps as plain words on the iPhone Home Screen, over the wallpaper behind each
widget. Tap a word and the app opens.

## What it does

- **One widget, up to 12 apps.** Hold it › *Edit Widget* and pick apps; each one shows
  as a word in the font you chose. A tap opens that app directly
  (`RunSystemShortcutIntent`, iOS 27).
- **Matched wallpaper.** Each widget draws the piece of wallpaper that sits behind it,
  cut from two screenshots of an empty Home Screen page (Light and Dark Mode). The app
  cuts a piece for every slot of the iPhone's widget grid; each widget picks its slot in
  Edit Widget (Position, Side). Public API only.
- **Style it in the app.** Font (system, rounded, serif, mono, 40 built-in families,
  your own `.ttf`/`.otf`), size slider, alignment, letter case, white/black/any colour,
  soft shadow, line spacing.
- **Placement.** *Stacked* keeps the clock above the words; *Free* gives the clock and
  the words their own 9-point anchor plus X/Y nudges, so any spot is reachable — even
  overlapping.
- **Clock.** Off, time, time + date, or date, in the same font; 12/24 h follows the
  iPhone setting.

## How the background works

Since iOS 26 every widget is drawn inside a system-owned container with a Liquid Glass
coating and a rim, and an app cannot remove it. WidgetSimple draws the matching piece of
wallpaper as the container background instead (`Shared/SeeThrough.swift`,
`WidgetSimple/WallpaperSetupView.swift`), so the widget blends into the Home Screen. A
widget without a matched piece keeps the system background. The app only uses public
API; `Scripts/audit-appstore.sh` checks App Store builds for that.

## Why the apps are picked in Edit Widget

iOS resolves app choices through `SystemShortcut`, which has no public initializer, no
KVC, and no enumeration:

> `SystemShortcut` … exposes no public initializer and no public static factory in the
> SDK, so app code cannot construct or enumerate `SystemShortcut` values directly … do
> not store your own or model it as a custom property on a widget timeline entry.
> — [App Intents: Running System Shortcuts](https://developer.apple.com/documentation/appintents/runsystemshortcutintent)

So the app list lives in the system's own picker in *Edit Widget*; everything else
(style, clock, placement) is set in the app and shared through the App Group, which
means it applies to every widget instantly.

## Build

Xcode 27 or newer (iOS 27 SDK; the app needs iOS 27). `Config/Base.xcconfig` holds the
team (`DEVELOPMENT_TEAM`), bundle prefix and Home Screen name. Open
`WidgetSimple.xcodeproj`, enable automatic signing for both targets, run.

### Without a Mac (GitHub → TestFlight)

The **TestFlight** workflow (`.github/workflows/testflight.yml`) archives, signs and
uploads on a GitHub-hosted Mac, using the same setup as JAAPP:
[codemagic-cli-tools](https://github.com/codemagic-ci-cd/cli-tools) creates or reuses the
distribution certificate and profiles through the App Store Connect API.

1. developer.apple.com › Identifiers: register the App IDs `com.rabetv.widgetsimple` and
   `com.rabetv.widgetsimple.widget`, create the App Group `group.com.rabetv.widgetsimple`
   and tick it under *App Groups* for both App IDs. (Apple's API can't assign App Groups,
   so this step is manual.)
2. Create the app record in App Store Connect with bundle ID `com.rabetv.widgetsimple`.
3. Repository secrets (Settings › Secrets and variables › Actions):
   `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_IDENTIFIER`,
   `APP_STORE_CONNECT_PRIVATE_KEY`, `CERTIFICATE_PRIVATE_KEY`.
4. Actions › TestFlight › Run workflow.

> GitHub-hosted minutes must be available. On a private repository the run fails before
> starting with *"recent account payments have failed or your spending limit needs to be
> increased"*; a temporary public fork of the repo builds and uploads for free.

## Name under the widget

The label under a Home Screen widget is the widget extension's `CFBundleDisplayName`.
`HOME_SCREEN_NAME` (the app) is `WidgetSimple`, matching the App Store name as
Guideline 2.3.8 requires. `WIDGET_SCREEN_NAME` (the widget) is U+2800, so the widget
label stays invisible.

## Project layout

```
Config/Base.xcconfig        team, bundle ids, app group, home screen name
Shared/                     app + widget: look model, fonts, storage, the widget face
WidgetSimple/               the app (one screen: preview, apps, clock, style)
WidgetSimpleWidget/         the widget
AppStore/listing.md         the copy for the App Store listing
```
