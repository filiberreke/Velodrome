"""make_euromax_textures.py – EuroMax Cycling logo (same colours/style as the EuroMax Sport reference).
Needs Pillow and Inter ExtraBold Italic (OFL, https://rsms.me/inter). Output: PNG with alpha + a navy panel version.
  python make_euromax_textures.py <out_dir> [font_path]
"""
import sys, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

NAVY = (24, 41, 104)
RED = (214, 30, 45)
YELLOW = (246, 194, 30)
WHITE = (255, 255, 255)
SS = 2  # supersampling

def star(draw, cx, cy, r, fill, rot=-90):
    pts = []
    for i in range(10):
        rr = r if i % 2 == 0 else r * 0.40
        a = math.radians(rot + i * 36)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    draw.polygon(pts, fill=fill)

def italic_text(text, font, fill, shadow=True, skew=0.0):
    """render text on its own layer (font is already italic); returns RGBA image tightly cropped"""
    l, t, r, b = font.getbbox(text)
    w, h = r - l + 40 * SS, b - t + 40 * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if shadow:
        sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((20 * SS - l + 4 * SS, 20 * SS - t + 6 * SS), text, font=font, fill=(5, 10, 35, 150))
        img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(3 * SS)))
        d = ImageDraw.Draw(img)
    d.text((20 * SS - l, 20 * SS - t), text, font=font, fill=fill)
    return img

def build(font_path, W=2048, H=1024):
    W2, H2 = W * SS, H * SS
    img = Image.new("RGBA", (W2, H2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    big = ImageFont.truetype(font_path, int(300 * SS))
    mid = ImageFont.truetype(font_path, int(225 * SS))

    # --- word marks
    euromax = italic_text("EuroMax", big, WHITE)
    cycling = italic_text("Cycling", mid, WHITE, shadow=False)
    ex, ey = int(560 * SS), int(150 * SS)
    # red block under EuroMax, slightly offset to the right like the original
    bx0, by0 = ex + int(95 * SS), ey + euromax.height - int(62 * SS)
    pad_x, pad_y = int(40 * SS), int(10 * SS)
    bw, bh = cycling.width + 2 * pad_x - int(40 * SS), int(250 * SS)
    sk = int(18 * SS)   # small forward lean of the block
    block = [(bx0 + sk, by0), (bx0 + bw + sk, by0), (bx0 + bw, by0 + bh), (bx0, by0 + bh)]
    sh = Image.new("RGBA", (W2, H2), (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon([(x + 6 * SS, y + 8 * SS) for x, y in block], fill=(5, 10, 35, 140))
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(4 * SS)))
    d = ImageDraw.Draw(img)
    d.polygon(block, fill=RED)
    img.alpha_composite(cycling, (bx0 + pad_x - int(20 * SS), by0 + (bh - cycling.height) // 2 + int(4 * SS)))
    img.alpha_composite(euromax, (ex, ey))

    # --- arc of yellow stars on the left (open EU-style ring)
    d = ImageDraw.Draw(img)
    top, bot = ey + int(25 * SS), by0 + bh
    cy = (top + bot) // 2
    R = (bot - top) // 2 + int(95 * SS)
    cx = ex + int(150 * SS)
    for a in [-72, -97, -122, -147, -172, 163, 138, 113]:
        ar = math.radians(a)
        star(d, cx + R * math.cos(ar), cy + R * math.sin(ar), 40 * SS, YELLOW)

    bbox = img.getbbox()
    img = img.crop((bbox[0] - 30 * SS, bbox[1] - 30 * SS, bbox[2] + 30 * SS, bbox[3] + 30 * SS))
    img = img.resize((img.width // SS, img.height // SS), Image.LANCZOS)
    return img

if __name__ == "__main__":
    out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    font = sys.argv[2] if len(sys.argv) > 2 else "/usr/share/fonts/opentype/inter/Inter-ExtraBoldItalic.otf"
    logo = build(font)
    logo.save(out / "euromax_cycling_logo.png")
    # panel texture: logo centred on navy, 2:1
    W, H = 2048, 1024
    panel = Image.new("RGBA", (W, H), NAVY + (255,))
    s = min(W * 0.86 / logo.width, H * 0.86 / logo.height)
    lg = logo.resize((int(logo.width * s), int(logo.height * s)), Image.LANCZOS)
    panel.alpha_composite(lg, ((W - lg.width) // 2, (H - lg.height) // 2))
    panel.convert("RGB").save(out / "euromax_cycling_panel.png")
    print("LOGO", logo.size)


def shirt_print(out, size=512):
    """tileable white shirt fabric with tiny blue and grey bicycles (left presenter)"""
    S = size * SS
    img = Image.new("RGB", (S, S), (247, 247, 244))
    d = ImageDraw.Draw(img)
    BLUE, GREY = (70, 110, 205), (128, 128, 132)
    def bike(cx, cy, s, col, flip):
        f = -1 if flip else 1
        r = 0.32 * s; w = max(2, int(0.07 * s))
        for wx in (-0.55, 0.55):
            d.ellipse([cx + wx * s - r, cy - r, cx + wx * s + r, cy + r], outline=col, width=w)
        p = lambda x, y: (cx + f * x * s, cy + y * s)
        for a, b_ in [((-0.55, 0), (-0.1, 0)), ((-0.1, 0), (0.35, -0.45)), ((-0.55, 0), (-0.25, -0.45)), ((-0.25, -0.45), (0.35, -0.45)),
                      ((0.35, -0.45), (0.55, 0)), ((-0.25, -0.45), (-0.1, 0)), ((-0.32, -0.55), (-0.15, -0.55)), ((0.30, -0.6), (0.42, -0.62))]:
            d.line([p(*a), p(*b_)], fill=col, width=w)
    n = 6; step = S / n
    for gy in range(n):
        for gx in range(n):
            x = (gx + (0.5 if gy % 2 else 0.0) + 0.25) * step
            y = (gy + 0.5) * step
            col = BLUE if (gx + gy) % 2 == 0 else GREY
            for ox in (-S, 0, S):
                bike(x + ox, y, step * 0.30, col, (gx * 3 + gy) % 4 == 1)
    img.resize((size, size), Image.LANCZOS).save(out / "shirt_print_navy_dots.png")

def monitor_screen(out, font_path, W=512, H=320):
    """simple live-timing UI for the commentator monitors (faces the presenters)"""
    img = Image.new("RGB", (W, H), (12, 20, 48))
    d = ImageDraw.Draw(img)
    f1 = ImageFont.truetype(font_path, 26); f2 = ImageFont.truetype(font_path, 21)
    d.rectangle([0, 0, W, 46], fill=NAVY)
    d.rectangle([W - 120, 8, W - 12, 38], fill=RED)
    d.text((W - 108, 9), "LIVE", font=f1, fill=WHITE)
    d.text((14, 9), "EuroMax Cycling", font=f1, fill=WHITE)
    rows = [("1", "BEL", "1:02.481", YELLOW), ("2", "NED", "1:02.913", WHITE), ("3", "GBR", "1:03.207", WHITE),
            ("4", "FRA", "1:03.664", WHITE), ("5", "ITA", "1:04.020", WHITE)]
    for i, (p, n, t, c) in enumerate(rows):
        y = 62 + i * 48
        d.rectangle([12, y, W - 12, y + 40], fill=(26, 40, 86) if i % 2 == 0 else (20, 32, 70))
        d.text((24, y + 8), p, font=f2, fill=c); d.text((70, y + 8), n, font=f2, fill=WHITE)
        d.text((W - 150, y + 8), t, font=f2, fill=c)
    img.save(out / "monitor_live_timing.png")

if __name__ == "__main__":
    shirt_print(out)
    monitor_screen(out, font)
