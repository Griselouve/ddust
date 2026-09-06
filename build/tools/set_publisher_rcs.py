#!/usr/bin/env python3
"""Complète l'identification de l'éditeur par la mention RCS, dans le corpus et sur le site.

Troisième et dernier passage sur l'identité, joué le 2026-09-03 quelques minutes
après `set_publisher_siren.py` — parce que l'extrait Kbis est arrivé entre les
deux et qu'il porte une information que le SIREN seul ne donne pas.

⚠ POURQUOI LE SIREN SEUL NE SUFFISAIT PAS. L'article R123-237 du code de commerce
  n'exige pas « un numéro » : il exige, pour une personne IMMATRICULÉE AU RCS, le
  **numéro d'immatriculation suivi de la mention RCS et du nom de la ville du
  greffe**. L'activité ayant été déclarée commerciale, l'immatriculation est bien
  au RCS — greffe du tribunal de commerce de **Pontoise**, extrait du 02/09/2026.
  Écrire « SIREN 109354092 » seul était donc une mention incomplète, pas fausse.

    Immatriculation au RCS, numéro   109 354 092 R.C.S. Pontoise
    Date d'immatriculation           02/09/2026

⚠ CE QUI RESTE ABSENT, ET LE RESTE VOLONTAIREMENT :
    - le **SIRET** — il ne figure PAS sur le Kbis (c'est une donnée INSEE, pas
      greffe) et se lit sur l'avis de situation SIRENE. R123-237 ne le demande pas ;
    - le **n° de TVA intracommunautaire** — il n'existe pas encore (demande au SIE,
      plan §2.1). Un numéro de TVA plausible mais faux serait pire que son absence.
  Les deux sont tracés dans `grisloup/docs/plan-creation-micro-entreprise.md`
  §5.2. Ils n'appellent qu'un ajout de ligne aux
  mentions légales du site, pas une nouvelle passe sur les 72 documents : le corpus
  n'a pas à porter un numéro de TVA que l'entreprise ne facture pas.

⚠ TOUJOURS AUCUN BUMP DE VERSION, même arbitrage qu'au second passage : la partie
  au traitement ne change pas, seule son identification se complète. Les fichiers
  restent en `v1`. Cf. `stores/google/dpa.md` §3, qui porte le raisonnement.

    python tools/set_publisher_rcs.py            # écrit
    python tools/set_publisher_rcs.py --check    # vérifie sans écrire

⚠ SCRIPT À USAGE UNIQUE, même contrat que ses aînés : une substitution qui ne
  trouve pas EXACTEMENT une occurrence est une erreur, jamais un silence.
"""

import re
import sys
from pathlib import Path

BUILD = Path(__file__).parent.parent
DOCS = BUILD / "legal" / "documents"
SITE = BUILD / "hosting" / "web"

SIREN = "109354092"
GREFFE = "Pontoise"

# L'ancre est ce que `set_publisher_siren.py` a écrit une heure plus tôt : présente
# une fois et une seule dans chacun des 75 fichiers, quelle que soit la forme de
# phrase. On la complète plutôt que de la remplacer — le SIREN reste lisible seul
# pour qui le cherche, et la mention légale devient complète.
ANCRE = f"SIREN {SIREN}"
COMPLETE = f"SIREN {SIREN}, RCS {GREFFE}"

MARCHES = ("fr", "euo", "eus", "eun", "eux", "uk", "ch",
           "us", "ca", "oceanie", "bresil", "hispam")
LANGS = ("fr", "en", "es")


def _cibles():
    for marche in MARCHES:
        for lang in LANGS:
            for kind in ("cgu", "privacy"):
                yield DOCS / f"{marche}-a-{lang}-{kind}-v1.html"
    for lang in LANGS:
        yield SITE / lang / "legal" / "index.html"


def _as_pattern(literal):
    return r"\s+".join(re.escape(w) for w in literal.split())


def main():
    check = "--check" in sys.argv
    n = 0

    for path in _cibles():
        if not path.exists():
            raise SystemExit(f"introuvable : {path}")
        text = path.read_text(encoding="utf-8")
        text, hits = re.subn(_as_pattern(ANCRE), COMPLETE, text)
        if hits != 1:
            raise SystemExit(
                f"[{path.name}] « {ANCRE} » : {hits} occurrence(s), 1 attendue."
            )
        if not check:
            path.write_text(text, encoding="utf-8")
        n += 1

    verb = "verifie(s)" if check else "ecrit(s)"
    print(f"{n} fichier(s) {verb} — 72 documents adultes + 3 pages du site.")
    print(f"  {COMPLETE} — extrait du 02/09/2026, greffe de {GREFFE}.")
    print("  SIRET et TVA intracom : toujours non attribues"
          " -> plan-creation-micro-entreprise.md 5.2.")


if __name__ == "__main__":
    main()
