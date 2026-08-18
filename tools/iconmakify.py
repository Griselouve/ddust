"""
iconmakify.py — Enchaîne iconmaker + iconify :
  1. Découpe une feuille d'icones en dessins individuels (détection + détourage,
     logique de iconmaker.py).
  2. Incruste chaque dessin dans un cercle doré encadré de bronze
     (logique de iconify.py).

Les résultats sont écrits dans "extracted iconified/" à côté de la feuille source,
de la même façon que iconmaker.py écrit dans "extracted icons/".
"""

import sys
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

# Réutilise la détection/segmentation de iconmaker (fonctions pures, sans effet de bord)
from iconmaker import find_cells, label_bottom, BG_TOL, PAD


# ── Incrustation dans le cercle (adapté de iconify.py) ────────────────────────
#
# Prend une image RGBA au fond déjà transparent (sortie rembg du crop) et la
# renvoie inscrite dans un cercle or encadré de deux filets bronze.

def circle_wrap(image: Image.Image) -> Image.Image:
    W, H = image.size

    # Rayons et épaisseurs
    # Cercle réduit à 75% : l'image déborde par-dessus le cercle
    inner_radius = math.sqrt(W**2 + H**2) / 2 * 0.75
    thickness    = max(48, int(inner_radius * 0.20))    # anneau or, ~20% du rayon
    outer_radius = inner_radius + thickness
    bronze_thick = max(9, int(thickness * 0.20))        # filet bronze, ~20% de l'or
    total_radius = outer_radius + bronze_thick          # bord externe du filet bronze
    margin = 6
    # Canvas assez grand pour le cercle ET pour l'image qui déborde
    canvas_size = max(math.ceil(total_radius * 2), W, H) + margin * 2

    # Supersampling 4× pour l'antialiasing
    scale = 4
    big = canvas_size * scale
    bcx = bcy = big // 2

    big_canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))

    def draw_ring(r_outer: float, r_inner: float, color: tuple) -> None:
        mask = Image.new("L", (big, big), 0)
        dm   = ImageDraw.Draw(mask)
        dm.ellipse([bcx - r_outer, bcy - r_outer, bcx + r_outer, bcy + r_outer], fill=255)
        dm.ellipse([bcx - r_inner, bcy - r_inner, bcx + r_inner, bcy + r_inner], fill=0)
        layer = Image.new("RGBA", (big, big), color)
        layer.putalpha(mask)
        nonlocal big_canvas
        big_canvas = Image.alpha_composite(big_canvas, layer)

    s = scale
    gold   = (153, 134, 78, 255)
    bronze = (176, 115, 40, 255)

    draw_ring(outer_radius * s, inner_radius * s,                   gold)
    draw_ring(total_radius * s, outer_radius * s,                   bronze)
    draw_ring(inner_radius * s, (inner_radius - bronze_thick) * s,  bronze)

    # Image collée PAR-DESSUS le cercle
    big_image  = image.resize((W * scale, H * scale), Image.LANCZOS)
    img_layer  = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    img_layer.paste(big_image, (bcx - (W * scale) // 2, bcy - (H * scale) // 2), big_image)
    big_canvas = Image.alpha_composite(big_canvas, img_layer)

    # Réduction à la taille finale
    return big_canvas.resize((canvas_size, canvas_size), Image.LANCZOS)


# ── Découpe des crops (logique de iconmaker.detect_icons) ─────────────────────

def compute_crops(img: Image.Image):
    """Détecte les cases et renvoie la liste des crops (x1, y1, x2, y2, aw, ah)."""
    arr = np.array(img, dtype=np.uint8)
    h, w = arr.shape[:2]

    corners = np.array([arr[0, 0, :3], arr[0, w - 1, :3],
                        arr[h - 1, 0, :3], arr[h - 1, w - 1, :3]], dtype=float)
    bg = corners.mean(axis=0)
    print(f"Fond : {np.round(bg).astype(int).tolist()}")

    fg = np.any(np.abs(arr[:, :, :3].astype(float) - bg) >= BG_TOL, axis=2)

    regions = find_cells(fg, h, w)
    if not regions:
        print("Aucune icone trouvée. Vérifie BG_TOL.")
        return []

    shields = [dict(cy=(r["rmin"] + r["rmax"]) / 2, cx=(r["cmin"] + r["cmax"]) / 2, **r)
               for r in regions]
    print(f"Icones détectées : {len(shields)}")
    shields.sort(key=lambda s: (s["cy"], s["cx"]))

    crops = []
    for shield in shields:
        x1 = max(0, shield["cmin"] - PAD)
        x2 = min(w, shield["cmax"] + PAD)
        y1 = max(0, shield["rmin"] - PAD)
        aw = shield["cmax"] - shield["cmin"]
        ah = shield["rmax"] - shield["rmin"]

        y2 = min(h, shield["rmax"] + PAD)

        below = [s for s in shields if s["rmin"] > shield["rmax"] + 5]
        max_y = (min(s["rmin"] for s in below) - 5) if below \
            else min(h, shield["rmax"] + int(1.2 * ah))

        scan_x1 = x1 - 20
        scan_x2 = x2 + 20
        min_gap = max(4, int(0.04 * ah))
        bottom = label_bottom(fg, scan_x1, scan_x2, shield["rmax"], max_y, min_gap)
        if bottom is not None:
            y2 = min(h, bottom + PAD)

        crops.append((x1, y1, x2, y2, aw, ah))
    return crops


def iconmakify(image_path: Path) -> int:
    img = Image.open(image_path).convert("RGBA")
    crops = compute_crops(img)
    if not crops:
        return 0

    out_dir = image_path.parent / "extracted iconified"
    out_dir.mkdir(exist_ok=True)

    existing = [int(p.stem.split("_")[1]) for p in out_dir.glob("icon_*.png")
                if p.stem.split("_")[1].isdigit()]
    start_idx = max(existing, default=0) + 1

    # Session rembg unique réutilisée pour tous les crops (modèle chargé 1 fois)
    from rembg import remove, new_session
    session = new_session()
    print("Détourage du fond (rembg) puis incrustation dans le cercle…")

    for idx, (x1, y1, x2, y2, aw, ah) in enumerate(crops, start=start_idx):
        crop = img.crop((x1, y1, x2, y2))
        cutout = remove(crop, session=session)   # RGBA, fond transparent
        final = circle_wrap(cutout)              # inscrit dans le cercle doré
        final.save(out_dir / f"icon_{idx:02d}.png", "PNG")
        print(f"  icon_{idx:02d}.png  ({x1},{y1})-({x2},{y2})  {x2-x1}×{y2-y1}px → {final.width}×{final.height}px")

    print(f"\nTerminé — {len(crops)} icones → {out_dir}")
    return len(crops)


def main():
    if len(sys.argv) < 2:
        print("ERREUR : aucun fichier fourni.")
        sys.exit(1)
    path = Path(sys.argv[1])
    if not path.exists():
        print(f"ERREUR : {path}")
        sys.exit(1)
    print(f"Traitement : {path.name}")
    iconmakify(path)


if __name__ == "__main__":
    main()
