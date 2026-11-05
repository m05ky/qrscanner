# QR Scanner for iPhone (SwiftUI)

iPhone version of the Android app: fast button-less continuous scanner, picture of the scanned frame (code outlined)
plus a crop of the code for every scan, gallery scan, create every QR / barcode type, history with favorites,
My QR, side menu with edge swipe, accent colors, light / dark, English and German.

* iOS 16 or newer, iPhone only, SwiftUI, no entitlements (works with a free Apple ID through SideStore)
* Scanning: AVFoundation (instant detection) + Vision (frame outline, Codabar, picked images) + ZXing-cpp (fallback)
* Creating: ZXing-cpp renders all 13 formats (QR, EAN-8/13, UPC-A/E, Code 39/93/128, ITF, PDF417, Codabar, Data Matrix, Aztec)
* Everything stays on the device; the internet is only used if "URL information" is switched on

## Getting an installable .ipa (no Mac needed)

The .ipa is built by GitHub Actions on a macOS machine, unsigned. SideStore signs it when you install it
and re-signs it automatically before the 7 days run out.

1. Create a new (private or public) repository on GitHub and upload the contents of this folder to it
   (the `.github` folder must be included; on the web: *Add file > Upload files*, drag everything in).
2. Open the **Actions** tab, pick **Build IPA** and press **Run workflow** (it also runs on every push).
3. After about 5 to 10 minutes open the finished run and download the artifact **QRScanner-ipa**
   (a zip that contains `QRScanner.ipa`). Unzip it.
4. Get `QRScanner.ipa` onto the iPhone (AirDrop, Files, cloud storage), open SideStore, tap **+** and choose the file.
5. Updating: upload new code, run the workflow again, install the new .ipa over the old one. History and settings are kept.

If the build fails, open the run, download the artifact **build-log** (or copy the red error lines from the
*Build* step) and send it over. The first build of a new code base often needs one or two small fixes.

## Project layout

```
project.yml                 XcodeGen description (the .xcodeproj is generated on CI, not stored)
.github/workflows/          Build IPA workflow
QRScanner/
  App/                      app entry, navigation state, handling of a decoded code
  Data/                     settings (UserDefaults), history (JSON file), scan pictures (JPEG)
  Model/                    formats, content parser (Wi-Fi, vCard, event, ...), payload builders
  Scan/                     camera session, image scanning, frame/code capture
  Gen/                      code generator (ZXing-cpp)
  Util/                     actions (share, contacts, calendar, maps, ...), localization, export
  UI/                       SwiftUI screens
  Resources/                Inter fonts, en/de strings, asset catalog (app icon, code preview tiles)
tools/make_resources.py     regenerates strings and assets from the Android project
```

## Differences from the Android app

* **Wi-Fi "Connect"**: iOS only lets apps join a network with a special entitlement that sideloaded apps cannot have.
  The button copies the password and opens Settings instead.
* **Camera choice** is not offered (iOS picks the best back camera itself).
* **Search engine**: no "device default"; Google is the default and the others are selectable.
* **Menu**: swipe in from the left edge of the screen or tap the menu button.

## Licenses

Inter font: SIL Open Font License (`tools/Inter-LICENSE.txt`). ZXing-cpp: Apache-2.0 (fetched by Swift Package Manager).
