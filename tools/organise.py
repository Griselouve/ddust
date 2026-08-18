"""
organise.py — Deplace un fichier vers un repertoire cible en le renommant
              dans la serie "P" (copies) de la base la plus elevee.

Le repertoire cible contient des fichiers d'une serie lettree, p.ex. :
    icon_35_C_01.png  icon_35_C_02.png  icon_35_C_03.png
(il n'y a plus forcement de icon_35.png, mais on reconnait "35" via ces
fichiers). Le script :

  1. repere la base au plus grand numero  -> base   (ex: icon_35)
  2. determine le prochain numero de la serie "P" pour cette base
  3. deplace le fichier fourni dans le repertoire cible en le renommant
     icon_35_P_01.png, icon_35_P_02.png, ...  (le marqueur "P" distingue
     les fichiers deplaces des fichiers deja presents).

Appel : python organise.py <repertoire_cible> <fichier_source>
Le .bat appelle ce script une fois par fichier selectionne ; comme chaque
appel relit le repertoire cible, la numerotation s'incremente naturellement.
"""

import re
import sys
import shutil
from pathlib import Path

# Marqueur des fichiers deplaces par cet outil.
COPY_TAG = "P"

# icon_35_C_01.png -> prefix="icon", num="35", tag="C", seq="01"
SERIES_RE = re.compile(
    r"^(?P<prefix>.+)_(?P<num>\d+)_(?P<tag>[A-Za-z]+)_(?P<seq>\d+)\.(?P<ext>\w+)$"
)


def find_base(target_dir: Path):
    """Retourne (nom_de_base, ext) de la serie au plus grand numero.

    Le tri se fait sur la VALEUR numerique (icon_216 > icon_99), pas sur
    l'ordre alphabetique brut qui casse avec un padding incoherent.
    """
    best = None  # (valeur, base, ext)
    for f in target_dir.iterdir():
        if not f.is_file():
            continue
        m = SERIES_RE.match(f.name)
        if not m:
            continue
        value = int(m.group("num"))
        base = f"{m.group('prefix')}_{m.group('num')}"
        if best is None or value > best[0]:
            best = (value, base, m.group("ext"))
    if best is None:
        return None, None
    return best[1], best[2]


def next_seq(target_dir: Path, base: str, tag: str) -> int:
    """Prochain numero de la serie <base>_<tag>_NN (ex: icon_35_P_04 -> 5)."""
    prefix = re.escape(f"{base}_{tag}")
    pat = re.compile(rf"^{prefix}_(\d+)\.\w+$")
    highest = 0
    for f in target_dir.iterdir():
        if not f.is_file():
            continue
        m = pat.match(f.name)
        if m:
            highest = max(highest, int(m.group(1)))
    return highest + 1


def organise(target_dir: Path, source: Path) -> Path:
    base, ext = find_base(target_dir)
    if base is None:
        print(
            f"ERREUR : aucun fichier de serie (icon_NN_X_NN) dans {target_dir}"
        )
        sys.exit(1)

    seq = next_seq(target_dir, base, COPY_TAG)
    # On conserve l'extension de la serie cible (celle des icones).
    dest = target_dir / f"{base}_{COPY_TAG}_{seq:02d}.{ext}"
    # Securite anti-collision (ne devrait pas arriver, mais on protege).
    while dest.exists():
        seq += 1
        dest = target_dir / f"{base}_{COPY_TAG}_{seq:02d}.{ext}"

    shutil.move(str(source), str(dest))
    return dest


def main():
    if len(sys.argv) < 3:
        print("Usage : python organise.py <repertoire_cible> <fichier_source>")
        sys.exit(1)

    target_dir = Path(sys.argv[1])
    source = Path(sys.argv[2])

    if not target_dir.is_dir():
        print(f"ERREUR : repertoire cible introuvable : {target_dir}")
        sys.exit(1)
    if not source.is_file():
        print(f"ERREUR : fichier source introuvable : {source}")
        sys.exit(1)

    dest = organise(target_dir, source)
    print(f"Deplace : {source.name}  ->  {dest.name}")


if __name__ == "__main__":
    main()
