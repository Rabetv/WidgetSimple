# Release flavours and who owns what

Two builds come out of this one repository. They differ in three things: the private
API, the name under the icon, and how the subscription is sold.

| | **hook** (AltStore / TestFlight) | **appstore** (App Review) |
|---|---|---|
| Private API | on — `WidgetDescriptorHook.mm` | off — `GCC_PREPROCESSOR_DEFINITIONS=APPSTORE=1` compiles it out |
| Widget container | removed, truly transparent | system glass (public API only) |
| Name under the icon | U+2800, invisible | `WidgetSimple` (`HOME_SCREEN_NAME`) |
| Payment | external checkout + licence key (Lemon Squeezy) | StoreKit 2, sold in-app |
| Distribution | AltStore Classic via a self-hosted source | App Store Connect / TestFlight |

## How to build each one

Actions › **TestFlight** › *Run workflow*, `flavour`:

- `hook` (default) — the build that goes to TestFlight and to AltStore;
- `appstore` — no private API, visible name, external checkout hidden from the paywall.

The `appstore` flavour passes `HOME_SCREEN_NAME=WidgetSimple`,
`GCC_PREPROCESSOR_DEFINITIONS=APPSTORE=1` (Objective-C: compiles the hook out) **and**
`SWIFT_ACTIVE_COMPILATION_CONDITIONS=APPSTORE` (Swift: StoreKit 2 store in
`License.swift`, StoreKit paywall in `PaywallView.swift`). Without the Swift setting
every `#if APPSTORE` in Swift is silently false and the external checkout ships.

`Scripts/audit-appstore.sh <path/to/WidgetSimple.app>` checks the built binaries with
`nm` / `strings` for every hook symbol, selector, class name and log line, for any
Lemon Squeezy trace, for the StoreKit product id and for the visible name. It runs in
the **Build** workflow (`appstore` leg; the `hook` leg is the control that must still
contain the hook) and gates the TestFlight upload of `flavour=appstore` archives.

AltStore IPA (unsigned, for AltServer) is a separate workflow: **Actions › AltStore IPA**.

## Facts to keep straight (for anyone joining this work)

- **This repo does use private API.** `WidgetSimpleWidget/WidgetDescriptorHook.mm`
  swizzles `-[_TtCC9WidgetKit24WidgetExtensionXPCServer14ExportedObject
  getAllCurrentDescriptorsWithCompletion:]` and calls `setTransparent:`,
  `setBackgroundRemovable:`, `setPreferredBackgroundStyle:`. That is what removes the
  widget's glass container, and it is what the `APPSTORE` guard excludes.
- **`NoEdgesView.swift` and `WallpaperComposer.swift` do not exist here.** They belong to
  a different project; nothing in this repository draws or hides widget edges by hand.
  The rim work lives in `WidgetDescriptorHook.mm` and `WidgetSimpleWidget.swift`.
- The default `HOME_SCREEN_NAME` is U+2800 (invisible) — good for the AltStore build,
  a guideline 2.3.8 risk for App Review, hence the override in the `appstore` flavour.

## Branch discipline

- Work on a feature branch, open a pull request, merge only when the checks pass.
- `main` is never force-pushed, and never merged while red.
- Two people/agents in parallel: the transparency and AltStore work touch
  `WidgetSimpleWidget/`, `Shared/LauncherFace.swift`, `altstore/`, `dist` assets; the
  App Store release work touches `WidgetSimple/License.swift`, `PaywallView.swift`,
  App Store Connect metadata. Overlap only at `PaywallView.swift` — coordinate there.

## CI note

GitHub-hosted minutes must be available. On this private repository the Build and
TestFlight runs fail before starting ("recent account payments have failed or your
spending limit needs to be increased"). Two working options:

1. fix billing in *Settings › Billing & plans*, or
2. flip the repository public for the duration of the run (free minutes), as the
   AltStore and TestFlight builds in this repo's history were made.
