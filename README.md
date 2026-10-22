# WidgetSimple

Your apps as plain words on the iPhone Home Screen, with a clock if you like. The widgets have the exact color of the wallpaper, so only the words show.

## How it works

- **One widget.** Hold it › *Edit Widget*: pick up to 12 apps (iOS lists every installed app) and a clock (none, time, or time and date). A tap opens the app directly (`RunSystemShortcutIntent`, iOS 27). Sizes: Small, Medium, Large, Max.
- **One look for every widget**, set in the app: color (black, gray, white), font, text size.
- **The app is one screen with five steps:** pick a color, pick letters, save the wallpaper, change four iPhone settings, add the widget.

## Why the widgets are invisible

A clear widget is not reliably see-through on iOS 26/27 (in the normal Home Screen style iOS can keep its own widget background behind it). So each widget is filled with exactly the color of the wallpaper the app saves to Photos. iOS also draws a glass edge on every widget; it disappears on a plain wallpaper with these settings (iOS 27, as [Blank Spaces](https://help.blankspaces.app/en/help/articles/3537637-how-to-hide-the-dock-and-widget-borders-ios-27) documents):

| | Black | Gray | White |
|---|---|---|---|
| Appearance | Dark | Dark | Light |
| Increase Contrast | **On** | Off | Off |
| Show Borders | Off | Off | **On** |
| Reduce Transparency | Off | Off | Off |

Plus: the app's wallpaper with Blur off, and Home Screen › Edit › Customize › **Default** with large icons (Clear and Tinted replace every widget background with glass). A photo wallpaper always keeps a visible edge.

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
Shared/                     app + widget: look, fonts, storage, the widget face
WidgetSimple/               the app (one screen, font list)
WidgetSimpleWidget/         the widget
```
