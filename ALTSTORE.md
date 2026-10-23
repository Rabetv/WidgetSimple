# Shipping WidgetSimple with AltStore

Classic AltStore (AltServer sideloading) has **no App Review**, so the private
descriptor API that makes the widget transparent is fine there. What it does not give
you is App Store payments — a sideloaded app cannot use StoreKit — so the €1/year
licence is sold on the web and validated with a key.

## 1. Build the IPA

Run **Actions › AltStore IPA › Run workflow** (or push a `v*` tag) and download the
`WidgetSimple-ipa` artifact. The IPA is unsigned on purpose: AltStore signs it with
your Apple ID at install time.

On a Mac you can do the same with `Scripts/build-ipa.sh`.

## 2. Host it publicly

AltStore fetches the IPA and the source over HTTPS, so both must be public. Either:

- use a **public** repo, e.g. `WidgetSimple-dist`, and put releases there, or
- make this repo public (the code and the private-API hook become visible).

Create a release with `v1.0`, upload `WidgetSimple.ipa`, and note:

- the download URL, e.g.
  `https://github.com/<you>/WidgetSimple-dist/releases/download/v1.0/WidgetSimple.ipa`
- the file size in bytes (`stat -f%z WidgetSimple.ipa`)

Put both into `altstore/source.json` (`downloadURL`, `size`), plus `iconURL` /
`headerURL` pointing at a 1024×1024 icon (you can reuse
`WidgetSimple/Assets.xcassets/AppIcon.appiconset/AppIcon.png`) and an optional header.
Add screenshots to `screenshots` if you want them shown (URLs to PNGs).

## 3. Add the source in AltStore

1. Install **AltServer** on Windows/Mac from altstore.io and run it (menu-bar icon).
2. Plug the iPhone in, trust the computer, and choose *Install AltStore* → your device →
   your Apple ID in AltServer.
3. On the iPhone: Settings › General › VPN & Device Management → trust your developer
   certificate. Then Settings › Privacy & Security › Developer Mode → on (iOS 16+).
4. In AltStore: *Sources* › **+** → paste the raw URL of `altstore/source.json`, e.g.
   `https://raw.githubusercontent.com/<you>/WidgetSimple-dist/main/altstore/source.json`
5. Install **WidgetSimple** from that source, then add the widget from the Home Screen.

Signing limits with a **free Apple ID**: 7-day expiry, 3 apps at a time, 10 App IDs per
week; AltServer refreshes over the same Wi-Fi. A paid developer account signs for a year.

## 4. Set up the €1/year licence

The app validates a key against **Lemon Squeezy**'s licence API (form-encoded POST to
`https://api.lemonsqueezy.com/v1/licenses/activate` and `/validate`).

1. Create a Lemon Squeezy store and a **subscription** product, €1 per year.
2. In the product, enable **license keys** (Generate license keys).
3. Copy the product's checkout URL and product id into `WidgetSimple/License.swift`:

```swift
static let checkoutURL = URL(string: "https://<store>.lemonsqueezy.com/buy/<id>")!
static let manageURL = URL(string: "https://<store>.lemonsqueezy.com/billing")!
static let productID = <id>      // optional
static let priceLine = "€1 per year"
```

4. Rebuild the IPA. The paywall then shows the price, the checkout button, a field for
   the key, and *Manage subscription* links to the customer portal.

Notes:

- A validated key is kept in the Keychain and trusted for **7 days offline**; after that
  the app needs the network once to re-validate.
- **Security:** any client-side check can be patched out of a sideloaded binary. Key
  validation against the store (with per-device instance limits) is the practical level
  without running your own server. If you want real enforcement, add a tiny backend that
  proxies the validation and signs a short-lived token.
- Widgets keep working when the app is locked; the paywall only unlocks the editor.

## 5. Why not AltStore PAL

**AltStore PAL** (the EU alternative marketplace) requires Apple **notarization** and a
marketplace review. A binary using private API will be rejected there — this route is
only for classic AltServer sideloading.
