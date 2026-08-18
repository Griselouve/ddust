"""
Assemble tous les screenshots du dossier SCREENSHOTS_DIR en une seule image JPEG
collée de gauche à droite (ordre alphabétique), avec le nom de fichier affiché
sous chaque screenshot. Écrase material/screens.jpg.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SCREENSHOTS_DIR = Path("C:/Users/grisl/Downloads/ddust/screenshots")
OUTPUT_FILE = Path(__file__).parent.parent / "material" / "screens.jpg"

# Hauteur cible de chaque screenshot (px). Contrôle la lisibilité.
TARGET_HEIGHT = 600

# Qualité JPEG (1–95). Diminuer pour réduire le poids du fichier.
JPEG_QUALITY = 82

# Hauteur de la bande de texte sous chaque screenshot (px).
LABEL_HEIGHT = 28

# Espacement horizontal entre les screenshots (px).
GAP = 6

BACKGROUND = (20, 20, 20)
LABEL_BG = (20, 20, 20)
LABEL_FG = (200, 200, 200)


def _load_font(size: int) -> ImageFont.ImageFont:
    for name in ("arial.ttf", "DejaVuSans.ttf", "LiberationSans-Regular.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    exts = {".png", ".jpg", ".jpeg", ".webp"}
    files = sorted(p for p in SCREENSHOTS_DIR.iterdir() if p.suffix.lower() in exts)

    if not files:
        print(f"Aucun screenshot trouvé dans {SCREENSHOTS_DIR}")
        return

    print(f"{len(files)} screenshot(s) trouvé(s) :")
    images, names = [], []
    for f in files:
        img = Image.open(f).convert("RGB")
        images.append(img)
        names.append(f.stem)
        print(f"  {f.name}  ({img.width}x{img.height})")

    # Redimensionner chaque screenshot à TARGET_HEIGHT
    resized = []
    for img in images:
        if img.height != TARGET_HEIGHT:
            ratio = TARGET_HEIGHT / img.height
            img = img.resize((max(1, int(img.width * ratio)), TARGET_HEIGHT), Image.LANCZOS)
        resized.append(img)

    total_w = sum(img.width for img in resized) + GAP * (len(resized) - 1)
    total_h = TARGET_HEIGHT + LABEL_HEIGHT

    font = _load_font(13)
    strip = Image.new("RGB", (total_w, total_h), BACKGROUND)
    draw = ImageDraw.Draw(strip)

    x = 0
    for i, (img, name) in enumerate(zip(resized, names)):
        strip.paste(img, (x, 0))
        # Centrer le nom sous le screenshot
        bbox = draw.textbbox((0, 0), name, font=font)
        text_w = bbox[2] - bbox[0]
        tx = x + (img.width - text_w) // 2
        ty = TARGET_HEIGHT + (LABEL_HEIGHT - (bbox[3] - bbox[1])) // 2
        draw.text((tx, ty), name, fill=LABEL_FG, font=font)
        x += img.width
        if i < len(resized) - 1:
            # Séparateur vertical blanc centré dans le gap
            sep_x = x + GAP // 2
            draw.line([(sep_x, 0), (sep_x, TARGET_HEIGHT - 1)], fill=(255, 255, 255), width=1)
            x += GAP

    strip.save(OUTPUT_FILE, "JPEG", quality=JPEG_QUALITY, optimize=True)
    size_kb = OUTPUT_FILE.stat().st_size // 1024
    print(f"Taille finale : {total_w}x{total_h}")
    print(f"Enregistré : {OUTPUT_FILE}  ({size_kb} Ko)")


if __name__ == "__main__":
    main()
