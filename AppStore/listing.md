# App Store listing

Paste-ready copy for App Store Connect. Character limits are noted for each field.

This listing describes the **`appstore` flavour** (see `RELEASES.md`): no private API,
the widget sits on the system glass, the name under the icon is `WidgetSimple`, and the
editor is unlocked by a StoreKit subscription. Nothing here may promise the truly
transparent look of the AltStore build — that would be inaccurate metadata (2.3.1, 2.3.7).

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

HOW IT LOOKS

Your words sit on the standard iOS widget background. With the Clear or Tinted Home
Screen appearance, iOS shows that background as glass over your wallpaper.

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
Privacy Policy: <PRIVACY POLICY URL>
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
| Review screenshot | the paywall of the `appstore` build (shows price, length, Restore, Terms, Privacy) |
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

- **Privacy Policy URL (required): not hosted yet — blocker.** Text ready in
  `AppStore/privacy.md`. Once it is public, put the URL here, in the description above
  and in `StoreConfig.privacyURL` (`WidgetSimple/License.swift`), which the paywall links to.
- **Support URL (required): not hosted yet — blocker.** Any public page with a contact
  e-mail works. This repository is private, so its README is not reachable.
- Marketing URL: optional, leave empty.

## Screenshots to capture

Capture from an **`appstore`-flavour build** only: the AltStore/hook build has no glass
and would make the screenshots inaccurate (2.3.3). Required: 6.9" display
(1320 × 2868 or 1290 × 2796 portrait); App Store Connect scales them for smaller iPhones.

1. Medium widget on the Home Screen, clock + 4 words, photo wallpaper.
2. Same widget with free placement: clock bottom-right, words top-left.
3. Small widget, white words, Clear Home Screen appearance (glass visible).
4. Style screen in the app (form with live preview).
5. Edit Widget sheet choosing apps (shows why apps are picked there).

## Notes for review

Paste into App Review Information › Notes:

```
WidgetSimple shows apps as words in a Home Screen widget; tapping a word opens the app.

1. Appearance. The widget uses only public WidgetKit/SwiftUI API. It draws its words
   over a clear container background (containerBackground(for: .widget)), so iOS shows
   its standard widget background — glass under the Clear and Tinted appearances. The
   widget is visually transparent only as far as that public API allows; we do not
   remove or alter the system container.

2. Choosing apps. Apps are chosen in the widget's Edit Widget sheet (long-press the
   widget › Edit Widget › App 1…12). Each slot is an App Intents parameter of type
   SystemShortcut, which has no public initializer and cannot be enumerated, so only
   the system can offer the list of installed apps. The app itself styles the words
   (font, colour, size, placement, clock) for all widgets at once.

3. No private API. The build contains no private frameworks, selectors or method
   swizzling. Opening an app uses the public iOS 27 system shortcut intent.

4. Subscription. The style editor unlocks with the auto-renewable subscription
   "WidgetSimple Pro" (com.rabetv.widgetsimple.pro.yearly, 1 year) with a 3-month free
   trial for new subscribers; the paywall states the trial length and the yearly price
   that follows. Buy it from the first screen with a sandbox account; "Restore Purchases", Terms of Use and Privacy
   Policy are on the same screen, and Account › Manage subscription opens the system
   subscription sheet. Widgets keep rendering without a subscription.

No login is required. The app collects no data.

To test: install, tap Subscribe and confirm with the sandbox account, then add the
WidgetSimple widget from the Home Screen gallery and pick apps in Edit Widget.
```
