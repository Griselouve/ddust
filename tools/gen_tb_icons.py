from PIL import Image, ImageDraw
import os

RS   = 512
OS   = 256
RSW  = 28
GOLD = (200, 168, 75, 255)
DARK = (30, 10, 0, 255)
TRAN = (0, 0, 0, 0)
OUT  = r"E:\Deva\projects\suites\ddust\build\resources\images_donjon"

try:
    RESAMPLE = Image.Resampling.LANCZOS
except AttributeError:
    RESAMPLE = Image.LANCZOS

def canvas():
    img = Image.new("RGBA", (RS, RS), TRAN)
    return img, ImageDraw.Draw(img)

def save(img, name):
    img.resize((OS, OS), RESAMPLE).save(os.path.join(OUT, name))
    print(name)

def poly(d, pts, c=GOLD, w=RSW, closed=True):
    lst = list(pts) + ([pts[0]] if closed else [])
    for i in range(len(lst) - 1):
        d.line([lst[i], lst[i+1]], fill=c, width=w)

# Boutique: sac de courses
img, d = canvas()
d.rectangle([136, 224, 376, 412], outline=GOLD, width=RSW)
d.line([(200, 224), (200, 168)], fill=GOLD, width=RSW)
d.line([(312, 224), (312, 168)], fill=GOLD, width=RSW)
d.arc([200, 108, 312, 228], start=180, end=360, fill=GOLD, width=RSW)
save(img, "tb_boutique.png")

# Clan: bouclier
img, d = canvas()
poly(d, [(104, 128), (408, 128), (408, 316), (256, 400), (104, 316)])
save(img, "tb_clan.png")

# Combat: cercle doré + épées croisées sombres
img, d = canvas()
d.ellipse([32, 32, 480, 480], fill=GOLD)
d.line([(108, 108), (404, 404)], fill=DARK, width=RSW)
d.line([(404, 108), (108, 404)], fill=DARK, width=RSW)
d.line([(140, 372), (196, 316)], fill=DARK, width=RSW + 4)
d.line([(316, 316), (372, 372)], fill=DARK, width=RSW + 4)
save(img, "tb_combat.png")

# Personnage: tête + épaules
img, d = canvas()
d.ellipse([192, 128, 320, 256], outline=GOLD, width=RSW)
d.arc([112, 272, 400, 440], start=180, end=360, fill=GOLD, width=RSW)
save(img, "tb_perso.png")

# Inventaire: cadenas
img, d = canvas()
d.rectangle([136, 256, 376, 400], outline=GOLD, width=RSW)
d.line([(192, 256), (192, 192)], fill=GOLD, width=RSW)
d.line([(320, 256), (320, 192)], fill=GOLD, width=RSW)
d.arc([192, 112, 320, 272], start=180, end=360, fill=GOLD, width=RSW)
d.ellipse([228, 306, 284, 362], outline=GOLD, width=RSW - 8)
save(img, "tb_inventaire.png")

print("Done.")
