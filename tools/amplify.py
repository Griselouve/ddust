"""
amplify.py — Agrandit le canvas d'une image à 1.5× sa taille (largeur et hauteur),
             en centrant l'image originale sur fond transparent.
             Sauvegarde en amplified_xxx.png.
"""

import sys
from pathlib import Path


def amplify(input_path: Path) -> Path:
    from PIL import Image

    image = Image.open(input_path).convert("RGBA")
    W, H = image.size

    new_W = round(W * 1.5)
    new_H = round(H * 1.5)

    canvas = Image.new("RGBA", (new_W, new_H), (0, 0, 0, 0))
    offset_x = (new_W - W) // 2
    offset_y = (new_H - H) // 2
    canvas.paste(image, (offset_x, offset_y), image)

    out_dir = input_path.parent / "amplified"
    out_dir.mkdir(exist_ok=True)
    output_path = out_dir / input_path.name
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

    print(f"Traitement de : {input_path.name} ...")
    output_path = amplify(input_path)
    print(f"Enregistré : {output_path}")


if __name__ == "__main__":
    main()
