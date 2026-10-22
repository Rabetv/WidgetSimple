# WidgetSimple

Your apps as plain words on the iPhone Home Screen, in widgets that look see-through, with a clock if you like.

## How it works

- **One widget.** Hold it › *Edit Widget*: pick up to 12 apps (iOS lists every installed app) and a clock (none, time, time and date, or date). A tap opens the app directly (`RunSystemShortcutIntent`, iOS 27). Sizes: Small, Medium, Large, Max.
- **One look for every widget**, set in the app: font, text size, alignment, and white, black or automatic words (white on a dark piece of wallpaper, black on a light one). The clock uses the same font and follows the iPhone's 12/24-hour setting.
- **The app is one screen with three steps:** add the widget, make it see-through, pick letters.

## See-through background

On the normal Home Screen iOS draws its own box behind every widget, and no public API removes it. So each widget shows the piece of wallpaper behind it, which looks see-through:

1. **The wallpaper:** one of the five that ship with the app (no screenshot needed — the app already has the pixels), or a screenshot of an empty Home Screen page in jiggle mode (no icons over the wallpaper).
2. **Find my widgets:** every widget turns pink and shows its key as 4 × 4 black/white squares (`SpotCode`). From one screenshot of the Home Screen, `SeeThroughMaker` finds each pink frame (walking outward from inside the pink, then snapping to the size the widget reported), reads the key and cuts that frame out of the wallpaper.

The key is the widget's size (2 bits) plus a 14-bit hash of its clock and apps (`SpotKey`), so each widget finds its own piece; if its apps change and it's the only widget of its size, it keeps the piece. A new wallpaper needs step 1 again, a moved widget needs step 2. On a Clear or Tinted Home Screen iOS replaces the background with its own glass, which needs no setup.

Step 2 has to happen even with a bundled wallpaper, because iOS doesn't tell a widget which slot of the Home Screen it sits in — only its size. The see-through apps that skip the screenshot (`ANALYSIS.md` has the measurements) get around that by asking the user for the slot: they ship each wallpaper pre-cut per slot, with a per-slot "the wallpaper here is dark" table (`sectionsIsDark`). This app instead finds the widgets once and measures the darkness of each piece it cuts, which needs no per-slot assets and survives any wallpaper.

### Bundled wallpapers

`WidgetSimple/Wallpapers/` holds each wallpaper as the two overlapping slices the see-through widget apps use (`<id>.slice.top.jpg`, `<id>.slice.bottom.jpg`), not as one screenshot: the previews in those apps' bundles have their buttons and the dock burned in, the slices don't. `WallpaperCatalog` stacks them back into the widget area (`top` at the top, `bottom` 544 px down, 518 px of overlap), scales that canvas to fill the screen and stores exactly those pixels, so the piece the widget shows is the piece that is behind it. To add a wallpaper, drop two slices in and add one line to `WallpaperCatalog.all`.

The five images are the wallpapers of the MD Blank app, copied for private use; they are not licensed for redistribution. Delete the folder and the `WallpaperCatalog.all` entries before making the repository public.

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
WidgetSimple/               the app (one screen, font list, bundled wallpapers)
WidgetSimpleWidget/         the widget
ANALYSIS.md                 how the reference app does the same look, and the measurements
```
