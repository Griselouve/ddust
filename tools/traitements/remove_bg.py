"""
remove_bg.py — Retire le fond d'une image PNG et le remplace par un canal alpha transparent.
Reçoit le chemin du fichier en argument (géré par remove_bg.bat via PowerShell).
"""

import sys
import io
from pathlib import Path


def remove_background(input_path: Path) -> Path:
    from rembg import remove
    from PIL import Image

    with open(input_path, "rb") as f:
        data = f.read()

    result = remove(data)

    output_path = input_path.with_stem(input_path.stem + "_nobg")
    image = Image.open(io.BytesIO(result)).convert("RGBA")
    image.save(output_path, "PNG")
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
    output_path = remove_background(input_path)
    print(f"Enregistre : {output_path}")


if __name__ == "__main__":
    main()
