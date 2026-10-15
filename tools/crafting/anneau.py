"""
anneau.py : pose un avatar dans l'anneau doré, selon LA RÈGLE DES DEUX MOITIÉS (2026-10-13).

    - La moitié SUPÉRIEURE de l'anneau est peinte DERRIÈRE l'avatar : la tête et les épaules ont
      le droit de la dépasser.
    - La moitié INFÉRIEURE est peinte PAR-DESSUS l'avatar, et l'avatar ne dépasse jamais du cercle
      dans cette moitié : ce qui sortirait du disque intérieur sous l'équateur est effacé.

Et une TAILLE HOMOGÈNE : le personnage (ou le groupe) est détouré, recadré sur lui-même, puis mis
à la même hauteur, le bas du corps posé sur le bas du cercle. Plus de petits personnages perdus
au milieu d'un grand fond, comme le faisait iconify (qui collait l'image entière, marges comprises).

Entrée : une image rendue sur FOND UNI (le fond est mesuré sur le pourtour et rendu transparent),
ou une image déjà détourée. Sortie : PNG carré 1024 px, fond transparent.
Mêmes couleurs d'anneau qu'iconify (or 153,134,78 ; filets bronze 176,115,40).
Appel par la chaîne de traitements d'assetgen : `{ outil: anneau, fonction: anneau }`.
"""

import math
import sys
from pathlib import Path

TAILLE = 1024
R_INT = 0.355          # rayon du disque intérieur / taille
EP_OR = 0.075          # épaisseur de l'anneau or / taille
EP_BRONZE = 0.014      # filets bronze / taille
CY = 0.57              # centre vertical (plus bas que le milieu : place pour la tête qui dépasse)
HAUTEUR = 2.2          # hauteur du personnage en rayons intérieurs (2 = juste le disque)
LARGEUR_MAX = 0.97     # largeur maximale / taille
OR = (153, 134, 78, 255)
BRONZE = (176, 115, 40, 255)


def _detoure(im):
    """Fond uni -> transparent, s'il n'y a pas déjà de transparence."""
    from PIL import Image
    im = im.convert("RGBA")
    if im.getchannel("A").getextrema()[0] < 250:
        return im                                   # déjà détouré
    px = im.load()
    w, h = im.size
    bord = [px[x, y] for x in range(0, w, 4) for y in (0, 1, h - 2, h - 1)] + \
           [px[x, y] for y in range(0, h, 4) for x in (0, 1, w - 2, w - 1)]
    fond = tuple(sorted(c[i] for c in bord)[len(bord) // 2] for i in range(3))
    pres, loin = 22.0, 55.0
    out = Image.new("RGBA", im.size)
    po = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            d = math.sqrt((r - fond[0]) ** 2 + (g - fond[1]) ** 2 + (b - fond[2]) ** 2)
            if d <= pres:
                po[x, y] = (0, 0, 0, 0)
            elif d < loin:
                t = (d - pres) / (loin - pres)
                po[x, y] = (r, g, b, int(a * t))
            else:
                po[x, y] = (r, g, b, a)
    return out


def _disque(taille, cx, cy, r_ext, r_int, couleur, haut=None):
    """Calque d'un anneau (r_int < r < r_ext). `haut` : True = moitié supérieure seule, False =
    moitié inférieure seule, None = tout."""
    from PIL import Image, ImageDraw
    m = Image.new("L", (taille, taille), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([cx - r_ext, cy - r_ext, cx + r_ext, cy + r_ext], fill=255)
    if r_int > 0:
        d.ellipse([cx - r_int, cy - r_int, cx + r_int, cy + r_int], fill=0)
    if haut is True:
        d.rectangle([0, cy, taille, taille], fill=0)
    elif haut is False:
        d.rectangle([0, 0, taille, cy - 1], fill=0)
    calque = Image.new("RGBA", (taille, taille), couleur)
    calque.putalpha(m)
    return calque


def _anneau_calque(taille, cx, cy, ri, haut):
    from PIL import Image
    ep_or, ep_br = EP_OR * taille, EP_BRONZE * taille
    c = Image.new("RGBA", (taille, taille), (0, 0, 0, 0))
    c = Image.alpha_composite(c, _disque(taille, cx, cy, ri + ep_or, ri, OR, haut))
    c = Image.alpha_composite(c, _disque(taille, cx, cy, ri + ep_or + ep_br, ri + ep_or, BRONZE, haut))
    c = Image.alpha_composite(c, _disque(taille, cx, cy, ri, ri - ep_br, BRONZE, haut))
    return c


def anneau(input_path: Path) -> Path:
    from PIL import Image, ImageDraw
    S = 4 * TAILLE                                  # suréchantillonnage 4x pour l'anticrénelage
    cx, cy, ri = S / 2, CY * S, R_INT * S

    sujet = _detoure(Image.open(input_path))
    bbox = sujet.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    if not bbox:
        raise RuntimeError("aucun sujet détecté")
    sujet = sujet.crop(bbox)

    # Taille homogène : même hauteur pour tous, plafonnée en largeur.
    k = (HAUTEUR * ri) / sujet.height
    if sujet.width * k > LARGEUR_MAX * S:
        k = LARGEUR_MAX * S / sujet.width
    sujet = sujet.resize((max(1, round(sujet.width * k)), max(1, round(sujet.height * k))), Image.LANCZOS)

    # Le bas du corps se pose sur le bas du cercle (un peu en dessous : la bordure le recouvre).
    x0 = round(cx - sujet.width / 2)
    y0 = round(cy + ri + 0.02 * S - sujet.height)
    calque = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    calque.paste(sujet, (x0, max(0, y0)), sujet)

    # Sous l'équateur, rien ne sort du disque intérieur.
    masque = Image.new("L", (S, S), 255)
    dm = ImageDraw.Draw(masque)
    dm.rectangle([0, cy, S, S], fill=0)
    dm.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=255)
    a = calque.getchannel("A")
    from PIL import ImageChops
    calque.putalpha(ImageChops.multiply(a, masque))

    toile = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    toile = Image.alpha_composite(toile, _anneau_calque(S, cx, cy, ri, None))     # tout l'anneau derrière
    toile = Image.alpha_composite(toile, calque)                                 # l'avatar
    toile = Image.alpha_composite(toile, _anneau_calque(S, cx, cy, ri, False))   # moitié basse par-dessus

    final = toile.resize((TAILLE, TAILLE), Image.LANCZOS)
    out = input_path.parent / ("anneau_" + input_path.stem + ".png")
    final.save(out, "PNG")
    return out


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(anneau(Path(p)))
