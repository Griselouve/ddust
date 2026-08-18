"""
Split task icons v2: 2048x2048, black background, 4 rows (4+5+5+5 = 19 icons).
Auto-clusters shields into rows via cy-gap detection.
"""
from PIL import Image
import numpy as np
from scipy import ndimage
import os

SRC = r'E:\Deva\projects\suites\ddust\material\divers_materiel\icons\Gemini_Generated_Image_3lbce43lbce43lbc.png'
OUT = r'E:\Deva\projects\suites\ddust\material\divers_materiel\icons'

LABELS = [
    # row 0 (4)
    'salon', 'chambre_parentale', 'chambre_enfant', 'cuisine',
    # row 1 (5)
    'repas', 'salle_de_bain', 'toilettes', 'couloir', 'entree',
    # row 2 (5)
    'terrasse', 'balcon', 'jardin', 'linge', 'dechets',
    # row 3 (5)
    'animaux', 'garage', 'routine', 'courses', 'extras',
]
ROW_SIZES = [4, 5, 5, 5]
N_ROWS    = 4
TOTAL     = 19

BG_TOL   = 25    # conservative: black bg, some icons have dark frames
DILATION = 5
MIN_AREA = 40000
PADDING  = 50
GAP_MARGIN = 6


def remove_border_bg(arr, tol):
    h, w = arr.shape[:2]
    corners = np.array([arr[0,0,:3], arr[0,w-1,:3], arr[h-1,0,:3], arr[h-1,w-1,:3]], dtype=float)
    bg = corners.mean(axis=0)
    diff = np.abs(arr[:,:,:3].astype(float) - bg)
    near_bg = np.all(diff < tol, axis=2)
    labeled, _ = ndimage.label(near_bg)
    border_labels = set()
    border_labels.update(labeled[0, :].tolist())
    border_labels.update(labeled[-1, :].tolist())
    border_labels.update(labeled[:, 0].tolist())
    border_labels.update(labeled[:, -1].tolist())
    border_labels.discard(0)
    mask = np.zeros((h, w), dtype=bool)
    for lbl in border_labels:
        mask |= (labeled == lbl)
    result = arr.copy()
    result[mask, 3] = 0
    return result


def find_text_start(arr, bg, tol, x1, x2, art_bottom, row_end, min_run=3):
    """Scan DOWN from art_bottom to find where text label starts (first dense-row run)."""
    x1c, x2c = max(0, x1), min(arr.shape[1], x2)
    cell_w = x2c - x1c
    if cell_w <= 0 or art_bottom >= row_end:
        return row_end
    region = arr[art_bottom:row_end, x1c:x2c, :3].astype(float)
    is_fg  = np.any(np.abs(region - bg) >= tol, axis=2)
    counts = is_fg.sum(axis=1)
    thresh = max(4.0, cell_w * 0.02)
    n = len(counts)
    for i in range(n - min_run + 1):
        if all(counts[i+j] >= thresh for j in range(min_run)):
            return art_bottom + i
    return row_end


def detect_text_bottom(arr, bg, tol, x1, x2, text_top, max_scan=100):
    """Scan downward from text_top to find where the text label ends."""
    x1c, x2c = max(0, x1), min(arr.shape[1], x2)
    cell_w = x2c - x1c
    scan_end = min(arr.shape[0], text_top + max_scan)
    if cell_w <= 0 or text_top >= scan_end:
        return text_top

    region = arr[text_top:scan_end, x1c:x2c, :3].astype(float)
    is_fg  = np.any(np.abs(region - bg) >= tol, axis=2)
    counts = is_fg.sum(axis=1)
    thresh = max(4.0, cell_w * 0.02)

    last_fg = -1
    for i, c in enumerate(counts):
        if c >= thresh:
            last_fg = i

    return text_top + last_fg + 1 if last_fg >= 0 else text_top


def detect_text_top(arr, bg, tol, x1, x2, row_y_start, row_h):
    """Scan bottom 25% of row upward to find the top of the text label."""
    x1c, x2c = max(0, x1), min(arr.shape[1], x2)
    cell_w = x2c - x1c
    if cell_w <= 0:
        return row_y_start + int(row_h * 0.92)

    scan_start = row_y_start + int(row_h * 0.75)
    scan_end   = row_y_start + row_h

    region = arr[scan_start:scan_end, x1c:x2c, :3].astype(float)
    is_fg  = np.any(np.abs(region - bg) >= tol, axis=2)
    counts = is_fg.sum(axis=1)

    thresh = max(4.0, cell_w * 0.02)
    n = len(counts)
    in_text, text_top_local = False, None

    for i in range(n - 1, -1, -1):
        if counts[i] >= thresh:
            in_text = True
            text_top_local = i
        elif in_text:
            break

    if text_top_local is not None:
        result = scan_start + text_top_local
        floor  = row_y_start + int(row_h * 0.80)
        return max(result, floor)

    return row_y_start + int(row_h * 0.92)


def cluster_rows(shields, n_rows):
    """Assign each shield to a row index via largest cy gaps."""
    cy = [s['cy'] for s in shields]
    order = sorted(range(len(cy)), key=lambda i: cy[i])
    sorted_cy = [cy[i] for i in order]

    # Find n_rows-1 largest consecutive gaps
    gaps = sorted(
        [(sorted_cy[i+1] - sorted_cy[i], i) for i in range(len(sorted_cy)-1)],
        reverse=True
    )
    split_points = sorted(idx for _, idx in gaps[:n_rows-1])
    boundaries = [(sorted_cy[p] + sorted_cy[p+1]) / 2 for p in split_points]

    for s in shields:
        s['row'] = sum(1 for b in boundaries if s['cy'] >= b)


def main():
    img = Image.open(SRC).convert('RGBA')
    arr = np.array(img, dtype=np.uint8)
    h, w = arr.shape[:2]
    print(f"Image: {w}x{h}")

    corners = np.array([arr[0,0,:3], arr[0,w-1,:3], arr[h-1,0,:3], arr[h-1,w-1,:3]], dtype=float)
    bg = corners.mean(axis=0)
    print(f"Background: {np.round(bg).astype(int).tolist()}")

    is_fg  = np.any(np.abs(arr[:,:,:3].astype(float) - bg) >= BG_TOL, axis=2)
    is_fgd = ndimage.binary_dilation(is_fg, iterations=DILATION)
    labeled, num = ndimage.label(is_fgd)
    slices = ndimage.find_objects(labeled)
    print(f"Raw components: {num}")

    shields = []
    for i, slc in enumerate(slices):
        if slc is None:
            continue
        lbl  = i + 1
        size = (labeled[slc] == lbl).sum()
        if size < MIN_AREA:
            continue
        rmin, rmax = slc[0].start, slc[0].stop - 1
        cmin, cmax = slc[1].start, slc[1].stop - 1
        shields.append({'cy': (rmin+rmax)/2, 'cx': (cmin+cmax)/2,
                        'rmin': rmin, 'rmax': rmax,
                        'cmin': cmin, 'cmax': cmax})

    print(f"Shields detected: {len(shields)}")

    if len(shields) != TOTAL:
        print(f"ERROR: expected {TOTAL}, got {len(shields)}. Tune MIN_AREA or BG_TOL.")
        # Print sizes for debugging
        all_sizes = sorted([(labeled[slc] == i+1).sum() for i, slc in enumerate(slices) if slc is not None], reverse=True)
        print(f"  Top-25 component sizes: {all_sizes[:25]}")
        return

    # Cluster into rows, then sort each row by cx
    cluster_rows(shields, N_ROWS)
    shields.sort(key=lambda s: (s['row'], s['cx']))

    # Compute per-row approximate row_h and row_top from detected positions
    row_h = h // N_ROWS   # 512 for 2048px

    # Row start positions (top y of each row)
    row_tops = {}
    for r in range(N_ROWS):
        row_shields = [s for s in shields if s['row'] == r]
        row_tops[r] = min(s['rmin'] for s in row_shields) - PADDING
        row_tops[r] = max(0, row_tops[r])

    # Compute actual row boundaries from detected shield extents
    row_groups = [sorted([s for s in shields if s['row'] == r], key=lambda s: s['cx'])
                  for r in range(N_ROWS)]

    # Phase 1: find text_top + text_bottom for each shield (rough row bounds)
    rough_rh = h // N_ROWS
    shield_text_bottom = {}
    for r in range(N_ROWS):
        rough_top = r * rough_rh
        for s in row_groups[r]:
            xs1 = max(0, s['cmin'] - PADDING)
            xs2 = min(w, s['cmax'] + PADDING + 1)
            tt = detect_text_top(arr, bg, BG_TOL, xs1, xs2, rough_top, rough_rh)
            tb = detect_text_bottom(arr, bg, BG_TOL, xs1, xs2, tt, max_scan=120)
            shield_text_bottom[id(s)] = tb

    # Phase 2: row tops = just after the furthest text of the previous row
    row_tops = [0]
    for r in range(N_ROWS - 1):
        max_tb   = max(shield_text_bottom[id(s)] for s in row_groups[r])
        min_rmin = min(s['rmin'] for s in row_groups[r + 1])
        # Use midpoint but guarantee we clear all text from previous row
        row_tops.append(max(max_tb + 5, (max_tb + min_rmin) // 2))
    row_tops.append(h)

    row_heights = [row_tops[r+1] - row_tops[r] for r in range(N_ROWS)]
    print(f"\nRow boundaries: {row_tops}")
    print(f"Row heights:    {row_heights}\n")

    label_idx = 0
    for r in range(N_ROWS):
        row_shields = row_groups[r]
        expected = ROW_SIZES[r]
        if len(row_shields) != expected:
            print(f"WARNING row {r}: expected {expected} icons, got {len(row_shields)}")

        row_top = row_tops[r]
        rh      = row_heights[r]

        for col_idx, s in enumerate(row_shields):
            label = LABELS[label_idx]
            label_idx += 1

            # Adaptive x padding
            left_edge  = row_shields[col_idx-1]['cmax'] if col_idx > 0 else 0
            right_edge = row_shields[col_idx+1]['cmin'] if col_idx < len(row_shields)-1 else w

            left_pad  = max(0, min(PADDING, s['cmin'] - left_edge  - GAP_MARGIN))
            right_pad = max(0, min(PADDING, right_edge - s['cmax'] - GAP_MARGIN))

            x1 = max(0, s['cmin'] - left_pad)
            x2 = min(w, s['cmax'] + right_pad + 1)

            # Y top: never above actual row boundary
            y1 = max(row_top, s['rmin'] - PADDING)

            # Y bottom: take the most conservative of two independent text detections
            row_end   = row_tops[r + 1]
            # 1) scan DOWN from art bottom (catches text just below rmax)
            tt_down = find_text_start(arr, bg, BG_TOL, x1, x2, s['rmax'], row_end)
            # 2) scan UP from row bottom (catches text even when rmax is inflated)
            tt_up   = detect_text_top(arr, bg, BG_TOL, x1, x2, row_top, rh)
            text_top = min(tt_down, tt_up)
            y2 = min(text_top, s['rmax'] + PADDING + 1)

            crop = arr[y1:y2, x1:x2].copy()
            crop = remove_border_bg(crop, BG_TOL)

            out_path = os.path.join(OUT, f'task_{label}.png')
            Image.fromarray(crop).save(out_path)
            print(f"  {label}: lpad={left_pad} rpad={right_pad} text_top={text_top} "
                  f"crop=({x1},{y1})-({x2},{y2}) {x2-x1}x{y2-y1}px")

    print(f"\nDone. {TOTAL} icons -> {OUT}")


if __name__ == '__main__':
    main()
