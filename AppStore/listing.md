# App Store listing

Paste-ready copy for App Store Connect. Character limits are noted for each field.

## Name (30)

```
WidgetSimple
```

## Subtitle (30)

```
Apps as words, see-through
```

## Promotional text (170)

```
Truly transparent widgets: no glass, no frames — just your apps as words on the wallpaper. Pick up to 12 apps, tap one to open it, and style every detail in the app.
```

## Keywords (100, comma separated)

```
widget,transparent,clear,text,launcher,apps,home screen,see through,minimal,aesthetic,words
```

## Description (4000)

```
WidgetSimple puts your apps on the Home Screen as plain words — in widgets that are
actually transparent.

No glass box. No rounded frame. No wallpaper screenshot to line up. Just your words on
your wallpaper, at any position, on any wallpaper, in any Focus.

WHAT YOU GET

• Up to 12 apps per widget, each one a word you can tap to open the app directly
• A clock: none, time, time and date, or date — in the same font, 12/24 h from the iPhone
• Style everything in the app: font, size, alignment, letter case, colour, shadow, spacing
• 40 built-in iPhone fonts, plus your own .ttf / .otf files
• White, black, or any colour you like
• Stacked layout, or free placement: put the clock and the words anywhere on the widget
• Every widget on the Home Screen follows the look you set, instantly

WHY IT LOOKS CLEAR

iOS draws its own glass container behind every widget. WidgetSimple removes that
container, so the wallpaper itself is the background — nothing is faked with pictures.

WHY THE APPS ARE PICKED IN EDIT WIDGET

iOS only lets the system fill the app list, so that one step happens in the widget's
Edit Widget sheet. Everything else — font, colour, size, placement, clock — is set in
the app and applies to all your widgets at once.

SMALL, MEDIUM, LARGE, MAX

One widget that fits every Home Screen size.

No account. No ads. No tracking. No subscription.
```

## Category

Utilities (secondary: Productivity)

## Support / marketing URLs

- Support URL: _needs a page_ (a GitHub README works)
- Marketing URL: optional

## Screenshots to capture

App Store requires 6.9" (iPhone 16/17 Pro Max) and 6.5"; capture on device or the
simulator:

1. Widget over a photo wallpaper, medium size, clock + 4 words.
2. Same widget, Free placement: clock bottom-right, words top-left.
3. Small widget, white words over a dark wallpaper.
4. Style screen in the app (Form with preview).
5. Large widget with a long app list and a custom colour.

## Notes for review

- The widget is transparent by design; the Home Screen label is a blank character
  (`HOME_SCREEN_NAME` = U+2800). If Guideline 2.3.8 is raised, set it to `WidgetSimple`.
- App launching uses `RunSystemShortcutIntent` (iOS 27) from a widget button — the
  supported API for opening a person's chosen app.
- **Risk to disclose internally:** the transparent background is produced with a private
  API (widget descriptor flags). Apple may reject under 2.5.1. The build for TestFlight
  is fine; an App Store submission should either remove the hook and accept the system
  glass, or expect a rejection.
- Privacy: the app collects nothing; no network calls.
