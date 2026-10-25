"""Default decal images for the Velodrome 250 rider (replace them with your own PNGs).
Transparent background = no print; the image is stretched over the decal area.
  decal_back_<n>.png  race number on the back (512x512)
  decal_chest.png     logo on the chest (1024x512)
  decal_thigh.png     logo on the side of the thighs (1024x384)
"""
from PIL import Image, ImageDraw, ImageFont
import os
HERE = os.path.dirname(os.path.abspath(__file__))
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

def fit_font(draw, text, w, h):
    size = h
    while size > 8:
        f = ImageFont.truetype(BOLD, size)
        b = draw.textbbox((0, 0), text, font=f)
        if b[2] - b[0] <= w and b[3] - b[1] <= h:
            return f, b
        size -= 4
    return ImageFont.truetype(BOLD, 8), (0, 0, 8, 8)

def centred(draw, box, text, fill, stroke=0, stroke_fill=None):
    x0, y0, x1, y1 = box
    f, b = fit_font(draw, text, x1 - x0 - 2 * stroke, y1 - y0 - 2 * stroke)
    tw, th = b[2] - b[0], b[3] - b[1]
    draw.text(((x0 + x1 - tw) / 2 - b[0], (y0 + y1 - th) / 2 - b[1]), text, font=f, fill=fill,
              stroke_width=stroke, stroke_fill=stroke_fill)

for n in range(1, 5):
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle((40, 70, 472, 442), 36, fill=(250, 250, 248, 255), outline=(20, 24, 32, 255), width=10)
    centred(d, (90, 110, 422, 400), str(n), (15, 18, 26, 255))
    im.save(os.path.join(HERE, f"decal_back_{n}.png"))
im = Image.new("RGBA", (1024, 512), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
centred(d, (40, 120, 984, 330), "VELODROME", (255, 255, 255, 255), 10, (12, 20, 36, 255))
centred(d, (330, 330, 694, 470), "250", (255, 214, 64, 255), 8, (12, 20, 36, 255))
im.save(os.path.join(HERE, "decal_chest.png"))
im = Image.new("RGBA", (1024, 384), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
centred(d, (30, 60, 994, 324), "V250", (255, 255, 255, 255), 12, (12, 20, 36, 255))
im.save(os.path.join(HERE, "decal_thigh.png"))
print("ok")
