#!/usr/bin/env python3
"""
Worm uygulaması için Duolingo tarzı sade, sevimli ve açık renkli
"solucanı (worm) patisiyle yakalayan kedi" uygulama ikonu ve bildirim ikonu üretir.
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


def draw_smooth_curve(
    draw: ImageDraw.ImageDraw,
    pts: list[tuple[float, float]],
    width: int,
    color: tuple[int, int, int, int],
) -> None:
    smooth_pts: list[tuple[float, float]] = []
    steps = 20
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
        draw.line([smooth_pts[i], smooth_pts[i + 1]], fill=color, width=width)
    r = width / 2
    for px, py in smooth_pts:
        draw.ellipse([px - r, py - r, px + r, py + r], fill=color)


def draw_cat_and_worm(
    draw: ImageDraw.ImageDraw,
    size: int,
    *,
    scale: float = 1.0,
) -> None:
    s = size * scale
    ox = (size - s) / 2
    oy = (size - s) / 2

    def pt(nx: float, ny: float) -> tuple[float, float]:
        return (ox + nx * s, oy + ny * s)

    cat_main = (255, 178, 107, 255)      # Sıcak pastel şeftali/turuncu
    cat_dark = (240, 146, 72, 255)       # Hafif gölge turuncu
    cat_cream = (255, 243, 226, 255)     # Krem yanak/pati
    ear_pink = (255, 152, 172, 255)      # Tatlı pembe kulak içi & burun
    eye_dark = (43, 39, 71, 255)         # Koyu indigo göz bebeği
    white = (255, 255, 255, 255)
    worm_green = (45, 212, 149, 255)     # Canlı mint yeşili solucan
    worm_light = (110, 231, 183, 255)    # Solucan parlama

    # 1. Kedi kulakları (doğal üçgen)
    left_ear = [pt(0.18, 0.42), pt(0.20, 0.16), pt(0.39, 0.29)]
    right_ear = [pt(0.64, 0.42), pt(0.62, 0.16), pt(0.43, 0.29)]
    draw.polygon(left_ear, fill=cat_main)
    draw.polygon(right_ear, fill=cat_main)

    # Kulak içi pembe
    draw.polygon([pt(0.215, 0.37), pt(0.23, 0.22), pt(0.35, 0.30)], fill=ear_pink)
    draw.polygon([pt(0.605, 0.37), pt(0.59, 0.22), pt(0.47, 0.30)], fill=ear_pink)

    # 2. Kedi gövdesi (alt kısım)
    body_box = [pt(0.22, 0.56)[0], pt(0.56)[1] if False else oy + 0.56 * s, ox + 0.60 * s, oy + 0.92 * s]
    draw.rounded_rectangle(body_box, radius=int(0.16 * s), fill=cat_dark)

    # Göbek krem lekesi
    belly_box = [ox + 0.30 * s, oy + 0.64 * s, ox + 0.52 * s, oy + 0.90 * s]
    draw.ellipse(belly_box, fill=cat_cream)

    # 3. Kedi kafası (yuvarlak sevimli form)
    head_box = [ox + 0.15 * s, oy + 0.25 * s, ox + 0.67 * s, oy + 0.72 * s]
    draw.ellipse(head_box, fill=cat_main)

    # Yanak / ağız krem alanı
    muzzle_l = [ox + 0.29 * s, oy + 0.49 * s, ox + 0.42 * s, oy + 0.62 * s]
    muzzle_r = [ox + 0.40 * s, oy + 0.49 * s, ox + 0.53 * s, oy + 0.62 * s]
    draw.ellipse(muzzle_l, fill=cat_cream)
    draw.ellipse(muzzle_r, fill=cat_cream)

    # 4. Büyük Duolingo tarzı gözler (sağa, solucana doğru bakıyor)
    for cx_n in (0.31, 0.51):
        gx, gy = pt(cx_n, 0.44)
        ew, eh = 0.072 * s, 0.082 * s
        draw.ellipse([gx - ew, gy - eh, gx + ew, gy + eh], fill=white)
        # Göz bebeği sağa/hafif yukarı (solucana odaklanmış)
        px, py = gx + 0.018 * s, gy - 0.004 * s
        pw, ph = 0.044 * s, 0.052 * s
        draw.ellipse([px - pw, py - ph, px + pw, py + ph], fill=eye_dark)
        # Parıltı noktası
        sx, sy = px - 0.015 * s, py - 0.018 * s
        sr = 0.015 * s
        draw.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=white)

    # 5. Minik pembe burun + tatlı gülümseme + bıyıklar
    nx, ny = pt(0.41, 0.525)
    draw.polygon(
        [
            (nx - 0.028 * s, ny - 0.014 * s),
            (nx + 0.028 * s, ny - 0.014 * s),
            (nx, ny + 0.020 * s),
        ],
        fill=ear_pink,
    )
    draw.arc(
        [ox + 0.35 * s, oy + 0.52 * s, ox + 0.41 * s, oy + 0.58 * s],
        start=15,
        end=165,
        fill=eye_dark,
        width=max(2, int(0.012 * s)),
    )
    draw.arc(
        [ox + 0.41 * s, oy + 0.52 * s, ox + 0.47 * s, oy + 0.58 * s],
        start=15,
        end=165,
        fill=eye_dark,
        width=max(2, int(0.012 * s)),
    )

    # Bıyıklar (sol taraf + sağ taraf kısa ve üstte)
    w_width = max(2, int(0.008 * s))
    draw.line([pt(0.12, 0.48), pt(0.23, 0.50)], fill=cat_dark, width=w_width)
    draw.line([pt(0.11, 0.54), pt(0.23, 0.54)], fill=cat_dark, width=w_width)
    draw.line([pt(0.58, 0.49), pt(0.66, 0.47)], fill=cat_dark, width=w_width)
    draw.line([pt(0.59, 0.53), pt(0.66, 0.53)], fill=cat_dark, width=w_width)

    # 6. Solucan (Worm) — sağ üstte kıvrılan sevimli mint yeşili solucan
    worm_pts = [
        pt(0.84, 0.25),
        pt(0.78, 0.35),
        pt(0.85, 0.44),
        pt(0.76, 0.54),
        pt(0.68, 0.57),
    ]
    draw_smooth_curve(draw, worm_pts, width=max(4, int(0.082 * s)), color=worm_green)

    # Solucan kafasında hafif parlaklık & sevimli gözler
    whx, why = pt(0.84, 0.24)
    whr = 0.048 * s
    draw.ellipse([whx - whr, why - whr, whx + whr, why + whr], fill=worm_light)
    w_eye_r = 0.012 * s
    for ex_off in (-0.019 * s, 0.019 * s):
        ex = whx + ex_off
        ey = why - 0.006 * s
        draw.ellipse([ex - w_eye_r, ey - w_eye_r, ex + w_eye_r, ey + w_eye_r], fill=eye_dark)
        sr = 0.004 * s
        draw.ellipse([ex - sr, ey - sr, ex + sr, ey + sr], fill=white)

    # 7. Kedinin sağ ön patisi — solucanı nazikçe yakalıyor!
    paw_pts = [pt(0.54, 0.69), pt(0.65, 0.62), pt(0.73, 0.54)]
    draw_smooth_curve(draw, paw_pts, width=max(4, int(0.095 * s)), color=cat_main)
    px, py = pt(0.735, 0.535)
    pr = 0.048 * s
    draw.ellipse([px - pr, py - pr, px + pr, py + pr], fill=cat_cream)
    draw.line([pt(0.725, 0.505), pt(0.75, 0.52)], fill=cat_dark, width=w_width)
    draw.line([pt(0.745, 0.53), pt(0.77, 0.545)], fill=cat_dark, width=w_width)


def create_launcher_master(size: int = 1024, include_bg: bool = True) -> Image.Image:
    # 2x supersampling ile jilet gibi yumuşak kenarlar
    work_size = size * 2
    img = Image.new("RGBA", (work_size, work_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if include_bg:
        top = (244, 247, 255)
        bottom = (222, 232, 255)
        for y in range(work_size):
            t = y / (work_size - 1)
            r = int(top[0] + (bottom[0] - top[0]) * t)
            g = int(top[1] + (bottom[1] - top[1]) * t)
            b = int(top[2] + (bottom[2] - top[2]) * t)
            draw.line([(0, y), (work_size, y)], fill=(r, g, b, 255))

        # Yumuşak beyaz daire arka vurgu
        pad = int(work_size * 0.11)
        draw.ellipse(
            [pad, pad, work_size - pad, work_size - pad],
            fill=(255, 255, 255, 190),
        )

    draw_cat_and_worm(draw, work_size, scale=0.82 if include_bg else 0.66)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def create_notification_master(size: int = 512) -> Image.Image:
    """Bildirim çubuğu için şeffaf arka planlı sade beyaz kedi + solucan silüeti."""
    work_size = size * 2
    img = Image.new("RGBA", (work_size, work_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    white = (255, 255, 255, 255)
    clear = (0, 0, 0, 0)

    s = work_size * 0.84
    ox = (work_size - s) / 2
    oy = (work_size - s) / 2

    def pt(nx: float, ny: float) -> tuple[float, float]:
        return (ox + nx * s, oy + ny * s)

    # Kedi kulakları ve kafa silüeti
    draw.polygon([pt(0.18, 0.44), pt(0.20, 0.16), pt(0.39, 0.30)], fill=white)
    draw.polygon([pt(0.64, 0.44), pt(0.62, 0.16), pt(0.43, 0.30)], fill=white)
    draw.ellipse([ox + 0.14 * s, oy + 0.26 * s, ox + 0.68 * s, oy + 0.76 * s], fill=white)

    # Şeffaf kesim gözler (silüet içinde okunur)
    for cx_n in (0.31, 0.51):
        gx, gy = pt(cx_n, 0.47)
        er = 0.055 * s
        draw.ellipse([gx - er, gy - er, gx + er, gy + er], fill=clear)

    # Pati ve solucan silüeti
    draw_smooth_curve(
        draw,
        [pt(0.56, 0.68), pt(0.68, 0.58)],
        width=max(4, int(0.095 * s)),
        color=white,
    )
    draw_smooth_curve(
        draw,
        [pt(0.86, 0.24), pt(0.79, 0.36), pt(0.86, 0.46), pt(0.75, 0.56)],
        width=max(4, int(0.085 * s)),
        color=white,
    )

    return img.resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    master_launcher = create_launcher_master(1024, include_bg=True)
    master_fg = create_launcher_master(1024, include_bg=False)
    master_notif = create_notification_master(512)

    preview_path = ROOT / "assets" / "icon_preview.png"
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    master_launcher.save(preview_path)

    for folder, px in MIPMAP_SIZES.items():
        out_dir = RES / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        master_launcher.resize((px, px), Image.Resampling.LANCZOS).save(
            out_dir / "ic_launcher.png"
        )

    for folder, px in ADAPTIVE_FG_SIZES.items():
        out_dir = RES / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        master_fg.resize((px, px), Image.Resampling.LANCZOS).save(
            out_dir / "ic_launcher_foreground.png"
        )

    for folder, px in NOTIF_SIZES.items():
        out_dir = RES / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        master_notif.resize((px, px), Image.Resampling.LANCZOS).save(
            out_dir / "ic_stat_worm.png"
        )

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

    print("Yeni kedi & solucan uygulama ve bildirim ikonları oluşturuldu.")


if __name__ == "__main__":
    main()
