# Placeholders des icônes du menu d'administration du tiroir (mode chef).
# Glyphes neutres, transparents, 256x256 — à REMPLACER par de vraies illustrations donjon.
# Chaque glyphe nomme l'état d'arrivée : ⌀ désactivée (ambre), V active (vert),
# œil barré cachée (rouge sourd), œil ouvert montrée (vert), + ajout (or).
#   python gen_adm_icons.py
from math import pi, sin

from PIL import Image, ImageDraw

OUT = "../resources_cloud/donjon/images/big"
S, C, R = 256, 128, 96          # taille, centre, rayon
AMBER, GREEN, RED, GOLD = (216, 158, 48, 255), (74, 176, 92, 255), (176, 64, 56, 255), (200, 168, 75, 255)


def canvas():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def disable():                                      # ⌀ : cercle barré
    img, d = canvas()
    d.ellipse([C - R, C - R, C + R, C + R], outline=AMBER, width=18)
    o = int(R * 0.70)
    d.line([C - o, C + o, C + o, C - o], fill=AMBER, width=18)
    return img


def enable():                                       # V : encoche
    img, d = canvas()
    d.line([(52, 132), (106, 188)], fill=GREEN, width=26, joint="curve")
    d.line([(106, 188), (206, 68)], fill=GREEN, width=26, joint="curve")
    return img


def hide():                                         # œil barré : amande (2 arcs sinus) + pupille + barre
    img, d = canvas()
    x0, x1, bulge = 40, 216, 46
    span = x1 - x0
    top = [(x, C - bulge * sin(pi * (x - x0) / span)) for x in range(x0, x1 + 1, 4)]
    bot = [(x, C + bulge * sin(pi * (x - x0) / span)) for x in range(x0, x1 + 1, 4)]
    d.line(top, fill=RED, width=14, joint="curve")
    d.line(bot, fill=RED, width=14, joint="curve")
    d.ellipse([C - 26, C - 26, C + 26, C + 26], outline=RED, width=14)
    d.line([(50, 206), (206, 50)], fill=RED, width=20)
    return img


def show():                                         # œil ouvert (vert) : révéler aux joueurs
    img, d = canvas()
    x0, x1, bulge = 40, 216, 46
    span = x1 - x0
    top = [(x, C - bulge * sin(pi * (x - x0) / span)) for x in range(x0, x1 + 1, 4)]
    bot = [(x, C + bulge * sin(pi * (x - x0) / span)) for x in range(x0, x1 + 1, 4)]
    d.line(top, fill=GREEN, width=14, joint="curve")
    d.line(bot, fill=GREEN, width=14, joint="curve")
    d.ellipse([C - 30, C - 30, C + 30, C + 30], outline=GREEN, width=14)
    d.ellipse([C - 12, C - 12, C + 12, C + 12], fill=GREEN)   # pupille pleine = œil grand ouvert
    return img


def add():                                          # +
    img, d = canvas()
    d.line([(C, 44), (C, 212)], fill=GOLD, width=28)
    d.line([(44, C), (212, C)], fill=GOLD, width=28)
    return img


def cross():                                        # croix rouge : overlay des tâches cachées
    img, d = canvas()                               # (coin sud-est de l'icône, en mode admin)
    for pts in ([(48, 48), (208, 208)], [(208, 48), (48, 208)]):
        d.line(pts, fill=(20, 20, 20, 255), width=44)   # liseré sombre : lisible sur toute icône
        d.line(pts, fill=(198, 52, 44, 255), width=32)
    return img


for name, fn in [("adm_disable", disable), ("adm_enable", enable),
                 ("adm_hide", hide), ("adm_show", show), ("adm_add", add), ("adm_cross", cross)]:
    fn().save(f"{OUT}/{name}.png")
    print(f"{name}.png")
