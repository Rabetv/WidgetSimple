# How MD Blank makes its widgets see-through

These are the measurements behind the `WallpaperCatalog` and the automatic word color.
They come from an extracted copy of MD Blank 4.3.3 (`tech.miidii.MDBlank`) on an iPhone
running iOS 27: its app bundle, its App Group container and its Core Data store.

Short version: **the widgets are not transparent.** The app knows which piece of the
wallpaper sits behind each widget slot and draws that piece as the widget's background.
The look is wallpaper slicing, plus a per-slot "is this area dark" table for the words.

## What was in the dump

```
Payload/MDBlank.app/Info.plist                      encrypted; no executable in the dump
Container/Library/Preferences/tech.miidii.MDBlank.plist
Container/AppGroups/group.tech.miidii.MDBlank/
    DataModel.sqlite                                4 widgets, control widgets
    Library/Preferences/group.….plist               the wallpaper centre (below)
    Widget/Background/                              5 wallpapers, 32 files
    WidgetPhoto/                                    96 built-in photos, per-size crops
    WallpaperPhoto/                                 empty (the user's own wallpapers)
```

The `.app` is only an encrypted `Info.plist`, so no binary was available to search for
selectors. The app is distributed through the App Store (RevenueCat and AppsFlyer are
wired in, `App.LatestRelease` = 2.8), which rules out the private
`setTransparent:` / `setBackgroundRemovable:` route anyway: an App Store build calling
those would be rejected. Nothing in the dump suggests one.

## 1. A wallpaper library, stored pre-sliced

`Widget/Background` holds five wallpapers (`WallpaperCenter.Wallpapers` names them
*Hintergrund*, *Background*, *Background 2*, *Background 3*, *Emily*), each with:

| file | size | what it is |
| --- | --- | --- |
| `preview.light` / `preview.dark` | 1179 × 2556 | a full screen screenshot **with the app's own buttons and the dock burned in** |
| `slice.top.<scheme>` | 1047 × 1062 | the clean top of the Home Screen's widget area |
| `slice.bottom.<scheme>` | 1047 × 1095 | the clean bottom, overlapping the top |
| `small.preview.<scheme>` | 354 × 767 | the list thumbnail |

The previews are what the app shows while you pick a wallpaper; the slices are the pixels
it actually cuts widget backgrounds from. Note the slices are 1047 px wide, not 1179:
they cover the widget area, not the screen.

## 2. Registering the slices: the widget-area canvas

Both slices were registered against `preview.light` with a scale-and-offset search
(downsampled template match over the clean band of the screenshot, `y` ∈ 10 %–84 % to
skip the status bar and the dock). Mean absolute error at the optimum was ~1 grey level,
i.e. an exact match:

| slice | scale | position on the 1179 × 2556 screenshot |
| --- | --- | --- |
| `slice.top.light` | 0.99–1.00 | x 64…1111, y 248…1296 |
| `slice.bottom.light` | 1.01 | x 64…1112, y 792…1888 |

So the slices are 1:1 crops, and their union is a canvas of **1047 × 1639 px**, inset
~64 px from each side and running from y 248 to 1888. On a 393 × 852 pt screen that is
x 21…370 pt, y 83…629 pt — the bounding box of the Home Screen's 3 × 2 widget grid
(three rows of widgets plus their gaps). `top` and `bottom` overlap by 518 px, verified
directly: `top[544:]` against `bottom[0:518]` matches to ~6 grey levels.

Nothing else is stored: no per-slot images, no rendered widget pictures. So the widget
cuts its own piece out of this canvas at display time.

## 3. Per-slot darkness, not just transparency

The App Group preferences carry a table per wallpaper:

```
WallpaperCenter.<uuid>.sectionsIsDark = {
  "<uuid>.small.light.topLeft": "true", "<uuid>.small.light.topRight": "true",
  "<uuid>.small.light.middleLeft": …, "<uuid>.small.light.bottomRight": …,
  "<uuid>.medium.light.top": …, "<uuid>.medium.light.middle": …,
  "<uuid>.large.light.bottom": …,                       (and the same for .dark)
}
```

The slot names spell out the layout the app supports: **6 small** (3 rows × 2 columns),
**3 medium** (rows), **2 large** (top half, bottom half), in light and dark variants.
`true` means that part of the wallpaper is dark, so the words on it have to be white.
That is a precomputed version of what this app now measures per piece at cut time
(`SeeThroughMaker.isDark`, `TextTone.auto`) — and the reason MD Blank can skip the
screenshot: it knows every slot's piece in advance.

## 4. Widget settings

`DataModel.sqlite`, table `ZWIDGETSETTINGSMODEL`, stores one JSON blob per widget:
`type` (`Widget.Text`, `Widget.Greetings`, `Widget.ClimateCrisis`, `Widget.Zen`),
`family` (1 = small, 2 = medium), and `settings` with `bgType` (1 and 4 observed),
`CustomBackground.userChangedBackground`, `CustomBackground.colorDisplayType`,
`CustomBackground.customGradient`, `CustomBackground.BlurEffect`. `bgType` selects the
background style; the values seen with `colorDisplayType` 4/5 and a `#9AC3E9_#BDCDED`
gradient point at color/gradient/photo styles. No key mentions transparency, a slot or a
private API.

## 5. Photos are a separate system

`WidgetPhoto` is the built-in photo library for photo widgets, not the see-through
mechanism: 96 `.resource` sidecars like

```json
{"builtin":102,"id":"BuiltIn.102","family":null,"remove.bg":false,
 "s.crop":"{{0, 0}, {0, 0}}", "m.crop":"…", "l.crop":"…", "album.crop":"…"}
```

with an image per widget size (`small` 474 × 474, `medium` 1014 × 474, `large`,
`xlargePortrait`, `album`) and precomputed crop rectangles. `remove.bg` is the
background-removal flag for cut-out subjects. `WallpaperPhoto` (the user's own
wallpapers) is empty in this dump.

## What this app does with that

- `WidgetSimple/Wallpapers/` ships the five wallpapers as the two slices, because the
  slices are the only clean pixels and the previews are screenshots of the app's UI.
- `WallpaperCatalog` stacks them back into the 1047 × 1639 canvas, scales it to fill the
  screen and saves exactly those pixels as the wallpaper the user sets in Settings.
- The widget still needs to know which piece is behind it, and WidgetKit only reports the
  widget's *size*, never its slot. So step 2 (the pink screenshot) stays: it finds each
  widget's frame on screen once, and the app cuts the piece from the same pixels the user
  set as wallpaper.
- `SeeThroughMaker.isDark` replaces the `sectionsIsDark` table: instead of a per-slot,
  per-wallpaper asset, the darkness of each cut piece is measured, so it works with any
  wallpaper, any widget position and any number of widgets.

## Reproducing the numbers

```python
# register a slice against the screen preview
P = preview.resize((W//8, H//8)); S = slice.resize((w//8, h//8))
for s in arange(0.95, 1.35, 0.01):
    T = S.resize((w*s, h*s))
    win = sliding_window_view(P, T.shape)      # every offset
    mae = abs(win - T).mean(axis=(2,3))        # mask rows outside 10%–84% first
```

The offset that minimises `mae` is the slice's position in the screenshot; the table in
section 2 lists the results, and `bottom`'s offset (544 px) is `bottomOffset` in
`WallpaperCatalog`.
