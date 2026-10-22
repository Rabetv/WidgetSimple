# WidgetSimple

A text-only app launcher for the iPhone Home Screen. Design a medium (or large) widget whose apps are just words in the font, size and color you choose. Tap a word, the app opens. No icons, no label under the widget, and a built-in workaround that makes the iOS 26/27 glass widget border disappear.

## Features

- **Text launcher widget** (Medium and Large). Grid/list or flowing-text layouts, 1–6 columns, alignment, spacing and margins.
- **Full typography control**: SF Pro / Rounded / New York / Mono, 40 font families built into iOS, or import your own `.ttf`/`.otf` (works in the widget too). Size, weight, italic, underline, color + opacity, letter spacing, case, shadow. Per-item overrides.
- **Opens any app**: built-in catalog of ~100 apps (installed ones are detected), custom URL schemes, websites/universal links, and *any* installed app through a Shortcut with the “Open App” action.
- **Glass-border workaround**: the widget background becomes a pixel-exact crop of your wallpaper. The app finds the widget's exact position by turning it magenta and analysing one screenshot.
- **No name under the widget**: the Home Screen name is an invisible character (configurable).
- Several layouts → several widgets (choose per widget via *Edit Widget*).

## Build & run

Requirements: Xcode 26 or newer (Xcode 27 recommended for iOS 27), an Apple Developer account, an iPhone on iOS 18+.

1. Open `Config/Base.xcconfig` and set:
   - `DEVELOPMENT_TEAM` = your Team ID (developer.apple.com › Account › Membership), or leave empty and pick the team in Xcode.
   - `BUNDLE_ID_PREFIX` if `com.rabetv` isn't yours.
2. Open `WidgetSimple.xcodeproj`.
3. For **both** targets (WidgetSimple and WidgetSimpleWidgetExtension) open *Signing & Capabilities*, tick *Automatically manage signing*, choose your team. The App Group `group.<prefix>.widgetsimple` comes from the entitlements file and is registered automatically.
4. Select your iPhone and press Run.

The GitHub Action in `.github/workflows/build.yml` compiles the project (unsigned) on every push.

## How the glass-border workaround works

Since iOS 26, iOS draws a thin Liquid Glass outline around every widget and no API turns it off. WidgetSimple makes the widget's background an exact copy of the wallpaper behind it, so the outline sits on identical pixels:

1. Home Screen style **Default** (not Clear/Tinted), wallpaper **Blur off**, **Reduce Motion on**.
2. Screenshot an empty Home Screen page (wallpaper only).
3. Tap *Turn my widget magenta*, screenshot the Home Screen, pick it in the app. The widget's exact frame is detected automatically (and refined with the size the widget reports about itself).
4. *Create background*. Done. Optional second wallpaper screenshot for Dark Mode.

## How taps open other apps

| Launch method | Websites / universal links | App URL schemes |
|---|---|---|
| Automatic (default) | Direct from the widget (`OpenURLIntent`) | Via WidgetSimple: forwards instantly on a black screen |
| Always direct (experimental) | Direct | Direct, if the iOS version allows it |
| Always via WidgetSimple | Via app | Via app |

Apple documents widget taps as opening the widget's own app. Forwarding from there works for every app; the direct path is offered as an option because newer iOS versions handle more cases.

## No name under the widget

The label under a Home Screen widget is the app's Home Screen name (`CFBundleDisplayName`). `HOME_SCREEN_NAME` in `Config/Base.xcconfig` is set to U+2800 (invisible). If App Review rejects the app under Guideline 2.3.8, set it to `WidgetSimple` and use *Edit › Customize › large icons* on the iPhone, which hides all labels.

## Project layout

```
Config/Base.xcconfig        team, bundle ids, app group, home screen name
Shared/                     compiled into app + widget (models, storage, renderer, intents)
WidgetSimple/               the app (editor, wallpaper matching, guides)
WidgetSimpleWidget/         the widget extension
```
