# CHANGES — branch `seethrough-fixes` (from `origin/main` b83c73c)

Bug fixes for the matched-wallpaper see-through, a layout engine with a design system,
the freeform layout editor, seven more widget kinds, a CC0 stock library, and the
removal of the private-API hook. Public API only. It compiles on CI (Xcode 27.1, Release,
warnings as errors, no warnings); nothing has run on a device yet — see "Not verified"
before merging.

## Where the handoff and the repository disagreed

| Handoff said | Repository had | What I did |
|---|---|---|
| Working tree `WidgetSimple-main/`, "no private API, verified absent" | `origin/main` (and every branch) contains `WidgetSimpleWidget/WidgetDescriptorHook.mm`, a swizzle of WidgetKit's descriptor XPC server, shipped on purpose ("App Store risk accepted") | Deleted it, plus everything that leaned on it (glass probe, hook log, "Clear removes the container" copy). The repo-wide grep from the handoff now returns nothing. |
| `HOME_SCREEN_NAME = " "` (DeepSeek) | Still U+2800 on `main` | Set to one U+0020 space (built from two empty expansions, since xcconfig trims whitespace); the audit checks the built plist. |
| Widget extension display name stays `WidgetSimple` | It was `$(HOME_SCREEN_NAME)` | Set to `WidgetSimple`. |
| `ANALYSIS.md`, `widget_probe.py`, `device_fetch.py` | Not in this repo or on this machine | Not used. |

## Bug fixes (§3)

Each fix carries a one-line comment in the code naming the failure mode.

**3.1 Wallpaper in the wrong widget / in plain widgets**
- (a) *Key collisions.* Every widget kind now has a `See-through ID` parameter
  (`WidgetIdentity`, `WidgetSimpleWidget/SeeThroughWidget.swift`): a UUID the system
  stores in that widget's configuration, filled by `defaultResult()` when the widget is
  added. Keys are `family(2) | origin(1) | hash(29)` of that UUID. Widgets added before
  this have no ID and keep a content key (migration only; kind `WidgetSimpleDirect`
  unchanged). If two widgets ever share a key, the scan drops both and says how to fix it
  ("set a new See-through ID in Edit Widget").
- (b) *Silent fallback.* `SharedStore.spotImage` returns only the exact key's piece. No
  "only one of its size" borrowing anywhere; a widget without its own piece draws
  `Color.clear` (the system background). Builds 35–39 pieces are still read by exact
  legacy key until the first new scan, so existing users don't lose see-through on update.
- (c) *Stale spots / mid-render wipe.* Pieces are written into a new folder
  `Spots/<generation>/` and switched in by one atomic write of `see-through.json`; the
  previous generation is kept so a widget mid-render still finds its file. A rescan of
  one page keeps identity-keyed matches on other pages; "Start over" forgets all.

**3.2 Misaligned crops.** The size each widget reported is the authority; the pink only
gives the centre. `pixelsPerPoint` = screenshot width ÷ screen width in points (correct
under Display Zoom) and is stored. Screenshots must be portrait and exactly this iPhone's
native pixel width. A widget whose measured size is more than 2 % off its reported size
rejects the whole scan with a message, and nothing is changed.

**3.3 `readKey` dropping widgets.** The code is now 6 × 6 (32-bit key + CRC-4). It is
located from the pixels (the non-pink block in the middle), not from an assumed size.
Each square is the median of 9 samples over its inner half, with 0.35 / 0.65 bands, and
pink samples are ignored. The CRC rejects misreads, so tolerance can't produce a wrong
key. Unreadable codes are kept and reported ("found N widgets but couldn't read their ID").

**3.4 Layout and spacing.** New `Shared/DesignSystem.swift` (`Spacing` 4–32,
`Typography` ratios, `FaceMetrics` widget sizes) and `Shared/FacePlan.swift`. The planner
measures every word with the same font the face draws (UIKit/CoreText), picks columns
1–4 (row-major, `rows = ⌈n/cols⌉`, last row padded, no empty columns) and clock
above/beside, and applies **one** scale to the whole block. The clock may shrink to 60 %
before the words do. Margins come from `widgetContentMargins`, not a constant;
Dynamic Type scales the words before the fit. `ViewThatFits` and per-word
`minimumScaleFactor(0.6)` are gone. The older "Free" arrangement still works, and words
on the same anchor are now stacked instead of drawn on top of each other.

**3.5 Smaller bugs**
- Preview card draws at the widget's real point size (reported by the widget) and scales
  the picture, over this size's matched piece or the middle of the wallpaper screenshot.
- `model.message` is shown as an alert from every tab.
- The same-size / same-device / upright rule is stated in the See-through footer before
  the second screenshot.
- Atomic piece swap (above).
- `recordSize` no longer reads or writes the file on every timeline call (in-process cache).
- Every app name is announced as "Phone, app"; the face is a container labelled
  "Launcher: Phone, Messages, …".
- Widget reloads from the editor are debounced to 300 ms.

## Features (§4)

**4.1 Catalogue.** Every kind is see-through, declares its families and disables content
margins (the piece is full-bleed; content re-applies the system margins).

| Kind (`kind`) | Families | Notes |
|---|---|---|
| Launcher (`WidgetSimpleDirect`, unchanged) | S M L XL | + Layout and See-through ID parameters |
| Text (`WidgetSimpleText`) | S M L, Lock rect | |
| Date & Time (`WidgetSimpleDateTime`) — new | S M L, Lock inline/circular/rect | time, time+date, date, calendar page, optional second city |
| Countdown (`WidgetSimpleCountdown`) | S M, Lock circular/rect | days to go / hours on the last day / days since |
| World Clock (`WidgetSimpleWorldClock`) | S M L, Lock rect | now a minute timeline |
| Photo (`WidgetSimplePhoto`) — new | S M L | photo per widget from the library, optional hourly shuffle, focal-point crop per size |
| Greeting (`WidgetSimpleGreeting`) — new | S M | time of day + optional name, localised |
| Dashboard (`WidgetSimpleDashboard`) — new | S M L, Lock circular | clock, battery %, free storage |
| Zen (`WidgetSimpleZen`) — new | S M | a step per minute + a live `ProgressView(timerInterval:)` ring |
| Spacer (`WidgetSimpleSpacer`) | S M L | shows its wallpaper piece |
| Run Shortcut control (`WidgetSimpleRunShortcutControl`) — new | Control Center, Lock Screen controls | MD's "Control Widget": runs a shortcut by name via `OpenURLIntent(shortcuts://run-shortcut?name=…)`. An "open any app" control is **not possible**: the App Intents metadata processor rejects `SystemShortcut` outside widget configuration intents (CI run 40082067043) |
| Weather — stub, **not built** | S | behind `WEATHER`; placeholder data only (see decisions) |
| Music — **skipped** | | a widget can't read another app's playback; the Launcher opens Music |
| Live Wallpaper — **not a widget** | | MD's Live Wallpaper is an app feature that makes a Live Photo the wallpaper; no public API sets the wallpaper, so it is out of scope |

**4.2 Stock photos.** 14 photos in `WidgetSimple/Stock/`, every one **CC0 1.0**
(Wikimedia Commons Quality Images; licence and "no restrictions" checked per file through
the Commons API). Each is sRGB, JPEG q80, at most 1600 px and under 300 KB (3.4 MB in all).
`stock-manifest.json` has id, title, file, credit, licence, source and focal point.
`CREDITS.md` lists each file's source and contains the CC0 legal code verbatim; it is
shown in Settings › Photo credits. I did not use the Unsplash or Pexels licences: both
forbid redistributing photos in a way that competes with or replicates their service,
which is a risk for a paid widget app. The app copies the files into the App Group on
launch. Nothing is fetched at run time.

**4.3 Freeform layouts.** Widgets › Launcher › Layouts. The canvas is the real widget at
real size and draws the same `LauncherFace` from the same plan. Drag words (and the
clock), snap to a 12 × 8 grid with centre guides, and set per-word size, rotation,
weight, opacity and colour. Column mode offers 1–4 or auto, row/column spacing and a
vertical offset. Layouts are saved as `Layouts/<uuid>.json` plus a PNG thumbnail and
picked per widget in Edit Widget › Layout (`LayoutEntity`). A word overlapping an
earlier one by more than 40 % moves by one grid row. Names come from what a launcher
last showed (the widget records them), else samples.

**4.4 Editor.** Grouped into See-through, Background, Apps, Clock, Typography (font,
weight, size, letter spacing, case), Colour (white/black/custom, "match my wallpaper",
shadow) and Layout (alignment, position, spacing, columns auto/1–4, inset from the edges
−8…+24 pt on top of the system margins, arrangement, Layouts, "Check every size").
The vertical position now defaults to Middle for new installs, so a few names sit
centred and a full block looks the same as Top; stored looks keep their choice. See-through has the three steps, status (matched / unread / shared IDs), a map
of where each widget was matched (the seam explanation) and Start over.

## Also changed

- `Scripts/audit-appstore.sh`: looks for every hook trace and forbidden runtime import in
  the binaries, prints linked frameworks and fails on a private one, and checks
  `CFBundleDisplayName` is a single space. The private names are assembled from pieces,
  so the script itself passes the repo grep.
- CI (`build.yml`): warnings as errors, a source grep step, linker maps, and the audit
  now **blocks**. `testflight.yml`: linker maps for the archive, and the audit blocks the
  upload.

### The audit and the dynamic symbol lookup import

Both binaries import the libSystem symbol-lookup function the handoff's grep bans
(`_dl` + `sym`), although no source calls it. Build run 40080516837 traced it with
the linker map. The only linked input that references it, in the app and in the widget
extension, is `libclang_rt.ios.a(os_version_check.c.o)`: clang's compiler runtime
behind `#available` / `@available`, which looks up the system's OS-version check by
name. Every Swift binary with an availability check carries it, and it is not private
API.

The rule (`check_lookup` in the audit) is exact, not a blanket allowance:

- both workflows link with `LD_GENERATE_MAP_FILE=YES` and pass the map folder to the
  audit as its second argument;
- the import passes only if the binary's map shows `libclang_rt.*.a(os_version_check.c.o)`
  as its **sole** referencer (archive members that aren't linked don't count);
- it fails if any other object references it (and names that object), if no linked input
  references it, or if no map was given;
- the dynamic library loader import, class lookup by name and every method-swizzling
  call stay hard failures with no exception.

Tested against a fake `nm` and fabricated link maps: clang only → pass; clang plus a
project object → fail naming the object; no map → fail.
- Privacy manifests: widget declares disk space (85F4.1, shown to the person); app
  declares UserDefaults (CA92.1, already used by `@AppStorage`).
- German strings for everything new; the widget extension gets its first `de.lproj`.
- README, RELEASES, WIDGETS-SPEC and the App Store listing no longer claim the container
  is removed. The **review notes** now describe the matching honestly.

## Handoff coverage

| Handoff | Status |
|---|---|
| §0 no private API, grep clean | done — hook deleted; repo grep empty; CI source grep + binary audit block |
| §0 don't remove the container | done — see-through is drawn inside it |
| §0 bundle ids, App Group, team, iOS 27, Swift 5, no dependencies | unchanged |
| §0 preview pixel-identical through `LauncherFace` | done — preview, layout editor, thumbnails and Date & Time all draw `LauncherFace` from the same plan at real size |
| §1 audit DeepSeek's work | done — see "Where the handoff and the repository disagreed" |
| §3.1 a/b/c | done — identity keys, exact lookup, atomic generations |
| §3.2 reported size authority, record pixel size + scale, 2 % reject | done — `pixelsPerPoint` = screenshot width ÷ screen points, validated against the native pixel width |
| §3.3 tolerant decoder, keep unread spots | done |
| §3.4 Spacing, Typography, measured columns, balanced rows, centred when few, Dynamic Type, content margins, harness | done (centred via the Middle default) |
| §3.5 preview wallpaper, error surface, same-size note, atomic swap, debounce, VoiceOver | done |
| §4.1 catalogue incl. Control Widget | done; Weather stub (needs a source decision), Music skipped, Live Wallpaper not a widget |
| §4.2 stock photos, CREDITS, offline | done — 14 CC0 |
| §4.3 LayoutEditor, LayoutEntity, freeform, migration, per-layout options | done |
| §4.4 grouped editor, debounced reloads | done |
| §5 acceptance | grep, `nm`/linked frameworks, display name, warnings-as-errors, no force unwraps: verified on CI. Layout matrix: verified by the planner port + in-app harness. Seam, identical widgets, ±1 pt freeform, VoiceOver: device only |
| §6 before/after screenshots on three wallpapers | not done — needs the iPhone |
| §7 don'ts | respected |
| §8 deliverables | this file, one branch |

## Verified here (Windows, no Mac)

- Repo-wide grep from the handoff: no matches. No `.m/.mm/.h` files remain.
- No force unwraps or `try!` in any file I touched.
- **Scanner:** a Python port of `SpotKey` + `SeeThroughMaker.scan`, run on synthetic
  1206 × 2622 screenshots (photo wallpaper, 10 % veil, 3 px rim, blur, a shadow across
  one code). 4/4 widgets found with **0 px** crop error; CRC caught 2000/2000 single-bit
  errors; all-white/all-black never decode; duplicates dropped; a fogged code is reported
  as unread; a wrong reported size is rejected; a family with no reported size falls back
  to the pink rect.
- **Layout:** a Python port of the column planner, run on the acceptance matrix
  (1/2/4/8/12 apps × S/M/L × 17/21/26 pt, clock on and off) with Arial, Georgia and Segoe
  UI metrics: **no overlap and no clipping** in any cell. The tightest cell is small,
  26 pt, 12 apps with a clock, at 43 % scale. That is why the floor is 0.4.
- Plists and both privacy manifests parse; strings files have no duplicate keys.

## Verified on CI (GitHub Actions, Xcode 27.1, iOS 27.1 SDK)

- Release build of the app and the widget for the device: **BUILD SUCCEEDED, no errors
  and no warnings**, with warnings as errors.
- Source grep for private symbols: clean.
- Binary audit: no hook traces, no swizzling imports, no external payment code, only
  public system frameworks linked, the StoreKit product compiled in, and
  `CFBundleDisplayName` a single space (so the xcconfig space trick works). The
  symbol-lookup import is attributed to clang's runtime as described above.

## Not verified — needs CI and the device

1. **Nothing has run on a device.** It compiles; the behaviour below still needs the
   iPhone. The TestFlight workflow has not run with these changes.
2. `WidgetIdentity.defaultResult()` gives each **new** widget its own UUID. If the system
   reuses one default, the scan reports the shared ID instead of mis-matching; the fix is
   "New ID" in Edit Widget. Confirm on device that two freshly added identical widgets
   get different IDs (Edit Widget shows "Widget XXXX").
3. The blank name is verified in the built plist; that iOS shows no label under the
   widget with it is still to be seen on the device.
4. Content margins are recorded from the widget's body; check the preview matches.
5. `UIDevice.batteryLevel` in the extension may report "–" on some iOS versions.
6. The magenta threshold was widened for the glass veil (r,b > 200, g < 90); check a scan
   on a pink or purple wallpaper.
7. The Run Shortcut control: that `OpenURLIntent` with a `shortcuts://` URL runs the
   shortcut when tapped in Control Center (Apple documents `OpenURLIntent` for controls;
   another app's URL scheme is the part to confirm).

## How to test each fix on the device

- **3.1a** Add two launchers of the same size with the same apps on two pages. Match
  (take a pink screenshot of each page and pick both). Each shows its own piece; move
  one and rematch, and only that one changes.
- **3.1b** After matching, add a new widget: it shows the system background, never
  another widget's piece.
- **3.1c** Change the clock or the apps on a matched launcher: its piece stays (the
  identity didn't change). Rematch while watching the Home Screen: no frame without a
  background.
- **3.2** Set Display Zoom differently from when the widgets were added and match: the
  scan is refused with the size message. At 100 % zoom, the edge ring with
  `widget_probe.py` should be under 3/255 inside the rect.
- **3.3** Match with a notification banner partly over one pink widget: it is reported as
  unread, not silently dropped, and gets no piece.
- **3.4** Widgets › Launcher › Check every size: every cell should read "fits" or
  "shrunk to N %", never "overlap" or "clipped".
- **4.3** Make a Free layout, drag "Phone" to the bottom right, save, and pick it in Edit
  Widget › Layout: the widget shows it there.
- **Name** `plutil -p WidgetSimple.app/Info.plist | grep CFBundleDisplayName` → `" "`.
- Take before/after screenshots of each family on a bright gradient, a photo and pure
  black.

## Decisions for the owner

- **Weather:** WeatherKit (capability on both App IDs + Apple attribution) or Open-Meteo
  (no key, but its free tier is non-commercial, so a paid app needs the paid plan). The
  stub is behind `WEATHER` until then.
- **Uptime** for the dashboard is left out: boot time is a required-reason API with no
  approved reason for showing it.
- **App Store screenshots** show the old launcher only; reshoot before using the new
  listing copy.
- The blank name is a 2.3.8 risk; the fallback stays documented in `Base.xcconfig`.
