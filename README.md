# WidgetSimple

Your apps as plain words on the iPhone Home Screen, in widgets that look see-through, with a clock if you like.

## How it works

- **One widget.** Hold it › *Edit Widget*: pick up to 12 apps (iOS lists every installed app) and a clock (none, time, time and date, or date). A tap opens the app directly (`RunSystemShortcutIntent`, iOS 27). Sizes: Small, Medium, Large, Max.
- **One look for every widget**, set in the app: font, text size, alignment, white or black words. The clock uses the same font and follows the iPhone's 12/24-hour setting.
- **The app is one screen with three steps:** add the widget, make it see-through, pick letters.

## See-through background

On the normal Home Screen iOS draws its own box behind every widget, and no public API removes it. So each widget shows the piece of wallpaper behind it, which looks see-through:

1. **Wallpaper screenshot:** an empty Home Screen page in jiggle mode (no icons over the wallpaper).
2. **Find my widgets:** every widget turns pink and shows its key as 4 × 4 black/white squares (`SpotCode`). From one screenshot of the Home Screen, `SeeThroughMaker` finds each pink frame (walking outward from inside the pink, then snapping to the size the widget reported), reads the key and cuts that frame out of the wallpaper screenshot.

The key is the widget's size (2 bits) plus a 14-bit hash of its clock and apps (`SpotKey`), so each widget finds its own piece; if its apps change and it's the only widget of its size, it keeps the piece. A new wallpaper needs step 1 again, a moved widget needs step 2.

### The piece is content, not the background

From iOS 26 the system removes a widget's container background on a Clear or Tinted Home Screen and draws its own themed glass in its place — "Removes the background and replaces it with a themed glass or tinted color effect" ([Apple](https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass)). A wallpaper piece passed to `.containerBackground(for: .widget)` is therefore the one thing that gets deleted, and what is left is the system's grey box.

So `LauncherWidgetView` draws the piece inside the widget's **content**, full bleed, and leaves the container background empty: content is never removed. `.widgetAccentedRenderingMode(.fullColor)` stops the accent tint from painting the piece white, and the words stay on top of it with their buttons unchanged. `contentMarginsDisabled()` is what lets the piece reach the widget's edges.

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
