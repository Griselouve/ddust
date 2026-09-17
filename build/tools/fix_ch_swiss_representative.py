#!/usr/bin/env python3
"""Pose au §1 de la politique adulte `ch` la mention du représentant en Suisse.

Joué le 2026-09-16. L'art. 14 al. 1 LPD impose à un responsable établi à
l'étranger de désigner un représentant en Suisse, mais seulement si quatre
conditions sont CUMULATIVEMENT réunies. Arbitrage : on n'en désigne pas, et on le
dit, avec la raison, plutôt que de laisser le silence au fond du corpus.

⚠ LES TEXTES NE SONT PAS ICI. Ils vivent dans `derive_market_corpus._CH_REPRESENTANT`,
  appliqués par `_ch_blocks`. Ce script ne fait que RATTRAPER les huit politiques
  déjà sur disque, que la dérivation refuse d'écraser. Même montage que
  `fix_ch_mediation_intro.py`, et pour la même raison : il faut les deux.

⚠ AUCUN BUMP DE VERSION : l'application n'a jamais été publiée, personne n'a
  accepté ces documents.

    python tools/fix_ch_swiss_representative.py            # écrit
    python tools/fix_ch_swiss_representative.py --check    # vérifie sans écrire

⚠ SCRIPT À USAGE UNIQUE. L'ancre (fin du §1) survit à la substitution, donc le
  rejeu est bloqué autrement : un document qui porte déjà le paragraphe est refusé.
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from derive_market_corpus import (  # noqa: E402
    DOCS, LANGS, _CH_REPRESENTANT, _CH_REPRESENTANT_SRC, _as_pattern,
)

MARCHE = "ch"


def main():
    check = "--check" in sys.argv
    n = 0

    for lang in LANGS:
        path = DOCS / ("%s-a-%s-privacy-v1.html" % (MARCHE, lang))
        if not path.exists():
            raise SystemExit("introuvable : %s" % path)
        text = path.read_text(encoding="utf-8")

        if "art. 14" in text or "Article 14 FADP" in text:
            raise SystemExit("[%s] mention de l'art. 14 déjà présente : script déjà joué ?" % path.name)

        remplacement = (_CH_REPRESENTANT_SRC[lang] + "\n" + _CH_REPRESENTANT[lang]).replace("\\", "\\\\")
        text, hits = re.subn(_as_pattern(_CH_REPRESENTANT_SRC[lang]), remplacement, text)
        if hits != 1:
            raise SystemExit(
                "[%s] fin du §1 : %d occurrence(s), 1 attendue." % (path.name, hits))

        if not check:
            path.write_text(text, encoding="utf-8")
        n += 1

    verb = "verifie(s)" if check else "ecrit(s)"
    print("%d fichier(s) %s - politiques adultes du marche %s, %d langues."
          % (n, verb, MARCHE, len(LANGS)))
    print("  Aucun representant designe (art. 14 LPD) : ni grande ampleur, ni risque eleve.")


if __name__ == "__main__":
    main()
