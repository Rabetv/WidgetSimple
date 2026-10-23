# WidgetSimple

Your apps as plain words on the iPhone Home Screen — in widgets that are **fully
transparent**: no glass, no rounded rim, no wallpaper screenshots. Tap a word and the
app opens.

## What it does

- **One widget, up to 12 apps.** Hold it › *Edit Widget* and pick apps; each one shows
  as a word in the font you chose. A tap opens that app directly
  (`RunSystemShortcutIntent`, iOS 27).
- **Truly transparent.** The widget has no background of its own, so the wallpaper runs
  edge to edge behind the words — on any wallpaper, any position, and with Focus modes.
  No setup: no screenshot of an empty Home Screen, no per-slot slices.
- **Style it in the app.** Font (system, rounded, serif, mono, 40 built-in families,
  your own `.ttf`/`.otf`), size slider, alignment, letter case, white/black/any colour,
  soft shadow, line spacing.
- **Placement.** *Stacked* keeps the clock above the words; *Free* gives the clock and
  the words their own 9-point anchor plus X/Y nudges, so any spot is reachable — even
  overlapping.
- **Clock.** Off, time, time + date, or date, in the same font; 12/24 h follows the
  iPhone setting.

## How the transparency works

Since iOS 26 every widget is drawn inside a system-owned container: a rounded rectangle
with a Liquid Glass coating and a rim. Nothing the app draws can cover that rim, because
the host composites it after the extension's snapshot. A container background of
`Color.clear` gets replaced by the system's glass, and
`.containerBackgroundRemovable(false)` keeps the container but paints it black.

The container is described by the **widget descriptor** the extension returns to Chrono
over XPC, so that descriptor is the only host-facing data an extension controls.
`WidgetDescriptorHook.mm` swizzles
`-[_TtCC9WidgetKit24WidgetExtensionXPCServer14ExportedObject getAllCurrentDescriptorsWithCompletion:]`,
rewrites the returned `CHSMutableWidgetDescriptor`s with
`setBackgroundRemovable:`, `setTransparent:` and `setPreferredBackgroundStyle:`, and hands
the rebuilt result back.

The Swift result type has no Objective-C accessor and its stored properties have no type
encoding, so the descriptors are reached by encoding the result, decoding it into a plain
Objective-C shim, mutating the descriptors there and letting `DescriptorFetchResult`
rebuild itself from the archive. Every stage is guarded and logged to the App Group
(`WidgetSimple/hook.log`); on any failure the original object is passed through, so the
widget can only ever behave as it did before.

**This is private API.** It is not App Store material (guideline 2.5.1) and Apple can
rename any of these symbols in any release. The standalone write-up, including the
approaches that do not work, is at
[Rabetv/ios-transparent-widget](https://github.com/Rabetv/ios-transparent-widget).

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
(`CFBundleDisplayName`). `HOME_SCREEN_NAME` in `Config/Base.xcconfig` is U+2800
(invisible). If App Review rejects the app under Guideline 2.3.8, set it to
`WidgetSimple`; large icons hide all labels anyway.

## Project layout

```
Config/Base.xcconfig        team, bundle ids, app group, home screen name
Shared/                     app + widget: look model, fonts, storage, the widget face
WidgetSimple/               the app (one screen: preview, apps, clock, style)
WidgetSimpleWidget/         the widget + the descriptor hook that makes it transparent
AppStore/listing.md         the copy for the App Store listing
```
