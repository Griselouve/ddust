#!/usr/bin/env python3
"""Le kit presse nommait l'éditeur par son DOMAINE. Il le nomme par son nom commercial.

⚠ CE QUI ÉTAIT ÉCRIT. Les pages presse et la fiche presse annonçaient
  « Développeur : grisloup.com ». C'est le domaine, pas le nom. Le nom commercial
  déclaré au RNE et confirmé sur l'extrait Kbis est **Grisloup** — un seul mot,
  une majuscule, pas d'extension. C'est ce que `build.yml → publisher.trade_name`
  porte depuis le 2026-09-03, et ce que les 168 documents légaux adultes écrivent
  depuis le 2026-08-31.

⚠ POURQUOI CE N'EST PAS UN DÉTAIL. `build.yml` porte l'avertissement en toutes
  lettres : « SURTOUT PAS grisloup.com ICI : c'est le nom commercial, il vit dans
  `trade_name`. L'écart avec la pièce justificative est une cause classique de
  blocage. » La règle de nommage du portefeuille tient sur tous les fronts —
  D-U-N-S, profil de paiement Google, banque, corpus légal, site. Le kit presse
  était le dernier endroit à ne pas la suivre : il n'avait pas été repris le
  2026-09-03 avec les pages légales, parce qu'il n'est pas une mention légale.

⚠ CE QUI RESTE `grisloup.com`, ET DOIT LE RESTER : le domaine, partout où c'est
  un domaine — la ligne « Site », les liens, `donjons.grisloup.com`. Ce script ne
  touche QUE la ligne qui nomme l'éditeur.

⚠ AUCUN DOCUMENT LÉGAL N'EST CONCERNÉ : ils écrivent déjà « Grisloup ». Vérifié
  sur les 336 avant d'écrire ce script.

    python tools/set_publisher_press_name.py            # écrit
    python tools/set_publisher_press_name.py --check    # vérifie sans écrire

⚠ SCRIPT À USAGE UNIQUE, même contrat que ses aînés : une substitution qui ne
  trouve pas EXACTEMENT une occurrence est une erreur, jamais un silence.
"""

import sys
from pathlib import Path

BUILD = Path(__file__).parent.parent
SITE = BUILD / "hosting" / "web"
FICHE = SITE / "assets" / "press" / "ddust-factsheet.txt"

LANGS = ("fr", "en", "es", "it", "de", "pt", "nl")

# Pages presse : la ligne « Développeur » de la liste des faits clés.
# La clef change de langue en langue, la valeur non — d'où une source par langue.
PAGES = {
    "fr": ("<span>grisloup.com — développeur indépendant solo (France)</span>",
           "<span>Grisloup — développeur indépendant solo (France)</span>"),
    "en": ("<span>grisloup.com — solo independent developer (France)</span>",
           "<span>Grisloup — solo independent developer (France)</span>"),
    "es": ("<span>grisloup.com — desarrollador independiente en solitario (Francia)</span>",
           "<span>Grisloup — desarrollador independiente en solitario (Francia)</span>"),
    "it": ("<span>grisloup.com — sviluppatore indipendente solo (Francia)</span>",
           "<span>Grisloup — sviluppatore indipendente solo (Francia)</span>"),
    "de": ("<span>grisloup.com — unabhängiger Solo-Entwickler (Frankreich)</span>",
           "<span>Grisloup — unabhängiger Solo-Entwickler (Frankreich)</span>"),
    "pt": ("<span>grisloup.com — programador independente a solo (França)</span>",
           "<span>Grisloup — programador independente a solo (França)</span>"),
    "nl": ("<span>grisloup.com — onafhankelijke solo-ontwikkelaar (Frankrijk)</span>",
           "<span>Grisloup — onafhankelijke solo-ontwikkelaar (Frankrijk)</span>"),
}

# Fiche presse : sept sections, une par langue. Les valeurs y sont alignées en
# colonne — le remplacement raccourcit la ligne de quatre signes sans déplacer la
# colonne, qui est fixée par le « : ».
FICHE_SUBS = [
    ("* Developer / publisher : grisloup.com (solo indie developer, France)",
     "* Developer / publisher : Grisloup (solo indie developer, France)"),
    ("* Développeur / éditeur : grisloup.com (développeur indépendant solo, France)",
     "* Développeur / éditeur : Grisloup (développeur indépendant solo, France)"),
    ("* Desarrollador / editor : grisloup.com (desarrollador independiente\n"
     "                             en solitario, Francia)",
     "* Desarrollador / editor : Grisloup (desarrollador independiente\n"
     "                             en solitario, Francia)"),
    ("* Sviluppatore / editore : grisloup.com (sviluppatore indipendente solo,\n"
     "                             Francia)",
     "* Sviluppatore / editore : Grisloup (sviluppatore indipendente solo,\n"
     "                             Francia)"),
    ("* Entwickler / Herausgeber : grisloup.com (unabhängiger Solo-Entwickler,\n"
     "                               Frankreich)",
     "* Entwickler / Herausgeber : Grisloup (unabhängiger Solo-Entwickler,\n"
     "                               Frankreich)"),
    ("* Programador / editor : grisloup.com (programador independente a solo,\n"
     "                           França)",
     "* Programador / editor : Grisloup (programador independente a solo,\n"
     "                           França)"),
    ("* Ontwikkelaar / uitgever : grisloup.com (onafhankelijke solo-ontwikkelaar,\n"
     "                              Frankrijk)",
     "* Ontwikkelaar / uitgever : Grisloup (onafhankelijke solo-ontwikkelaar,\n"
     "                              Frankrijk)"),
]


def _substitue(path, paires):
    texte = path.read_text(encoding="utf-8")
    for src, dst in paires:
        n = texte.count(src)
        if n != 1:
            raise SystemExit("[%s] « %s… » : %d occurrence(s), 1 attendue."
                             % (path.name, src[:60], n))
        texte = texte.replace(src, dst)
    return texte


def main():
    check = "--check" in sys.argv
    n = 0

    for lang in LANGS:
        path = SITE / lang / "press" / "index.html"
        texte = _substitue(path, [PAGES[lang]])
        if not check:
            path.write_text(texte, encoding="utf-8")
        n += 1

    texte = _substitue(FICHE, FICHE_SUBS)
    if not check:
        FICHE.write_text(texte, encoding="utf-8")

    print("%d page(s) presse + la fiche presse (7 sections) %s."
          % (n, "verifiee(s)" if check else "corrigee(s)"))
    print("  L'editeur y est nomme « Grisloup », comme au RNE et au corpus legal.")
    print("  Le domaine reste « grisloup.com » la ou c'est un domaine.")


if __name__ == "__main__":
    main()
