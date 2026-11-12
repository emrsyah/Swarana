"""Regenerate the app icon and splash images from assets/v5/logo.png.

    python tool/make_icons.py
    dart pub global activate flutter_native_splash && dart pub global run flutter_native_splash:create

Writes:
  assets/v5/icon_fg.png        adaptive foreground (also the Android 12 splash icon)
  assets/v5/splash_logo.png    logo for the pre-Android-12 native splash
  android/.../mipmap-*/        legacy square icon + adaptive foreground per density
  android/.../mipmap-anydpi-v26/ic_launcher.xml
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
ASSETS = ROOT / "assets/v5"
BLUE = (0x1F, 0x4F, 0xFF, 255)  # V5Colors.primary
logo = Image.open(ASSETS / "logo.png").convert("RGBA")


def placed(size, bg, width_frac):
    c = Image.new("RGBA", (size, size), bg)
    w = int(size * width_frac)
    h = round(logo.height * w / logo.width)
    c.alpha_composite(logo.resize((w, h), Image.LANCZOS), ((size - w) // 2, (size - h) // 2))
    return c


# Adaptive icons show only the centre ~66%, so the logo stays well inside it.
placed(1024, (0, 0, 0, 0), 0.50).save(ASSETS / "icon_fg.png")
logo.resize((logo.width * 3, logo.height * 3), Image.LANCZOS).save(ASSETS / "splash_logo.png")

for density, scale in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
    d = RES / f"mipmap-{density}"
    d.mkdir(exist_ok=True)
    placed(round(48 * scale), BLUE, 0.62).save(d / "ic_launcher.png")
    placed(round(108 * scale), (0, 0, 0, 0), 0.50).save(d / "ic_launcher_foreground.png")

anydpi = RES / "mipmap-anydpi-v26"
anydpi.mkdir(exist_ok=True)
(anydpi / "ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    "</adaptive-icon>\n"
)
(RES / "values/ic_launcher_colors.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    "<resources>\n"
    '    <color name="ic_launcher_background">#1F4FFF</color>\n'
    "</resources>\n"
)
print("icons written")
