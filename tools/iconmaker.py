"""
iconmaker.py — Détecte automatiquement les icones dans une feuille d'icones,
               détoure chacune (fond transparent via rembg) et sauvegarde
               en 1536x1536 PNG transparent dans "extracted icons/".

Stratégie (deux passes) :
  1. Pass 1 — segmentation : bandes de rangées (gouttières noires pleine largeur)
     puis blocs de contenu dans chaque bande (gouttières = colonnes vides sur
     toute la hauteur de la bande). Les éléments d'une même scène se chevauchent
     verticalement → restent groupés (pas de sur-découpe). On en déduit la taille
     MÉDIANE d'une case.
  2. Pass 2 — cohérence : tout bloc dont une dimension dépasse 1.6× la médiane
     (= plusieurs scènes collées) est découpé à sa gouttière interne. Les cases
     simplement larges restent intactes.
  3. Pour chaque case, scan vers le bas pour un éventuel label texte.
  4. Echelle par icone : chaque dessin occupe FILL × OUT_SIZE.
  5. Détourage du fond (rembg) → canvas transparent.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

BG_TOL   = 20
PAD      = 15     # marge autour du crop (px)
OUT_SIZE = 1536
OUT_BG   = (0, 0, 0, 0)   # canvas transparent (fond retiré)
FILL     = 0.88   # fraction de OUT_SIZE occupée par l'art de chaque icone


def label_bottom(fg: np.ndarray, x1: int, x2: int, art_bottom: int,
                 max_y: int, min_gap: int):
    """Dernière ligne d'un vrai bloc de label sous l'art, ou None si absent.

    Un label = un trou d'au moins ``min_gap`` lignes vides après le bas de l'art,
    suivi de pixels fg (le texte). Sans ce trou, on considère qu'il n'y a pas de
    label (cas des grilles sans légende) et on ne sur-étend pas le crop.
    """
    x1c = max(0, x1)
    x2c = min(fg.shape[1], x2)
    band = fg[art_bottom:max_y, x1c:x2c]
    if band.size == 0:
        return None
    rows_fg = band.any(axis=1)   # présence d'au moins un pixel fg par ligne
    gap = 0
    for i, has in enumerate(rows_fg):
        if has:
            gap = 0
            continue
        gap += 1
        if gap >= min_gap:
            rest = np.where(rows_fg[i + 1:])[0]
            if len(rest):
                return art_bottom + (i + 1) + int(rest[-1])
            return None
    return None


# ── Détection des cases (deux passes) ─────────────────────────────────────────
#
# Pass 1 — segmentation et estimation de la taille moyenne :
#   On découpe en bandes de RANGÉES (gouttières noires pleine largeur), puis,
#   DANS chaque bande, en BLOCS de contenu (gouttières = colonnes vides sur toute
#   la hauteur de la bande). Les éléments d'une même scène se chevauchent
#   verticalement → aucune gouttière interne → ils restent groupés (pas de
#   sur-découpe garçon/monstre). On en déduit la taille MÉDIANE d'une case.
#
# Pass 2 — cohérence : tout bloc dont une dimension dépasse 1.6× la médiane
#   contient en réalité plusieurs scènes collées → on le découpe à sa gouttière
#   interne (densité minimale). Les cases simplement larges (≤ ~1.5×) restent
#   intactes. C'est l'estimation de taille de la pass 1 qui autorise — ou non —
#   un découpage.

def _w(r): return r["cmax"] - r["cmin"] + 1
def _h(r): return r["rmax"] - r["rmin"] + 1


def _runs(mask, length):
    """Intervalles (start, end) où mask est vrai."""
    out = []
    s = None
    for i, e in enumerate(mask):
        if e and s is None:
            s = i
        elif not e and s is not None:
            out.append((s, i)); s = None
    if s is not None:
        out.append((s, length))
    return out


def _tight(fg, rmin, rmax, cmin, cmax):
    """Boîte serrée sur les pixels fg dans la fenêtre donnée (ou None si vide)."""
    sub = fg[rmin:rmax + 1, cmin:cmax + 1]
    ys = np.where(sub.any(axis=1))[0]
    xs = np.where(sub.any(axis=0))[0]
    if len(ys) == 0 or len(xs) == 0:
        return None
    return dict(rmin=rmin + int(ys[0]),  rmax=rmin + int(ys[-1]),
                cmin=cmin + int(xs[0]),  cmax=cmin + int(xs[-1]))


def _cut_positions(profile, length, k, win):
    """k-1 offsets de coupe = minima du profil près des séparations régulières."""
    cuts = []
    for j in range(1, k):
        c = int(round(length * j / k))
        lo = max(1, c - win)
        hi = min(length - 1, c + win)
        cuts.append(lo + int(np.argmin(profile[lo:hi])) if hi > lo else c)
    return cuts


def split_cell(c, fg, ref_w, ref_h):
    """Découpe un bloc dont une dimension dépasse 1.6× la médiane (scènes collées).

    On coupe aux gouttières internes (colonnes/lignes de densité minimale), en
    `round(dim / réf)` morceaux. Un bloc cohérent (≤ ~1.5× la médiane) est laissé
    tel quel.
    """
    # Horizontal (largeur > 1.6× largeur médiane)
    out = []
    k = int(round(_w(c) / ref_w))
    if k >= 2 and _w(c) > 1.6 * ref_w:
        sub = fg[c["rmin"]:c["rmax"] + 1, c["cmin"]:c["cmax"] + 1]
        cuts = _cut_positions(sub.sum(axis=0), _w(c), k, int(0.3 * ref_w))
        bounds = [0] + cuts + [_w(c)]
        out += [t for a, b in zip(bounds, bounds[1:])
                if (t := _tight(fg, c["rmin"], c["rmax"], c["cmin"] + a, c["cmin"] + b - 1))]
    else:
        out.append(c)
    # Vertical (hauteur > 1.6× hauteur médiane)
    res = []
    for s in out:
        k = int(round(_h(s) / ref_h))
        if k >= 2 and _h(s) > 1.6 * ref_h:
            sub = fg[s["rmin"]:s["rmax"] + 1, s["cmin"]:s["cmax"] + 1]
            cuts = _cut_positions(sub.sum(axis=1), _h(s), k, int(0.3 * ref_h))
            bounds = [0] + cuts + [_h(s)]
            res += [t for a, b in zip(bounds, bounds[1:])
                    if (t := _tight(fg, s["rmin"] + a, s["rmin"] + b - 1, s["cmin"], s["cmax"]))]
        else:
            res.append(s)
    return res


def find_cells(fg, h, w):
    """Pass 1 : rangées → blocs par bande → taille médiane.  Pass 2 : découpe les blocs incohérents."""
    min_area = int(h * w * 0.002)

    # Pass 1 — segmentation directe en cases
    row_bands = [b for b in _runs(fg.mean(axis=1) >= 0.02, h) if b[1] - b[0] > 40]
    cells = []
    for y0, y1 in row_bands:
        col_density = fg[y0:y1].mean(axis=0)
        for x0, x1 in _runs(col_density >= 0.02, w):
            if x1 - x0 < 40:
                continue
            t = _tight(fg, y0, y1 - 1, x0, x1 - 1)
            if t and _w(t) * _h(t) >= min_area:
                cells.append(t)
    if not cells:
        return []

    ref_w = float(np.median([_w(c) for c in cells]))
    ref_h = float(np.median([_h(c) for c in cells]))

    # Pass 2 — découpe les blocs trop grands (plusieurs scènes collées)
    out = []
    for c in cells:
        out += split_cell(c, fg, ref_w, ref_h)
    print(f"Cases : {len(cells)} blocs → {len(out)} après cohérence "
          f"(case médiane {ref_w:.0f}×{ref_h:.0f}px)")
    return out


def detect_icons(image_path: Path) -> int:
    img = Image.open(image_path).convert("RGBA")
    arr = np.array(img, dtype=np.uint8)
    h, w = arr.shape[:2]

    # Couleur de fond estimée depuis les 4 coins
    corners = np.array([arr[0,0,:3], arr[0,w-1,:3],
                        arr[h-1,0,:3], arr[h-1,w-1,:3]], dtype=float)
    bg = corners.mean(axis=0)
    print(f"Fond : {np.round(bg).astype(int).tolist()}")

    fg = np.any(np.abs(arr[:,:,:3].astype(float) - bg) >= BG_TOL, axis=2)

    regions = find_cells(fg, h, w)
    if not regions:
        print("Aucune icone trouvée. Vérifie BG_TOL.")
        return 0

    shields = [dict(cy=(r["rmin"] + r["rmax"]) / 2, cx=(r["cmin"] + r["cmax"]) / 2, **r)
               for r in regions]
    print(f"Icones détectées : {len(shields)}")

    shields.sort(key=lambda s: (s["cy"], s["cx"]))

    # Pour chaque icone : crop de l'art (+ label texte sous le dessin si présent).
    # On conserve la bbox de l'art (aw, ah) pour caler chaque icone individuellement.
    crops = []
    for shield in shields:
        x1 = max(0, shield["cmin"] - PAD)
        x2 = min(w, shield["cmax"] + PAD)
        y1 = max(0, shield["rmin"] - PAD)
        aw = shield["cmax"] - shield["cmin"]
        ah = shield["rmax"] - shield["rmin"]

        # Par défaut : crop de l'art seul
        y2 = min(h, shield["rmax"] + PAD)

        # Borne basse du scan = rmin de l'icone la plus proche en dessous ;
        # sinon une borne raisonnable sous l'art (jamais le bord de l'image)
        below = [s for s in shields if s["rmin"] > shield["rmax"] + 5]
        max_y = (min(s["rmin"] for s in below) - 5) if below \
            else min(h, shield["rmax"] + int(1.2 * ah))

        # N'étendre vers le bas que si un VRAI bloc de label (texte séparé par un
        # trou de lignes vides) existe sous le dessin → neutralise la sur-extension
        # sur les grilles sans légende, garde le label des feuilles qui en ont.
        scan_x1 = x1 - 20   # léger débordement horizontal pour le texte
        scan_x2 = x2 + 20
        min_gap = max(4, int(0.04 * ah))
        bottom = label_bottom(fg, scan_x1, scan_x2, shield["rmax"], max_y, min_gap)
        if bottom is not None:
            y2 = min(h, bottom + PAD)

        crops.append((x1, y1, x2, y2, aw, ah))

    out_dir = image_path.parent / "extracted icons"
    out_dir.mkdir(exist_ok=True)

    existing = [int(p.stem.split("_")[1]) for p in out_dir.glob("icon_*.png")
                if p.stem.split("_")[1].isdigit()]
    start_idx = max(existing, default=0) + 1

    # Session rembg unique réutilisée pour toutes les icones (modèle chargé 1 fois)
    from rembg import remove, new_session
    session = new_session()
    print("Détourage du fond (rembg)…")

    for idx, (x1, y1, x2, y2, aw, ah) in enumerate(crops, start=start_idx):
        crop = img.crop((x1, y1, x2, y2))
        # Détourage : retire le fond du crop → RGBA avec canal alpha transparent
        cutout = remove(crop, session=session)
        # Échelle par icone : l'art occupe FILL × OUT_SIZE, indépendamment des autres
        # icones et des autres feuilles → tailles de dessins homogènes.
        scale = (OUT_SIZE * FILL) / max(aw, ah)
        # Garde-fou : la crop complète (art + label éventuel) ne déborde pas du canvas
        scale = min(scale, OUT_SIZE / (x2 - x1), OUT_SIZE / (y2 - y1))
        nw = max(1, int(cutout.width  * scale))
        nh = max(1, int(cutout.height * scale))
        resized = cutout.resize((nw, nh), Image.LANCZOS)

        canvas = Image.new("RGBA", (OUT_SIZE, OUT_SIZE), OUT_BG)
        canvas.paste(resized, ((OUT_SIZE - nw) // 2, (OUT_SIZE - nh) // 2), resized)
        canvas.save(out_dir / f"icon_{idx:02d}.png", "PNG")
        print(f"  icon_{idx:02d}.png  ({x1},{y1})-({x2},{y2})  {x2-x1}×{y2-y1}px  ×{scale:.3f} → {nw}×{nh}px")

    print(f"\nTerminé — {len(shields)} icones → {out_dir}")
    return len(shields)


def main():
    if len(sys.argv) < 2:
        print("ERREUR : aucun fichier fourni.")
        sys.exit(1)
    path = Path(sys.argv[1])
    if not path.exists():
        print(f"ERREUR : {path}")
        sys.exit(1)
    print(f"Traitement : {path.name}")
    detect_icons(path)


if __name__ == "__main__":
    main()
