#!/usr/bin/env python3
"""Corrige une coquille du §10 des CGU adultes ANGLAISES : « defects. publisher strives ».

⚠ CE QU'ELLE ÉTAIT. Le §10 anglais disait « the service may contain defects.
  publisher strives to keep the service available » : l'article manquait devant le
  sujet. Trouvée le 2026-09-08 en relisant la souche `us` avant d'en tirer les
  quatre traductions neuves.

⚠ ELLE TOUCHAIT LES DOUZE MARCHÉS, et c'est la leçon. On l'a d'abord crue propre à
  la souche américaine ; elle était dans les DEUX souches, `fr` comme `us`, et les
  dix marchés dérivés l'avaient héritée telle quelle — la dérivation recopie le
  texte qu'on lui donne, y compris ses défauts. Une faute dans une souche se paie
  douze fois.
  ⚠ Elle ne touche QUE l'anglais : les six autres langues ont été rédigées
    séparément et portent leur sujet.

⚠ AUCUN BUMP DE VERSION, et c'est le même arbitrage que `set_publisher_siren.py`.
  Un article manquant ne modifie ni un droit, ni une obligation, ni le sens de la
  clause : la responsabilité de l'éditeur y est décrite à l'identique avant et
  après. Re-notifier les inscrits de la beta pour trois lettres coûterait plus que
  ça ne les protège. Les fichiers restent en `v1` et sont corrigés sur place.
  ⚠ LA LIGNE DE PARTAGE À TENIR : un changement de FOND, lui, se bumpe.

    python tools/fix_en_publisher_typo.py            # écrit
    python tools/fix_en_publisher_typo.py --check    # vérifie sans écrire

⚠ SCRIPT À USAGE UNIQUE, même contrat que ses aînés : une substitution qui ne
  trouve pas EXACTEMENT une occurrence est une erreur, jamais un silence. Une fois
  joué, il ne retrouve plus son motif et échoue — c'est ainsi qu'on le sait joué.
"""

import re
import sys
from pathlib import Path

DOCS = Path(__file__).parent.parent / "legal" / "documents"

MARCHES = ("fr", "euo", "eus", "eun", "eux", "uk", "ch",
           "us", "ca", "oceanie", "bresil", "hispam")

# ⚠ Le motif tolère le retour à la ligne : le corpus est enregistré en lignes
#   courtes, et la coupure ne tombe pas au même endroit d'un marché à l'autre.
ANCRE = "defects. publisher strives to keep the service available"
CORRIGE = "defects. The publisher strives to keep the service available"


def _motif(litteral):
    return r"\s+".join(re.escape(mot) for mot in litteral.split())


def main():
    check = "--check" in sys.argv
    n = 0
    for marche in MARCHES:
        path = DOCS / ("%s-a-en-cgu-v1.html" % marche)
        if not path.exists():
            raise SystemExit("introuvable : %s" % path)
        texte = path.read_text(encoding="utf-8")
        texte, hits = re.subn(_motif(ANCRE), CORRIGE, texte)
        if hits != 1:
            raise SystemExit(
                "[%s] « %s » : %d occurrence(s), 1 attendue." % (path.name, ANCRE, hits))
        if not check:
            path.write_text(texte, encoding="utf-8")
        n += 1

    print("%d fichier(s) %s — les 12 CGU adultes anglaises."
          % (n, "verifie(s)" if check else "corrige(s)"))
    print("  Aucun bump : la clause dit la meme chose, mieux.")


if __name__ == "__main__":
    main()
