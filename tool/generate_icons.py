#!/usr/bin/env python3
"""
Worm uygulaması için açık renkli modern uygulama ikonu (ic_launcher),
Android Adaptive Icon (ic_launcher_foreground) ve bildirim ikonu (ic_stat_worm) üretir.
"""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android" / "app" / "src" / "main" / "res"

MIPMAP_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

ADAPTIVE_FG_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

NOTIF_SIZES = {
    "drawable-mdpi": 24,
    "drawable-hdpi": 36,
    "drawable-xhdpi": 48,
    "drawable-xxhdpi": 72,
    "drawable-xxxhdpi": 96,
}


def draw_worm_glyph(
    draw: ImageDraw.ImageDraw,
    size: int,
    *,
    stroke_color: tuple[int, int, int, int],
    dot_color: tuple[int, int, int, int],
    scale: float = 1.0,
) -> None:
    """Kart içinde 'W' formunda yumuşak kıvrımlı minimalist kitap kurdu glifi çizer."""
    cx, cy = size / 2, size / 2
    s = size * scale

    # 'W' formunda akıcı 5 nokta
    pts = [
        (cx - 0.25 * s, cy - 0.09 * s),
        (cx - 0.125 * s, cy + 0.13 * s),
        (cx, cy - 0.05 * s),
        (cx + 0.125 * s, cy + 0.13 * s),
        (cx + 0.25 * s, cy - 0.11 * s),
    ]

    width = max(2, int(0.085 * s))
    # Catmull-Rom benzeri yumuşak interpolasyon noktaları
    smooth_pts: list[tuple[float, float]] = []
    steps = 18
    extended = [pts[0]] + pts + [pts[-1]]
    for i in range(1, len(extended) - 2):
        p0, p1, p2, p3 = extended[i - 1], extended[i], extended[i + 1], extended[i + 2]
        for step in range(steps):
            t = step / steps
            t2 = t * t
            t3 = t2 * t
            x = 0.5 * (
                (2 * p1[0])
                + (-p0[0] + p2[0]) * t
                + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3
            )
            y = 0.5 * (
                (2 * p1[1])
                + (-p0[1] + p2[1]) * t
                + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3
            )
            smooth_pts.append((x, y))
    smooth_pts.append(pts[-1])

    for i in range(len(smooth_pts) - 1):
        draw.line([smooth_pts[i], smooth_pts[i + 1]], fill=stroke_color, width=width)
    r = width / 2
    for px, py in smooth_pts:
        draw.ellipse([px - r, py - r, px + r, py + r], fill=stroke_color)

    # Sağ üst uçta minik parlak nokta (kitap kurdu başı / vurgu)
    hx, hy = pts[-1][0], pts[-1][1] - 0.11 * s
    hr = max(2, int(0.052 * s))
    draw.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=dot_color)


def create_launcher_master(size: int = 1024, include_bg: bool = True) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if include_bg:
        # Açık lavanta/buz mavisi yumuşak dikey gradyan
        top = (244, 247, 255)
        bottom = (224, 232, 255)
        for y in range(size):
            t = y / (size - 1)
            r = int(top[0] + (bottom[0] - top[0]) * t)
            g = int(top[1] + (bottom[1] - top[1]) * t)
            b = int(top[2] + (bottom[2] - top[2]) * t)
            draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # Merkez beyaz kelime kartı + yumuşak gölge
    card_margin = int(size * (0.19 if include_bg else 0.24))
    card_rect = [card_margin, card_margin, size - card_margin, size - card_margin]
    card_radius = int(size * 0.14)

    shadow_offset = int(size * 0.022)
    shadow_rect = [
        card_rect[0],
        card_rect[1] + shadow_offset,
        card_rect[2],
        card_rect[3] + shadow_offset,
    ]
    draw.rounded_rectangle(
        shadow_rect,
        radius=card_radius,
        fill=(99, 102, 241, 28),
    )

    draw.rounded_rectangle(
        card_rect,
        radius=card_radius,
        fill=(255, 255, 255, 255),
        outline=(210, 220, 255, 255),
        width=max(2, int(size * 0.01)),
    )

    # Üstte ince pastel dekoratif çizgi (kart başlığı hissi)
    bar_w = int(size * 0.16)
    bar_h = max(3, int(size * 0.022))
    bar_x0 = (size - bar_w) // 2
    bar_y0 = card_rect[1] + int(size * 0.065)
    draw.rounded_rectangle(
        [bar_x0, bar_y0, bar_x0 + bar_w, bar_y0 + bar_h],
        radius=bar_h // 2,
        fill=(218, 226, 255, 255),
    )

    # Merkez 'W' / worm glifi
    draw_worm_glyph(
        draw,
        size,
        stroke_color=(99, 102, 241, 255),  # Canlı ama yumuşak indigo
        dot_color=(52, 211, 153, 255),  # Ferah mint yeşili
        scale=0.68 if include_bg else 0.56,
    )

    return img


def create_notification_master(size: int = 512) -> Image.Image:
    """Android bildirim çubuğu için şeffaf arka planlı saf beyaz silüet."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Yuvarlak hatlı kart çerçevesi
    m = int(size * 0.14)
    r = int(size * 0.16)
    stroke_w = max(4, int(size * 0.075))
    draw.rounded_rectangle(
        [m, m, size - m, size - m],
        radius=r,
        outline=(255, 255, 255, 255),
        width=stroke_w,
    )

    draw_worm_glyph(
        draw,
        size,
        stroke_color=(255, 255, 255, 255),
        dot_color=(255, 255, 255, 255),
        scale=0.62,
    )
    return img


def main() -> None:
    master_launcher = create_launcher_master(1024, include_bg=True)
    master_fg = create_launcher_master(1024, include_bg=False)
    master_notif = create_notification_master(512)

    # Assets içine önizleme/yedek olarak da kaydet
    preview_path = ROOT / "assets" / "icon_preview.png"
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    master_launcher.save(preview_path)

    for folder, px in MIPMAP_SIZES.items():
        out_dir = RES / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        resized = master_launcher.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(out_dir / "ic_launcher.png")

    for folder, px in ADAPTIVE_FG_SIZES.items():
        out_dir = RES / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        resized = master_fg.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(out_dir / "ic_launcher_foreground.png")

    for folder, px in NOTIF_SIZES.items():
        out_dir = RES / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        resized = master_notif.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(out_dir / "ic_stat_worm.png")

    # Adaptive icon XML ve açık arka plan rengi
    anydpi_dir = RES / "mipmap-anydpi-v26"
    anydpi_dir.mkdir(parents=True, exist_ok=True)
    (anydpi_dir / "ic_launcher.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
""",
        encoding="utf-8",
    )

    values_dir = RES / "values"
    values_dir.mkdir(parents=True, exist_ok=True)
    (values_dir / "colors.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#EEF2FF</color>
</resources>
""",
        encoding="utf-8",
    )

    print("Uygulama ikonları ve bildirim ikonları başarıyla oluşturuldu.")


if __name__ == "__main__":
    main()
