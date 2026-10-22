# WidgetSimple

A text-only app launcher for the iPhone Home Screen. Design a medium (or large) widget whose apps are just words in the font, size and color you choose, floating on your wallpaper with no widget background. Tap a word, the app opens. No icons, no label under the widget.

## Features

- **Text launcher widget** (Medium and Large). Grid/list or flowing-text layouts, 1–6 columns, alignment, spacing and margins.
- **Fully transparent widgets** (iOS 26+): no background at all, the wallpaper shows straight through. Nothing to line up, works with any wallpaper and with motion effects on.
- **Your colors in every Home Screen style**: in Clear/Tinted style iOS turns widget text white; WidgetSimple draws the words as full-color images there so fonts and colors stay.
- **Full typography control**: SF Pro / Rounded / New York / Mono, 40 font families built into iOS, or import your own `.ttf`/`.otf` (works in the widget too). Size, weight, italic, underline, color + opacity, letter spacing, case, shadow. Per-item overrides.
- **Pick from your apps**: a checklist of ~100 well-known apps; the ones on your iPhone are detected and listed first, tick the ones the widget shows. Custom URL schemes and websites/universal links for anything else. No Shortcuts needed.
- **No glass edge**: *Hide the glass edge* saves a flat wallpaper and fills the widget with exactly that color, so the iOS 26+ glass outline has nothing to show. Optional edge correction draws a soft band under the outline to cancel what's left.
- **No name under the widget**: the Home Screen name is an invisible character (configurable).
- Several layouts → several widgets (choose per widget via *Edit Widget*).
- Fallback backgrounds: solid color, or an exact wallpaper copy (found automatically via a magenta calibration screenshot).

## Build without a Mac (GitHub → TestFlight)

The **TestFlight** workflow (`.github/workflows/testflight.yml`) archives, signs and uploads the app on a GitHub-hosted Mac.

1. Register the App IDs `com.rabetv.widgetsimple` and `com.rabetv.widgetsimple.widget` with the App Group `group.com.rabetv.widgetsimple` (developer.apple.com › Identifiers).
2. Create the app record in App Store Connect with bundle ID `com.rabetv.widgetsimple`.
3. App Store Connect › Users and Access › Integrations › App Store Connect API: create a key with the **Admin** role.
4. Repository secrets (Settings › Secrets and variables › Actions): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (whole .p8 file), and `GH_SECRETS_TOKEN` (fine-grained token with *Secrets: Read and write* on this repo).
5. Actions › TestFlight › Run workflow. The first run creates an Apple Distribution certificate via the API and stores it as `SIGNING_P12_BASE64` / `SIGNING_P12_PASSWORD`; later runs reuse it. Provisioning profiles are recreated on every run (`ci/asc_signing.py`).
6. Install from the TestFlight app on your iPhone.

## Build with a Mac

Xcode 26 or newer. `Config/Base.xcconfig` holds the team (`DEVELOPMENT_TEAM`), bundle prefix and Home Screen name. Open `WidgetSimple.xcodeproj`, enable automatic signing for both targets, run. The **Build** workflow compiles every push unsigned.

## Transparent widgets and the glass edge

Since iOS 26 a widget may have no background, so the wallpaper shows through. WidgetSimple layouts default to that (`containerBackground` = clear). iOS still draws its own thin glass edge on top of every widget, outside the widget's control, so the widget can't paint over it.

The edge only shows the wallpaper behind it (refracted and highlighted). **Layout › Background › Hide the glass edge** removes what it has to show: it saves a flat wallpaper (white, gray, black or any color) to Photos, fills the widget with exactly that color, lists the iPhone settings that matter (Home Screen style *Default*, matching Light/Dark appearance, Reduce Motion, Reduce Transparency / Increase Contrast) and can copy the exact on-screen color from a Home Screen screenshot. If a faint line is left, *Edge correction* draws a soft darker or lighter band just inside the edge, tuned by eye on the device.

| Home Screen style | Result |
|---|---|
| Default (Light/Dark/Auto) | See-through, your exact fonts and colors |
| Clear | Most see-through, very light clear glass; colors kept via full-color label images |
| Tinted | Works, but iOS tints around the words |

If a device ever shows a solid box, switch that layout's background to *Wallpaper copy*: take a wallpaper screenshot and a screenshot with the widget turned magenta, and the app crops an exact copy. For that fallback turn off *Perspective Zoom* (Edit Wallpaper › ⋯); Reduce Motion is not needed.

## Which apps are detected

iOS has no public API that lists installed apps. WidgetSimple checks its catalog with `canOpenURL`, which only works for schemes in `LSApplicationQueriesSchemes`: at most 50, and only the first 25 for apps built with the iOS 27 SDK. The list in `WidgetSimple/Info.plist` is ordered by popularity; entry 26 is WidgetSimple's own scheme, which tells the app at runtime whether iOS checks 25 or 50. Apps that can't be checked are listed under *More apps*.

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
