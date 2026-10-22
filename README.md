# WidgetSimple

Your apps as plain words on the iPhone Home Screen, on see-through glass, with a clock if you like.

## How it works

- **One widget.** Hold it › *Edit Widget*: pick up to 12 apps (iOS lists every installed app) and a clock (none, time, time and date, or date). A tap opens the app directly (`RunSystemShortcutIntent`, iOS 27). Sizes: Small, Medium, Large, Max.
- **One look for every widget**, set in the app: font, text size, alignment. The clock uses the same font and follows the iPhone's 12/24-hour setting.
- **The app is one screen with three steps:** add the widget, make it see-through, pick letters.

## See-through background

The widget hands its background to iOS: `.containerBackground(for: .widget) { Color.clear }`. On a **Clear** (or Tinted) Home Screen, iOS replaces it with its live Liquid Glass, so the wallpaper shows through and follows wallpaper changes by itself (no screenshots). The widget reads `widgetRenderingMode`: in `.accented` (Clear / Tinted) it draws white text only, with the clock as the accent that Tinted colors; in `.fullColor` (Default Home Screen) it uses the system text color, since iOS doesn't show the wallpaper through a widget there.

To turn it on: hold the Home Screen › Edit › Customize › **Clear**.

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

Xcode 27 or newer (iOS 27 SDK; the app needs iOS 27). `Config/Base.xcconfig` holds the team (`DEVELOPMENT_TEAM`), bundle prefix and Home Screen name. Open `WidgetSimple.xcodeproj`, enable automatic signing for both targets, run. The **Build** workflow compiles every push unsigned.

## No name under the widget

The label under a Home Screen widget is the app's Home Screen name (`CFBundleDisplayName`). `HOME_SCREEN_NAME` in `Config/Base.xcconfig` is set to U+2800 (invisible). If App Review rejects the app under Guideline 2.3.8, set it to `WidgetSimple`; large icons hide all labels anyway.

## Project layout

```
Config/Base.xcconfig        team, bundle ids, app group, home screen name
Shared/                     app + widget: look, clock option, fonts, storage, the widget face
WidgetSimple/               the app (one screen, font list)
WidgetSimpleWidget/         the widget
```
