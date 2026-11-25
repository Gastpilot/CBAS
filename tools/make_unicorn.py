# Erzeugt Media/Unicorn.tga: weisses Einhorn auf pinkem Kreis, ohne Rand (64x64, Alpha)
from PIL import Image, ImageDraw
import sys
S = 1024; N = 64
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
PINK = (255, 64, 160, 255); PINK_D = (214, 32, 128, 255); WHITE = (255, 255, 255, 255)
d.ellipse((8, 8, S - 8, S - 8), fill=PINK)
def P(pts): return [(x * S / 100, y * S / 100) for x, y in pts]
# Kopf + Hals (Blick nach links)
head = P([(70, 86), (64, 64), (58, 52), (50, 44), (40, 40), (30, 42), (21, 48), (16, 55),
          (17, 61), (23, 64), (31, 62), (38, 60), (42, 64), (44, 74), (46, 86)])
d.polygon(head, fill=WHITE)
d.ellipse(P([(14, 50), (28, 66)])[0] + P([(14, 50), (28, 66)])[1], fill=WHITE)  # Maul rund
# Ohr
d.polygon(P([(52, 44), (57, 27), (61, 45)]), fill=WHITE)
# Horn (gerillt angedeutet)
d.polygon(P([(43, 41), (33, 13), (50, 39)]), fill=WHITE)
for t in (0.35, 0.55, 0.75):
    x1, y1 = 43 + (33 - 43) * t, 41 + (13 - 41) * t
    x2, y2 = 50 + (33 - 50) * t, 39 + (13 - 39) * t
    d.line(P([(x1, y1), (x2, y2)]), fill=PINK_D, width=int(S * 0.012))
# Maehne
d.polygon(P([(58, 44), (70, 40), (80, 48), (76, 52), (84, 60), (77, 63), (85, 72),
             (76, 74), (80, 84), (70, 86), (64, 64)]), fill=WHITE)
# Maehnen-Linien in pink fuer Struktur
for a, b in (((66, 47), (75, 56)), ((67, 58), (77, 68)), ((68, 69), (75, 79))):
    d.line(P([a, b]), fill=PINK_D, width=int(S * 0.014))
# Auge + Nuester
d.ellipse(P([(35, 46), (39.5, 50.5)])[0] + P([(35, 46), (39.5, 50.5)])[1], fill=PINK_D)
d.ellipse(P([(18.5, 54), (21.5, 57)])[0] + P([(18.5, 54), (21.5, 57)])[1], fill=PINK_D)
# alles ausserhalb des Kreises abschneiden
mask = Image.new("L", (S, S), 0); ImageDraw.Draw(mask).ellipse((8, 8, S - 8, S - 8), fill=255)
img.putalpha(Image.composite(img.getchannel("A"), Image.new("L", (S, S), 0), mask))
small = img.resize((N, N), Image.LANCZOS)
out = sys.argv[1] if len(sys.argv) > 1 else "Media/Unicorn.tga"
small.save(out)
img.resize((256, 256), Image.LANCZOS).save("/tmp/unicorn_preview.png")
