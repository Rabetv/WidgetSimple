# App Store listing

Paste-ready copy for App Store Connect. Character limits are noted for each field.

This listing describes the App Store build (see `RELEASES.md`): public API only, widgets
drawn over the matching piece of the person's wallpaper, the name under the icon visible,
and the editor unlocked by a StoreKit subscription.

## Name (30)

```
WidgetSimple
```

## Subtitle (30)

```
Your apps as words on widgets
```

## Promotional text (170)

```
Your apps as plain words on the Home Screen. Pick up to 12 apps, tap a word to open the app, and style the font, colour, size and placement in one place.
```

## Keywords (100, comma separated)

No app names, no competitor names, nothing already in the name or subtitle.

```
launcher,text,minimal,aesthetic,typography,font,clock,home screen,shortcut,list,clean,simple
```

## Description (4000)

```
WidgetSimple puts your apps on the Home Screen as plain words.

Instead of a grid of icons, a widget shows the names of the apps you choose, in the
font and colour you like. Tap a word and the app opens.

WHAT YOU GET

• Up to 12 apps per widget, each one a word you can tap to open the app
• A clock: none, time, time and date, or date — in the same font, 12/24 h from the iPhone
• Style everything in the app: font, size, alignment, letter case, colour, shadow, spacing
• 40 built-in iPhone fonts, plus your own .ttf / .otf files
• White, black, or any colour you like
• Stacked layout, or free placement: put the clock and the words anywhere on the widget
• Every widget on the Home Screen follows the look you set, instantly
• Small, medium, large and extra-large sizes
• Per widget in Edit Widget: position, text size, text colour, a dimmer for bright
  wallpapers, and an option to show the words without opening apps

HOW IT LOOKS

Each widget shows the piece of your wallpaper that sits behind it, so the words look like
they are written on your Home Screen. Set-up takes two screenshots of an empty Home
Screen page, one in Light Mode and one in Dark Mode. If a widget isn't at the top left,
tell it where it sits in Edit Widget › Position.

WHY THE APPS ARE PICKED IN EDIT WIDGET

iOS lets only the system offer the list of installed apps, so that one step happens in
the widget's Edit Widget sheet. Everything else — font, colour, size, placement, clock —
is set in the app and applies to all your widgets at once.

WIDGETSIMPLE PRO

The style editor is unlocked with WidgetSimple Pro, an auto-renewable yearly
subscription. New subscribers get the first 3 months free; after the free trial the
yearly price is charged unless you cancel at least 24 hours before it ends. Payment is
charged to your Apple Account at confirmation of purchase.
The subscription renews automatically unless cancelled at least 24 hours before the end
of the current period; you can manage or cancel it in Settings › Apple Account ›
Subscriptions. Widgets you already placed keep working if the subscription ends.

No account. No ads. No tracking.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://rabetv.github.io/widgetsimple-site/privacy.html
```

## In-app purchase (App Store Connect › Subscriptions)

| Field | Value |
|---|---|
| Subscription group | WidgetSimple Pro |
| Reference name | WidgetSimple Pro Yearly |
| Product ID | `com.rabetv.widgetsimple.pro.yearly` (must match `StoreConfig.productID`) |
| Duration | 1 year |
| Price | €1/year target — pick the nearest EUR price point (e.g. €0.99), let Apple derive other storefronts |
| Introductory offer | Free trial, 3 months, all storefronts, no end date (new subscribers only; Apple enforces one per group and Apple Account) |
| Display name | WidgetSimple Pro |
| Description | Unlocks the style editor for all widgets. |
| Review screenshot | Apple's subscription screen in the `appstore` build (price, trial, Restore, Terms, Privacy) |
| Review notes | see "Notes for review" below |

The first subscription must be **submitted together with the app version** (Distribution
› the version › In-App Purchases and Subscriptions › add it), or review sees no product
and the buy button stays on "Loading…".

## Category

Primary: Utilities. Secondary: Productivity.

## Age rating

Answer **None / No** to every content question, "No" to unrestricted web access,
user-generated content, messaging, gambling and loot boxes → **4+**.

## App Privacy (nutrition label)

**Data Not Collected.** The app makes no network calls of its own in the `appstore`
build (the Lemon Squeezy licence code is compiled out); purchases go through StoreKit,
which Apple handles. `PrivacyInfo.xcprivacy` declares no collected data types.

## URLs

- **Privacy Policy URL:** https://rabetv.github.io/widgetsimple-site/privacy.html
  (English and German; also linked from the paywall via `StoreConfig.privacyURL`).
- **Support URL:** https://rabetv.github.io/widgetsimple-site/ (help, subscription,
  contact, Impressum).
- Both pages live in the public repository `Rabetv/widgetsimple-site` (GitHub Pages).
- Marketing URL: optional, leave empty.

## Screenshots to capture

Ready: `AppStore/screenshots/*.png`, 1320 × 2868 (6.9", the required size; App Store
Connect scales them for smaller iPhones). Upload in this order:

1. `01-apps-as-words.png`: hero, launcher widgets on the system glass.
2. `02-style-every-word.png`: the editor (40+ fonts = 4 system + 40 built-in families).
3. `03-templates.png`: the Templates tab, two templates popping out.
4. `04-every-size.png`: small, medium, large and extra-large widgets.
5. `05-place-anywhere.png`: free placement, word by word.
6. `06-three-steps.png`: the first-run tutorial; no account, no ads, no tracking.

Style: dark warm stage, amber ribbon, callout pills, screens breaking out of the frame.
Every claim on them is true for the `appstore` build; no user counts or ratings.

They show only what the `appstore` build has: the launcher widget on the system glass,
no other widget types (2.3.1, 2.3.3). Sources: `AppStore/screenshots/src/*.html`,
rendered with headless Chrome at 1320 × 2868; re-render after UI changes.

## Notes for review

Paste into App Review Information › Notes:

```
WidgetSimple shows apps as words in a Home Screen widget; tapping a word opens the app.
The app uses public API only.

1. Subscription. The first screens are a short tutorial and the StoreKit subscription
   screen (SubscriptionStoreView) for "WidgetSimple Pro"
   (com.rabetv.widgetsimple.pro.yearly, 1 year). Restore Purchases, Terms of Use and
   Privacy Policy are on that screen; Settings › Manage subscription opens the system
   sheet. Please subscribe with a sandbox account.

2. Wallpaper set-up. Each widget draws the piece of the wallpaper behind it, cut from
   screenshots the person picks in the system photo picker. After subscribing the app asks
   for two screenshots of an empty Home Screen page, one in Light Mode and one in Dark
   Mode. Until both are picked, widgets show "Open WidgetSimple to add your wallpaper".
   Any two Home Screen screenshots work for review; one must be taken in Dark Mode.

3. Choosing apps. Apps are chosen in the widget's Edit Widget sheet (touch and hold the
   widget › Edit Widget › App 1…12). Each slot is an App Intents parameter of type
   SystemShortcut, which has no public initializer and cannot be enumerated, so only
   the system can offer the list of installed apps. Opening an app uses the public
   iOS 27 RunSystemShortcutIntent. The app styles the words (font, colour, size,
   placement, clock) for all widgets at once.

4. WidgetKit doesn't tell a widget where it sits, so each widget has Position (Top,
   Middle, Bottom) and Side (Left, Right, for small widgets) in Edit Widget; top left is
   the default. The app cuts the wallpaper for every position from the two screenshots.

No login is required. The app collects no data and makes no network requests of its own.
```
