# WidgetSimple

A text-only app launcher for the iPhone Home Screen. Your apps are just words in the font, size and color you choose. Tap a word, the app opens. Plus a clock widget. No icons, no label under the widget.

## Features

- **Text launcher widget** (Small, Medium, Large). Grid/list or flowing text, 1–6 columns, alignment, spacing.
- **Clock widget** (Small, Medium, Large): day, time, date and the current week (month on Large), in your font and colors. Tap opens Calendar.
- **Pick from your apps**: a checklist of ~100 apps; the ones detected on your iPhone come first. Websites and URL schemes for anything else.
- **Hide the edges**: a flat wallpaper, the same color on every widget and four iPhone settings (below).
- **Typography**: system fonts, 40 font families built into iOS, or your own `.ttf`/`.otf`.
- **No name under the widget**: the Home Screen name is an invisible character.
- Backgrounds: a color, or an exact copy of the wallpaper behind the widget (magenta calibration screenshot).
- A 4-page tutorial on first launch (**?** brings it back).

## Build without a Mac (GitHub → TestFlight)

The **TestFlight** workflow (`.github/workflows/testflight.yml`) archives, signs and uploads the app on a GitHub-hosted Mac. It uses the same setup as JAAPP: [codemagic-cli-tools](https://github.com/codemagic-ci-cd/cli-tools) creates or reuses the distribution certificate and the provisioning profiles through the App Store Connect API.

1. developer.apple.com › Identifiers: register the App IDs `com.rabetv.widgetsimple` and `com.rabetv.widgetsimple.widget`, create the App Group `group.com.rabetv.widgetsimple` and tick it under *App Groups* for both App IDs. (Apple's API can't assign App Groups, so this one step is manual.)
2. Create the app record in App Store Connect with bundle ID `com.rabetv.widgetsimple`.
3. Repository secrets (Settings › Secrets and variables › Actions), the same values JAAPP uses:
   - `APP_STORE_CONNECT_ISSUER_ID`: Issuer ID (App Store Connect › Users and Access › Integrations › App Store Connect API)
   - `APP_STORE_CONNECT_KEY_IDENTIFIER`: Key ID of an API key with the **Admin** role
   - `APP_STORE_CONNECT_PRIVATE_KEY`: whole contents of that key's `AuthKey_XXXX.p8` file
   - `CERTIFICATE_PRIVATE_KEY`: RSA private key (PEM) of the distribution certificate. Reusing JAAPP's key reuses its certificate; a new key (`ssh-keygen -t rsa -b 2048 -m PEM -f cert_key -q -N ""`) makes the workflow create a new certificate.
4. Actions › TestFlight › Run workflow.
5. Install from the TestFlight app on your iPhone.

## Build with a Mac

Xcode 26 or newer. `Config/Base.xcconfig` holds the team (`DEVELOPMENT_TEAM`), bundle prefix and Home Screen name. Open `WidgetSimple.xcodeproj`, enable automatic signing for both targets, run. The **Build** workflow compiles every push unsigned.

## Hiding the widget edges

iOS can't show a widget without a background: a clear background becomes a gray box. iOS also draws a glass edge on top of every widget, which no widget can paint over. The edge only shows what is behind it, so on iOS 27 it disappears when:

| | Black | Gray | White |
|---|---|---|---|
| Wallpaper (Blur off) and widget color | same flat black | same flat gray | same flat white |
| Display & Brightness | Dark | Dark | Light |
| Increase Contrast | **On** | Off | Off |
| Show Borders | Off | Off | **On** |
| Reduce Transparency | Off | Off | Off |

Plus Home Screen › Customize › Default with large icons. Accessibility settings are under Settings › Accessibility › Display & Text Size. This follows what [Blank Spaces](https://help.blankspaces.app/en/articles/5884313-how-to-set-up-the-dark-theme-ios-27) documents for iOS 27. On iOS 26 a faint outline always stays, and photo wallpapers always keep a faint edge. *Hide the edges* in the app saves the wallpaper, applies the color to every widget and can copy the exact on-screen color from a screenshot.

## Which apps are detected

iOS has no public API that lists installed apps. WidgetSimple checks its catalog with `canOpenURL`, which only works for schemes in `LSApplicationQueriesSchemes`: at most 50, and only the first 25 for apps built with the iOS 27 SDK. The list in `WidgetSimple/Info.plist` is ordered by popularity; entry 26 is WidgetSimple's own scheme, which tells the app at runtime whether iOS checks 25 or 50. Apps that can't be checked are listed under *More apps*.

## How taps open other apps

iOS sends every widget tap to the widget's own app; a widget can't open another app by itself (`OpenURLIntent` only opens the widget app's own links). So each word links to `widgetsimple://open?u=…`, and WidgetSimple forwards it at once on a black screen. Catalog items always use the catalog's current link, so a fixed link (e.g. Messages → `ichat://`, which opens the app instead of a new message; Wolt → `https://wolt.com/discovery`) reaches existing widgets too.

## No name under the widget

The label under a Home Screen widget is the app's Home Screen name (`CFBundleDisplayName`). `HOME_SCREEN_NAME` in `Config/Base.xcconfig` is set to U+2800 (invisible). If App Review rejects the app under Guideline 2.3.8, set it to `WidgetSimple` and use *Edit › Customize › large icons* on the iPhone, which hides all labels.

## Project layout

```
Config/Base.xcconfig        team, bundle ids, app group, home screen name
Shared/                     compiled into app + widget (models, storage, renderer, intents)
WidgetSimple/               the app (editor, wallpaper matching, guides)
WidgetSimpleWidget/         the widget extension
```
