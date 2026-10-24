# WidgetSimple

Your apps as plain words on the iPhone Home Screen, over your own wallpaper — each
widget draws the exact piece of wallpaper behind it, so it looks see-through. Tap a word
and the app opens. Public API only.

## What it does

- **One widget, up to 12 apps.** Hold it › *Edit Widget* and pick apps; each one shows
  as a word in the font you chose. A tap opens that app directly
  (`RunSystemShortcutIntent`, iOS 27).
- **See-through by matching.** Two kinds of screenshot, once: an empty Home Screen page
  (the wallpaper) and the Home Screen while every widget shows a pink code. The app
  finds each widget, cuts its piece of the wallpaper and the widget draws it.
- **Style it in the app.** Font (system, rounded, serif, mono, 40 built-in families,
  your own `.ttf`/`.otf`), weight, size, letter spacing, case, alignment,
  white/black/any colour or a tint matched to the wallpaper, shadow, spacing.
- **Layouts.** Automatic balanced columns, or drag every word anywhere in the layout
  editor and pick that layout per widget in Edit Widget.
- **More widgets.** Text, Date & Time, Countdown, World Clock, Greeting, Photo (14 CC0
  stock photos or your own), Dashboard (clock, battery, storage), Zen, Spacer — all
  see-through.

## How the see-through works

Since iOS 26 every widget is drawn inside a system-owned container: a rounded rectangle
with a light glass veil and a specular rim. The host composites it after the extension's
snapshot, and no public API removes it, so WidgetSimple doesn't try. Instead each widget
fills its container with the matching piece of the wallpaper (`Shared/SeeThrough.swift`):

1. Every widget has its own identity (`WidgetIdentity`, a UUID stored in its Edit Widget
   configuration), so two identical widgets still get different pieces.
2. While matching, each widget draws its 32-bit key plus a CRC as 6 × 6 squares on pink.
   `SeeThroughMaker` finds the pink rectangles, reads the codes, and takes each widget's
   size from what the widget itself reported (the pink only gives the centre).
3. The pieces are cut into a new folder and switched in with one atomic write; a widget
   with no piece of its own draws the system background, never someone else's piece.

On a black wallpaper the container is invisible; on a bright one its thin rim stays.
That is the ceiling for an App Store app.

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

## No name under the widget

The label under a Home Screen widget is the app's Home Screen name
(`CFBundleDisplayName`). `HOME_SCREEN_NAME` in `Config/Base.xcconfig` is a single
U+0020 space, the value MD Blank ships. If App Review rejects the app under Guideline
2.3.8, set it to `WidgetSimple`; large icons hide all labels anyway.

## Project layout

```
Config/Base.xcconfig        team, bundle ids, app group, home screen name
Shared/                     app + widget: look, layout planner, design system, storage, face
WidgetSimple/               the app (one screen: preview, apps, clock, style)
WidgetSimpleWidget/         every widget kind, the see-through resolver, Edit Widget entities
WidgetSimple/Stock/         CC0 stock photos for the Photo widget, manifest, CREDITS.md
AppStore/listing.md         the copy for the App Store listing
```
