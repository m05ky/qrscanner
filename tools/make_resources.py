#!/usr/bin/env python3
"""One-off helper that produced the resources of the iOS project from the Android project.

  python3 tools/make_resources.py /path/to/QRScanner-android

* Localizable.strings (en, de) from the Android strings.xml files (same keys, %1$d / %1$@ placeholders)
* Assets.xcassets: AppIcon (1024 px, opaque), AppLogo and the barcode icons of the "Other types" list
"""
import json
import re
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import cv2

SRC = Path(sys.argv[1])
HERE = Path(__file__).resolve().parent.parent
RES = HERE / "QRScanner" / "Resources"

IOS_OVERRIDES = {
    "en": {
        "wifi_failed": "Could not join the network automatically. The password was copied; open Settings > Wi-Fi to join.",
        "set_camera": "Camera",
    },
    "de": {
        "wifi_failed": "Das Netzwerk konnte nicht automatisch hinzugefügt werden. Das Passwort wurde kopiert; öffne Einstellungen > WLAN.",
        "set_camera": "Kamera",
    },
}


def android_value(text: str) -> str:
    t = text or ""
    t = t.replace("\\'", "'").replace('\\"', '"').replace("\\@", "@").replace("\\?", "?")
    t = t.replace("\\n", "\n")
    t = re.sub(r"%(\d+)\$s", r"%\1$@", t)
    return t


def esc(t: str) -> str:
    return t.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def convert(lang: str, xml_path: Path, base_keys=None):
    root = ET.parse(xml_path).getroot()
    out = {}
    for el in root.findall("string"):
        out[el.get("name")] = android_value(el.text)
    out.update(IOS_OVERRIDES[lang])
    if lang == "de" and base_keys:
        for k in base_keys:
            out.setdefault(k, None)
    return out


en = convert("en", SRC / "app/src/main/res/values/strings.xml")
de = convert("de", SRC / "app/src/main/res/values-de/strings.xml")
for k, v in en.items():
    if k not in de or de[k] is None:
        de[k] = v
for lang, data in (("en", en), ("de", de)):
    d = RES / f"{lang}.lproj"
    d.mkdir(parents=True, exist_ok=True)
    lines = ['/* Generated from the Android strings. */']
    for k in sorted(data):
        lines.append(f'"{k}" = "{esc(data[k])}";')
    (d / "Localizable.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(lang, len(data), "strings")

info = {
    "en": {
        "NSCameraUsageDescription": "QR Scanner uses the camera to scan QR codes and barcodes.",
        "NSPhotoLibraryAddUsageDescription": "QR Scanner saves generated codes to your photo library when you tap Save.",
        "NSCalendarsUsageDescription": "QR Scanner adds scanned events to your calendar.",
        "NSCalendarsFullAccessUsageDescription": "QR Scanner adds scanned events to your calendar.",
        "NSCalendarsWriteOnlyAccessUsageDescription": "QR Scanner adds scanned events to your calendar.",
    },
    "de": {
        "NSCameraUsageDescription": "QR Scanner verwendet die Kamera, um QR-Codes und Barcodes zu scannen.",
        "NSPhotoLibraryAddUsageDescription": "QR Scanner speichert erstellte Codes in deiner Fotomediathek, wenn du auf Speichern tippst.",
        "NSCalendarsUsageDescription": "QR Scanner fügt gescannte Termine deinem Kalender hinzu.",
        "NSCalendarsFullAccessUsageDescription": "QR Scanner fügt gescannte Termine deinem Kalender hinzu.",
        "NSCalendarsWriteOnlyAccessUsageDescription": "QR Scanner fügt gescannte Termine deinem Kalender hinzu.",
    },
}
for lang, data in info.items():
    lines = [f'"{k}" = "{esc(v)}";' for k, v in data.items()]
    (RES / f"{lang}.lproj" / "InfoPlist.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")

# ---------------------------------------------------------------- asset catalog
XC = RES / "Assets.xcassets"
if XC.exists():
    shutil.rmtree(XC)
XC.mkdir(parents=True)
(XC / "Contents.json").write_text(json.dumps({"info": {"version": 1, "author": "xcode"}}, indent=2))

# App icon: 1024 px, opaque RGB
master = cv2.imread(str(SRC / "tools/app-icon/master.png"), cv2.IMREAD_COLOR)
icon = cv2.resize(master, (1024, 1024), interpolation=cv2.INTER_LANCZOS4)
ai = XC / "AppIcon.appiconset"
ai.mkdir()
cv2.imwrite(str(ai / "icon-1024.png"), icon)
(ai / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
    "info": {"version": 1, "author": "xcode"},
}, indent=2))


def imageset(name: str, src: Path):
    d = XC / f"{name}.imageset"
    d.mkdir()
    shutil.copy(src, d / f"{name}.png")
    (d / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "3x"}],
        "info": {"version": 1, "author": "xcode"},
    }, indent=2))


drawables = SRC / "app/src/main/res/drawable-nodpi"
imageset("AppLogo", drawables / "ic_app_logo.png")
for p in sorted(drawables.glob("code_*.png")):
    imageset(p.stem, p)
print("assets:", sorted(x.name for x in XC.iterdir()))
