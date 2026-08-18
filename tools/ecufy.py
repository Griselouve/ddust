"""
ecufy.py — Retire le fond d'une image, l'entoure d'un écu héraldique doré
           délimité par deux filets bronze, sauvegarde en ecu_xxx.png.

Forme construite par 4 primitives géométriques exactes :
  1. Haut-gauche : arc de cercle (coin G → vallée G → pic central)
  2. Haut-droit  : arc de cercle (pic central → vallée D → coin D)
  3. Côtés       : segments verticaux
  4. Bas         : 2 courbes de Bézier quadratiques (tangente verticale à l'épaule)
"""

import sys
import io
import math
from pathlib import Path


# ---------------------------------------------------------------------------
# Primitives géométriques
# ---------------------------------------------------------------------------

def circumcenter(p1, p2, p3):
    """Centre (hx, hy) et rayon r du cercle circonscrit à 3 points."""
    ax, ay = p1;  bx, by = p2;  ex, ey = p3
    D = 2 * (ax*(by - ey) + bx*(ey - ay) + ex*(ay - by))
    if abs(D) < 1e-9:
        raise ValueError("Points collinéaires")
    a2 = ax*ax + ay*ay;  b2 = bx*bx + by*by;  e2 = ex*ex + ey*ey
    hx = (a2*(by - ey) + b2*(ey - ay) + e2*(ay - by)) / D
    hy = (a2*(ex - bx) + b2*(ax - ex) + e2*(bx - ax)) / D
    return hx, hy, math.hypot(ax - hx, ay - hy)


def quad_bez(p0, p1, p2, steps=30):
    """Bézier quadratique : p0 → p1(contrôle) → p2."""
    return [((1-t)**2*p0[0] + 2*(1-t)*t*p1[0] + t**2*p2[0],
             (1-t)**2*p0[1] + 2*(1-t)*t*p1[1] + t**2*p2[1])
            for t in [i/steps for i in range(steps + 1)]]


def arc_through_3pts(p_start, p_mid, p_end, steps=40):
    """
    Arc de cercle passant par p_start → p_mid → p_end dans cet ordre.
    Choisit automatiquement le sens (CW ou CCW) qui passe par p_mid.
    """
    hx, hy, r = circumcenter(p_start, p_mid, p_end)
    a0 = math.atan2(p_start[1] - hy, p_start[0] - hx)
    am = math.atan2(p_mid[1]   - hy, p_mid[0]   - hx)
    a1 = math.atan2(p_end[1]   - hy, p_end[0]   - hx)
    # Distance en CCW (math) de a0 vers am et a1
    dm = (am - a0) % (2*math.pi)
    de = (a1 - a0) % (2*math.pi)
    span = de if dm < de else de - 2*math.pi   # CCW si am avant a1, sinon CW
    return [(hx + r*math.cos(a0 + span*i/steps),
             hy + r*math.sin(a0 + span*i/steps))
            for i in range(steps + 1)]



# ---------------------------------------------------------------------------
# Forme de l'écu
# ---------------------------------------------------------------------------

def shield_polygon(cx, cy, w, h, peak_frac, valley_frac, point_frac):
    """
    Polygone de l'écu héraldique.

    Paramètres (fractions de w) :
      peak_frac   : hauteur du pic central au-dessus des coins (~0.12)
      valley_frac : profondeur des vallées sous les coins (~0.06)
      point_frac  : hauteur de la pointe basse (~0.38)

    Coordonnées :
      y_peak   : très haut (pic central)
      y_coin   : niveau des coins gauche/droit (= y_peak + peak_frac*w)
      y_epaule : jonction corps / pointe
      y_tip    : pointe basse
    """
    peak_h   = w * peak_frac
    valley_d = w * valley_frac
    point_h  = w * point_frac
    body_h   = max(1.0, h - peak_h - point_h)

    x0 = cx - w / 2
    x1 = cx + w / 2

    y_peak   = cy - h / 2
    y_coin   = y_peak + peak_h
    y_epaule = y_coin + body_h
    # y_tip  = cy + h / 2  (point bas, atteint par les arcs)

    # --- Bord supérieur : 2 arcs de cercle via 3 points ---
    left_corner  = (x0,        y_coin)
    right_corner = (x1,        y_coin)
    top_peak     = (cx,        y_peak)
    left_valley  = (cx - w/4,  y_coin + valley_d)
    right_valley = (cx + w/4,  y_coin + valley_d)

    left_arc  = arc_through_3pts(left_corner,  left_valley,  top_peak,      steps=40)
    right_arc = arc_through_3pts(top_peak,     right_valley, right_corner,  steps=40)

    # --- Pointe basse : Bézier quadratique ---
    # Point de contrôle directement SOUS l'épaule (même x) → tangente verticale
    # garantie au raccord avec le côté droit, pointe naturellement arrondie.
    # ctrl_frac : 0 = triangle pur, 1 = très arrondi (0.25 ≈ bouclier classique)
    ctrl_frac = 0.25
    y_tip     = cy + h / 2
    ctrl_y    = y_epaule + ctrl_frac * point_h

    right_fwd    = quad_bez((x1, y_epaule), (x1, ctrl_y), (cx, y_tip), steps=30)
    left_fwd     = quad_bez((x0, y_epaule), (x0, ctrl_y), (cx, y_tip), steps=30)
    right_bottom = right_fwd
    left_bottom  = list(reversed(left_fwd))

    # --- Assemblage dans l'ordre (sens horaire vue PIL) ---
    #   left_arc[:-1]  : coin G → ... (pic exclu, évite doublon)
    #   right_arc      : pic → coin D
    #   right_bottom   : épaule D → pointe (segment droit)
    #   left_bottom    : pointe → épaule G (segment droit)
    #   PIL ferme      : épaule G → coin G (segment auto = côté gauche)
    poly  = left_arc[:-1]
    poly += right_arc
    poly += right_bottom        # (x1,y_coin)→(x1,y_epaule) [côté droit] + Bézier → pointe
    poly += left_bottom[1:]     # pointe → (x0,y_epaule) [Bézier] ; skip doublon pointe
    # PIL ferme : (x0,y_epaule) → (x0,y_coin) [côté gauche, segment auto]
    return poly


# ---------------------------------------------------------------------------
# Traitement principal
# ---------------------------------------------------------------------------

def ecufy(input_path: Path) -> Path:
    from rembg import remove
    from PIL import Image, ImageDraw

    with open(input_path, "rb") as f:
        data = f.read()
    result = remove(data)
    image  = Image.open(io.BytesIO(result)).convert("RGBA")
    W, H   = image.size

    # Paramètres de forme (en pixels, proportionnels à W)
    peak_h   = max(20, int(W * 0.12))   # hauteur du pic central au-dessus des coins
    valley_d = max(10, int(W * 0.06))   # profondeur des vallées
    point_h  = max(30, int(W * 0.38))   # hauteur de la pointe basse

    peak_frac   = peak_h   / W
    valley_frac = valley_d / W
    point_frac  = point_h  / W

    # Écu réduit à 75% : l'image déborde par-dessus l'écu
    inner_w = float(W) * 0.40
    inner_h = float(H + peak_h + point_h) * 0.40

    # Épaisseurs des anneaux
    thickness = max(48, int(W * 0.07))
    bt        = max(9,  int(thickness * 0.20))

    outer_w   = inner_w + 2 * thickness
    outer_h   = inner_h + 2 * thickness
    outmost_w = outer_w + 2 * bt
    outmost_h = outer_h + 2 * bt

    # Taille du canvas : assez grand pour le polygone ET pour l'image qui déborde
    test_pts = shield_polygon(0, 0, outmost_w, outmost_h,
                              peak_frac, valley_frac, point_frac)
    xs = [p[0] for p in test_pts];  ys = [p[1] for p in test_pts]
    margin   = 15
    canvas_w = max(int(max(xs) - min(xs)), W) + 2 * margin
    canvas_h = max(int(max(ys) - min(ys)), H) + 2 * margin

    # Supersampling 4× pour l'antialiasing
    scale = 4
    big_w = canvas_w * scale
    big_h = canvas_h * scale
    bcx   = big_w // 2
    bcy   = big_h // 2

    big_canvas = Image.new("RGBA", (big_w, big_h), (0, 0, 0, 0))

    # Écu dessiné EN PREMIER (derrière l'image)
    def draw_ring(wo, ho, wi, hi, color):
        mask = Image.new("L", (big_w, big_h), 0)
        dm   = ImageDraw.Draw(mask)
        dm.polygon(
            shield_polygon(bcx, bcy, wo*scale, ho*scale,
                           peak_frac, valley_frac, point_frac),
            fill=255)
        dm.polygon(
            shield_polygon(bcx, bcy, wi*scale, hi*scale,
                           peak_frac, valley_frac, point_frac),
            fill=0)
        layer = Image.new("RGBA", (big_w, big_h), color)
        layer.putalpha(mask)
        nonlocal big_canvas
        big_canvas = Image.alpha_composite(big_canvas, layer)

    gold   = (218, 165, 32, 255)
    bronze = (176, 115, 40, 255)

    draw_ring(outer_w,   outer_h,   inner_w,          inner_h,          gold)
    draw_ring(outmost_w, outmost_h, outer_w,          outer_h,          bronze)
    draw_ring(inner_w,   inner_h,   inner_w - 2*bt,   inner_h - 2*bt,   bronze)

    # Image collée PAR-DESSUS l'écu, centrée sur le canvas
    big_img   = image.resize((W * scale, H * scale), Image.LANCZOS)
    img_layer = Image.new("RGBA", (big_w, big_h), (0, 0, 0, 0))
    img_layer.paste(big_img, (bcx - (W * scale) // 2, bcy - (H * scale) // 2), big_img)
    big_canvas = Image.alpha_composite(big_canvas, img_layer)

    final = big_canvas.resize((canvas_w, canvas_h), Image.LANCZOS)
    output_path = input_path.parent / ("ecu_" + input_path.stem + ".png")
    final.save(output_path, "PNG")
    return output_path


# ---------------------------------------------------------------------------

def main():
    import traceback
    if len(sys.argv) < 2:
        print("ERREUR : aucun fichier fourni.")
        sys.exit(1)
    input_path = Path(sys.argv[1])
    if not input_path.exists():
        print(f"ERREUR : fichier introuvable : {input_path}")
        sys.exit(1)
    print(f"Traitement de : {input_path.name} ...")
    try:
        output_path = ecufy(input_path)
        print(f"Enregistre : {output_path}")
    except Exception:
        print("\n--- ERREUR ---")
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
