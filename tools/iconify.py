"""
iconify.py — Retire le fond d'une image, ajoute un cercle épais doré autour
             (l'image originale est inscrite dans le cercle), sauvegarde en icon_xxx.png.
             Le cercle or est encadré d'un cercle bronze fin à l'extérieur et à l'intérieur.
"""

import sys
import io
import math
from pathlib import Path


def iconify(input_path: Path) -> Path:
    from rembg import remove
    from PIL import Image, ImageDraw

    # 1. Supprime le fond
    with open(input_path, "rb") as f:
        data = f.read()
    result = remove(data)
    image = Image.open(io.BytesIO(result)).convert("RGBA")
    W, H = image.size

    # 2. Rayons et épaisseurs
    # Cercle réduit à 75% : l'image déborde par-dessus le cercle
    inner_radius = math.sqrt(W**2 + H**2) / 2 * 0.75
    thickness    = max(48, int(inner_radius * 0.20))    # anneau or, ~20% du rayon
    outer_radius = inner_radius + thickness
    bronze_thick = max(9, int(thickness * 0.20))        # filet bronze, ~20% de l'or
    total_radius = outer_radius + bronze_thick          # bord externe du filet bronze
    margin = 6
    # Canvas assez grand pour le cercle ET pour l'image qui déborde
    canvas_size = max(math.ceil(total_radius * 2), W, H) + margin * 2

    # 3. Supersampling 4× pour l'antialiasing
    scale = 4
    big = canvas_size * scale
    bcx = bcy = big // 2

    big_canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))

    # 4. Cercle dessiné EN PREMIER (derrière l'image)
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

    # 5. Image collée PAR-DESSUS le cercle
    big_image  = image.resize((W * scale, H * scale), Image.LANCZOS)
    img_layer  = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    img_layer.paste(big_image, (bcx - (W * scale) // 2, bcy - (H * scale) // 2), big_image)
    big_canvas = Image.alpha_composite(big_canvas, img_layer)

    # 6. Réduction à la taille finale
    final = big_canvas.resize((canvas_size, canvas_size), Image.LANCZOS)

    # 6. Sauvegarde
    output_path = input_path.parent / ("icon_" + input_path.stem + ".png")
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
    output_path = iconify(input_path)
    print(f"Enregistre : {output_path}")


if __name__ == "__main__":
    main()
