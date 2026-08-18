"""
expand.py — Agrandit la partie opaque d'une image detouree jusqu'a ce qu'elle remplisse
            le canvas, a taille de canvas constante et sans deformation.
            Sauvegarde en xxx-x.png (suffixe attendu par remove-x.py).
"""

import sys
from pathlib import Path

ALPHA_SEUIL = 8   # en dessous, un pixel est considere comme transparent (halo d'antialiasing)
MARGE = 0         # marge en pixels laissee entre le sujet et le bord du canvas


def expand(input_path: Path) -> Path:
    from PIL import Image

    image = Image.open(input_path).convert("RGBA")
    W, H = image.size

    alpha = image.getchannel("A")
    bbox = alpha.point(lambda a: 255 if a >= ALPHA_SEUIL else 0).getbbox()
    if bbox is None:
        print("Image entierement transparente : rien a agrandir.")
        return None

    sujet = image.crop(bbox)
    bw, bh = sujet.size

    k = min((W - 2 * MARGE) / bw, (H - 2 * MARGE) / bh)
    if k <= 1:
        print("Le sujet remplit deja le canvas : sortie identique a l'original.")
        k = 1.0

    new_W = max(1, round(bw * k))
    new_H = max(1, round(bh * k))
    sujet = sujet.resize((new_W, new_H), Image.LANCZOS)

    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.paste(sujet, ((W - new_W) // 2, (H - new_H) // 2), sujet)

    output_path = input_path.with_stem(input_path.stem + "-x")
    canvas.save(output_path, "PNG")
    return output_path


def main():
    if len(sys.argv) < 2:
        print("ERREUR : aucun fichier fourni.")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    if not input_path.exists():
        print(f"ERREUR : fichier introuvable : {input_path}")
        sys.exit(1)

    if input_path.stem.endswith("-x"):
        print(f"ERREUR : {input_path.name} est deja un fichier -x.")
        sys.exit(1)

    print(f"Traitement de : {input_path.name} ...")
    output_path = expand(input_path)
    if output_path:
        print(f"Enregistre : {output_path}")


if __name__ == "__main__":
    main()
