"""
iconconify.py — Retire le fond d'une image icône, recolore en doré (même doré que iconify),
                ajoute un contour bronze proportionnel à l'épaisseur du tracé de l'icône,
                sauvegarde en iconcon_xxx.png. Pas de cercle.
"""

import sys
import io
from pathlib import Path


def estimate_stroke_width(alpha_array):
    """
    Estime l'épaisseur moyenne du tracé via ratio aire/périmètre.
    Pour un trait de largeur S : aire ≈ périmètre * S → S ≈ 2 * aire / nb_pixels_bord.
    """
    import numpy as np
    binary = (alpha_array > 128).astype(np.uint8)
    area = int(binary.sum())
    if area == 0:
        return 1.0
    padded = np.pad(binary, 1)
    neighbor_sum = (
        padded[:-2, 1:-1] + padded[2:, 1:-1] +
        padded[1:-1, :-2] + padded[1:-1, 2:]
    )
    edge_pixels = int(((binary == 1) & (neighbor_sum < 4)).sum())
    if edge_pixels == 0:
        return float(area)
    return 2.0 * area / edge_pixels


def dilate_alpha(alpha, radius):
    from PIL import ImageFilter
    result = alpha
    remaining = int(radius)
    while remaining > 0:
        step = min(remaining, 10)
        result = result.filter(ImageFilter.MaxFilter(step * 2 + 1))
        remaining -= step
    return result


def iconconify(input_path: Path) -> Path:
    import numpy as np
    from rembg import remove
    from PIL import Image

    # 1. Supprime le fond
    with open(input_path, "rb") as f:
        data = f.read()
    result = remove(data)
    image = Image.open(io.BytesIO(result)).convert("RGBA")
    W, H = image.size

    # Couleurs identiques à iconify
    gold   = (218, 165, 32, 255)
    bronze = (176, 115, 40, 255)

    # 2. Supersampling 4× pour l'antialiasing
    scale = 4
    big_W, big_H = W * scale, H * scale
    big_image = image.resize((big_W, big_H), Image.LANCZOS)
    _, _, _, a = big_image.split()

    # 3. Épaisseur bronze : 20% de l'épaisseur estimée du tracé (en pixels supersamplés)
    #    Minimum 2px natifs (= scale*2 supersamplés) pour rester visible
    stroke_px = estimate_stroke_width(np.array(a))
    bt = max(scale * 2, int(stroke_px * 0.20))
    print(f"  Épaisseur tracé estimée : {stroke_px / scale:.1f}px → contour bronze : {bt / scale:.1f}px")

    # 4. Icône dorée (alpha original conservé)
    gold_layer = Image.new("RGBA", (big_W, big_H), gold)
    gold_layer.putalpha(a)

    # 5. Contour bronze par dilatation du masque alpha
    dilated = dilate_alpha(a, bt)
    bronze_layer = Image.new("RGBA", (big_W, big_H), bronze)
    bronze_layer.putalpha(dilated)

    # 6. Compositer : bronze derrière, doré devant
    canvas = Image.new("RGBA", (big_W, big_H), (0, 0, 0, 0))
    canvas = Image.alpha_composite(canvas, bronze_layer)
    canvas = Image.alpha_composite(canvas, gold_layer)

    # 7. Réduire à la taille finale et sauvegarder
    final = canvas.resize((W, H), Image.LANCZOS)
    output_path = input_path.parent / ("iconcon_" + input_path.stem + ".png")
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
    output_path = iconconify(input_path)
    print(f"Enregistré : {output_path}")


if __name__ == "__main__":
    main()
