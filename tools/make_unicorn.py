# Erzeugt Media/Unicorn.tga: goldenes Einhorn auf dunkelblauer Scheibe, ohne Rand (64x64, Alpha)
# Scheibenfarbe wie der Minimap-Knopf von Polestar (Schema "Dusk", panel = 0.11/0.133/0.203 -> #1C2234)
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import sys
S = 1024; N = 64
NAVY = (28, 34, 52, 255)            # #1C2234
NAVY_HI = (40, 49, 76, 255)         # leicht hellere Mitte fuer Tiefe
GOLD_TOP = (255, 238, 176)          # Lichtkante
GOLD_MID = (230, 186, 102)          # #E6BA66 (Polestar-Gold)
GOLD_LOW = (168, 118, 46)           # Schattenseite
GOLD_DARK = (110, 72, 22, 255)      # Linien, Auge
def P(pts): return [(x * S / 100, y * S / 100) for x, y in pts]
def box(a, b): return P([a, b])[0] + P([a, b])[1]

# Scheibe mit sanftem Verlauf zur Mitte
disc = Image.new("RGBA", (S, S), (0, 0, 0, 0))
dd = ImageDraw.Draw(disc)
dd.ellipse((8, 8, S - 8, S - 8), fill=NAVY)
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((S * 0.18, S * 0.12, S * 0.82, S * 0.76), fill=NAVY_HI)
glow = glow.filter(ImageFilter.GaussianBlur(S * 0.12))
disc = Image.alpha_composite(disc, glow)

# Silhouette des Einhorns (Blick nach links)
sil = Image.new("L", (S, S), 0)
d = ImageDraw.Draw(sil)
d.polygon(P([(70, 86), (64, 64), (58, 52), (50, 44), (40, 40), (30, 42), (21, 48), (16, 55),
             (17, 61), (23, 64), (31, 62), (38, 60), (42, 64), (44, 74), (46, 86)]), fill=255)
d.ellipse(box((14, 50), (28, 66)), fill=255)                        # Maul
d.polygon(P([(52, 44), (57, 27), (61, 45)]), fill=255)               # Ohr
d.polygon(P([(43, 41), (33, 13), (50, 39)]), fill=255)               # Horn
d.polygon(P([(58, 44), (70, 40), (80, 48), (76, 52), (84, 60), (77, 63), (85, 72),
             (76, 74), (80, 84), (70, 86), (64, 64)]), fill=255)      # Maehne

# Gold: senkrechter Verlauf hell -> satt -> dunkel, dazu ein schraeger Glanz
grad = Image.new("RGB", (S, S))
gp = grad.load()
for y in range(S):
    t = y / S
    if t < 0.45:
        k = t / 0.45; c0, c1 = GOLD_TOP, GOLD_MID
    else:
        k = (t - 0.45) / 0.55; c0, c1 = GOLD_MID, GOLD_LOW
    col = tuple(int(c0[i] + (c1[i] - c0[i]) * k) for i in range(3))
    for x in range(S):
        gp[x, y] = col
shine = Image.new("L", (S, S), 0)
ImageDraw.Draw(shine).polygon(P([(10, 30), (40, 8), (52, 14), (18, 46)]), fill=90)
shine = shine.filter(ImageFilter.GaussianBlur(S * 0.03))
grad = Image.composite(Image.new("RGB", (S, S), (255, 250, 225)), grad, shine)
gold = grad.convert("RGBA")
gold.putalpha(sil)

# weicher Schatten unter dem Einhorn (Tiefe, wirkt wie Praegung)
shadow = Image.new("RGBA", (S, S), (6, 8, 16, 0))
shadow.putalpha(ImageChops.offset(sil, int(S * 0.012), int(S * 0.02)).filter(ImageFilter.GaussianBlur(S * 0.015)).point(lambda v: int(v * 0.75)))
img = Image.alpha_composite(disc, shadow)
img = Image.alpha_composite(img, gold)

# Praegung: helle Kante oben links, dunkle Kante unten rechts
o = int(S * 0.008)
hi = ImageChops.subtract(sil, ImageChops.offset(sil, o, o)).filter(ImageFilter.GaussianBlur(1.5))
lo = ImageChops.subtract(sil, ImageChops.offset(sil, -o, -o)).filter(ImageFilter.GaussianBlur(1.5))
img = Image.composite(Image.new("RGBA", (S, S), (255, 248, 214, 255)), img, hi.point(lambda v: int(v * 0.85)))
img = Image.composite(Image.new("RGBA", (S, S), (120, 80, 26, 255)), img, lo.point(lambda v: int(v * 0.7)))

# Feine dunkle Goldlinien: Horn-Rillen, Maehne, Auge, Nuester
d = ImageDraw.Draw(img)
for t in (0.35, 0.55, 0.75):
    x1, y1 = 43 + (33 - 43) * t, 41 + (13 - 41) * t
    x2, y2 = 50 + (33 - 50) * t, 39 + (13 - 39) * t
    d.line(P([(x1, y1), (x2, y2)]), fill=GOLD_DARK, width=int(S * 0.012))
for a, b in (((66, 47), (75, 56)), ((67, 58), (77, 68)), ((68, 69), (75, 79))):
    d.line(P([a, b]), fill=GOLD_DARK, width=int(S * 0.014))
d.ellipse(box((35, 46), (39.5, 50.5)), fill=NAVY)
d.ellipse(box((18.5, 54), (21.5, 57)), fill=GOLD_DARK)

# alles ausserhalb der Scheibe abschneiden
mask = Image.new("L", (S, S), 0); ImageDraw.Draw(mask).ellipse((8, 8, S - 8, S - 8), fill=255)
img.putalpha(ImageChops.multiply(img.getchannel("A"), mask))
small = img.resize((N, N), Image.LANCZOS)
out = sys.argv[1] if len(sys.argv) > 1 else "Media/Unicorn.tga"
small.save(out)
img.resize((256, 256), Image.LANCZOS).save("/tmp/unicorn_preview.png")
