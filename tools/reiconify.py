"""
reiconify.py — Modifie une image deja produite par iconify.py :
               redessine la MOITIE INFERIEURE du cercle (or + les deux filets
               bronze) par-dessus l'image, pour que le bas du cercle passe
               devant le sujet (le sujet ne deborde plus qu'en haut).

               Aucun recalcul, aucune image source requise : le cercle est deja
               peint dans l'icone, on le RELIT directement dans les pixels
               (couleurs exactes or et bronze), puis on repeint sa moitie basse.

               Le resultat est enregistre dans un NOUVEAU fichier reicon_xxx.png
               a cote de l'original.
"""

import sys
from pathlib import Path

# Couleurs exactes posees par iconify.py
GOLD   = (153, 134, 78, 255)
BRONZE = (176, 115, 40, 255)


def reiconify(icon_path: Path) -> Path:
    import numpy as np
    from PIL import Image, ImageDraw

    icon = Image.open(icon_path).convert("RGBA")
    W, H = icon.size
    cx, cy = W / 2.0, H / 2.0          # iconify centre toujours l'anneau

    # 1. Relire le cercle dans les pixels
    arr = np.asarray(icon).astype(int)
    R, G, B, A = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]

    def color_mask(cr, cg, cb, tol=32):
        return (
            (abs(R - cr) <= tol)
            & (abs(G - cg) <= tol)
            & (abs(B - cb) <= tol)
            & (A >= 128)
        )

    # Rmax = demi-diagonale (rayon maximal possible)
    Rmax = int(np.ceil((W ** 2 + H ** 2) ** 0.5 / 2)) + 1
    radii = np.arange(Rmax + 1)
    circumference = 2 * np.pi * np.maximum(radii, 1)   # nb de pixels attendus par anneau de 1px

    def outer_band(mask, thresh=0.30):
        """Bande annulaire la plus exterieure ou la couleur occupe toute la
        circonference (compte >= thresh * 2*pi*r). Ignore les taches locales
        (or/bronze du sujet), qui ne couvrent qu'un petit arc.
        Retourne (bord_interieur, bord_exterieur) ou None."""
        if not mask.any():
            return None
        yy, xx = np.nonzero(mask)
        rr = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        counts = np.zeros(Rmax + 1)
        np.add.at(counts, np.clip(rr.astype(int), 0, Rmax), 1)
        above = counts >= thresh * circumference
        r_out = Rmax
        while r_out >= 0 and not above[r_out]:
            r_out -= 1
        if r_out < 0:
            return None
        r_in = r_out
        while r_in - 1 >= 0 and above[r_in - 1]:
            r_in -= 1
        return float(r_in), float(r_out)

    gold_band = outer_band(color_mask(*GOLD[:3]))
    if gold_band is None:
        print("ERREUR : anneau or introuvable — est-ce bien une icone iconify ?")
        sys.exit(1)
    inner, outer = gold_band          # bords interieur/exterieur de la bande or

    # Filet bronze : bande bronze la plus exterieure -> son bord externe = total.
    # Les deux filets ont la meme epaisseur dans iconify -> on en deduit le filet interieur.
    bronze_band = outer_band(color_mask(*BRONZE[:3]))
    if bronze_band is not None:
        total = bronze_band[1]                 # bord externe du filet bronze exterieur
        bronze_thick = max(1.0, total - outer)
    else:
        bronze_thick = max(9.0, (outer - inner) * 0.20)
        total = outer + bronze_thick
    filet_in = inner - bronze_thick            # bord interne du filet bronze interieur

    # 2. Redessiner les anneaux en supersampling 4x
    scale = 4
    big   = max(W, H) * scale
    bc    = big / 2.0

    ring = Image.new("RGBA", (big, big), (0, 0, 0, 0))

    def draw_ring(r_outer: float, r_inner: float, color: tuple) -> None:
        nonlocal ring
        mask = Image.new("L", (big, big), 0)
        dm   = ImageDraw.Draw(mask)
        dm.ellipse([bc - r_outer, bc - r_outer, bc + r_outer, bc + r_outer], fill=255)
        dm.ellipse([bc - r_inner, bc - r_inner, bc + r_inner, bc + r_inner], fill=0)
        layer = Image.new("RGBA", (big, big), color)
        layer.putalpha(mask)
        ring = Image.alpha_composite(ring, layer)

    s = scale
    draw_ring(outer * s, inner * s,    GOLD)      # bande or
    draw_ring(total * s, outer * s,    BRONZE)    # filet bronze exterieur
    draw_ring(inner * s, filet_in * s, BRONZE)    # filet bronze interieur

    # 3. Ne garder que la moitie inferieure (y >= centre)
    keep = Image.new("L", (big, big), 0)
    ImageDraw.Draw(keep).rectangle([0, int(round(bc)), big, big], fill=255)
    r_, g_, b_, a_ = ring.split()
    a_   = Image.composite(a_, Image.new("L", (big, big), 0), keep)
    ring = Image.merge("RGBA", (r_, g_, b_, a_))

    # 4. Reduction et composition par-dessus l'icone
    ring_small = ring.resize((max(W, H), max(W, H)), Image.LANCZOS)
    if ring_small.size != icon.size:                     # icone non carree : recentrer
        canvas = Image.new("RGBA", icon.size, (0, 0, 0, 0))
        canvas.paste(ring_small,
                     ((W - ring_small.width) // 2, (H - ring_small.height) // 2),
                     ring_small)
        ring_small = canvas
    final = Image.alpha_composite(icon, ring_small)

    # 5. Sauvegarde dans un nouveau fichier a cote
    stem = icon_path.stem
    out_stem = "icon_" + (stem[len("icon_"):] if stem.startswith("icon_") else stem)
    output_path = icon_path.parent / (out_stem + "-x.png")
    final.save(output_path, "PNG")
    return output_path


def main():
    if len(sys.argv) < 2:
        print("ERREUR : aucun fichier fourni.")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    if not input_path.exists():
        print(f"ERREUR : fichier introuvable : {input_path}")
        sys.exit(1)

    print(f"Traitement de : {input_path.name} ...")
    output_path = reiconify(input_path)
    print(f"Enregistre : {output_path}")


if __name__ == "__main__":
    main()
