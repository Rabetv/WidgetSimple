# Widget-side spec (for the widget owner)

The app side of the glass redesign is on branch `app-glass-redesign`. Everything below
lives in the widget extension (`WidgetSimpleWidget/`, `Shared/LauncherFace.swift`), which
the app-side work does not touch. The approved design is the Claude Design canvas
"WidgetSimple Redesign" (catalogue artboard = every widget type).

Priorities come from ~800 MD Widgets reviews (US, GB, DE, CA): clocks, weather, calendar,
photo and a dashboard are asked for most; widgets that go blank after iOS updates, data
that stops updating and "nothing is free" are the top complaints.

All of it must stay public API: the `appstore` flavour is audited by
`Scripts/audit-appstore.sh`.

## Shared requirements

- **Background option per widget** (new `Look` field): Glass (system container,
  default), Tinted (`.containerBackground` tint), Colour (solid), Clear (shows as Clear
  appearance only), **Matched wallpaper**: the person imports a screenshot of an empty
  Home Screen page in the app; the app crops the region for the chosen grid position
  and device model and stores it in the App Group; the widget draws it as its
  background. Public API, App Store safe. Needs a per-device frame table and a
  position picker (WidgetKit does not tell a widget where it sits).
- **Rendering modes**: every face must work in `.fullColor`, `.accented` (Tinted Home
  Screen) and `.vibrant` (Lock Screen, StandBy night) — reviewers report black or
  blank widgets in tinted mode and after iOS updates.
- **Tap behaviour**: an option to make a widget non-tappable (reviewers open apps by
  accident), and an explicit target app where a tap opens something.
- **12/24 h** follows the iPhone with an override; **Monday-first** follows the locale
  with an override; °C/°F and wind units likewise.
- **Families**: Home Screen small/medium/large/extra-large, Lock Screen
  `accessoryCircular`/`accessoryRectangular`/`accessoryInline` where the type makes
  sense, StandBy (small, night mode red).
- **Backup**: looks and widget settings in iCloud (key-value store is enough), so a
  restore or new phone keeps them — a recurring review complaint.

## Widget types

| Type | Families | Data / API | Notes |
|---|---|---|---|
| Launcher | all Home, Lock rect/inline, StandBy | `SystemShortcut`, `RunSystemShortcutIntent` | Exists. Add background options above. |
| Clock (14 styles) | all | `Text(date, style: .time)`, minute timeline for analog | Reviews: more faces, analog-only, thick/thin, 12 h, no leading zero. |
| Word Clock | small, medium, Lock rect, StandBy | 5-minute timeline | "quarter past ten"; localised (DE: "Viertel nach zehn"). |
| World Clock | medium, large, Lock rect | `TimeZone`, `Text` with `.environment(\.timeZone)` | Up to 4 cities, labelled by name. |
| Countdown | small, Lock circular | stored date, midnight timeline | "days to go" / "days since". Optional: pick a calendar event. |
| Calendar (up next, month) | small–large, Lock rect | EventKit full access, asked in the app (`NSCalendarsFullAccessUsageDescription`) | Choose calendars; month grid; hide past events (reviewers saw years-old events). |
| Reminders | small, medium, Lock rect | EventKit reminders; tick via `Button(intent:)` | Interactive. |
| Weather | small–large, Lock | WeatherKit (capability + entitlement) | Must show the Apple Weather attribution and legal link. Location: `NSWidgetWantsLocation` + when-in-use, or a manual city (reviewers ask for it). |
| Photo | small–XL | Photos picked in the app (`PhotosPicker`), downscaled copies in the App Group | Shuffle an album on a timeline, pin one, stickers (move/rotate/scale stored per widget). Keep images small: widget memory limit. |
| Text & Quote | small, medium, Lock | local | Daily quote rotation or own text. |
| Greeting | small, medium | name stored in app, time-of-day timeline | |
| Dashboard | medium, large | composes Clock, Weather, Calendar, Battery | Reviewers' favourite at MD (iBoard). |
| Battery | small, Lock circular | `UIDevice` battery, refreshed on timeline | **Design correction:** iPhone only. There is no public API for AirPods or Watch levels; drop "connected devices". |
| Music | medium | — | **Design correction:** a widget cannot read what other apps play. Either Apple Music via MusicKit in the app with `AudioPlaybackIntent` buttons, or drop the type. Reviewers' top music complaint is "doesn't update": don't promise now-playing. |
| Spacer | small, medium, large | empty view, clear container | The App Store build still shows "WidgetSimple" under it (2.3.8); only the AltStore build is label-free. |
| App Control | Control Center | `ControlWidgetButton` + `RunSystemShortcutIntent` (verify it runs from a control) | Spike first. |
| Shortcut Control | Control Center, Lock | `OpenURLIntent` with `shortcuts://run-shortcut?name=` | |

## Free vs Pro (decision for the owner of the App Store release)

MD Widgets' most common one-star reason is "almost nothing is free". The design marks
Launcher, Clock, Word Clock, Countdown, Text & Quote, Greeting, Spacer and App Control
as free and the rest as Pro. Today the app still locks the whole editor behind the
subscription; changing that is a product decision, not part of this spec.
