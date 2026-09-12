#!/usr/bin/env python3
"""Contrôle les invariants du corpus légal. À rejouer, contrairement à ses voisins.

⚠ CE SCRIPT N'EST PAS UN SCRIPT À USAGE UNIQUE. Les `set_publisher_*.py`,
  `reset_corpus_v1.py` et `fix_corpus_fr.py` ont été joués une fois et échouent
  désormais faute de retrouver leurs motifs — c'est ainsi qu'on les sait joués.
  Celui-ci se rejoue à volonté : il ne modifie rien, il vérifie.

    python tools/check_corpus.py

⚠ POURQUOI IL EXISTE. Rien, dans la chaîne de build, ne garantit qu'un document
  légal est complet :
    - `builder._check_documents_regions` ne teste que `default_language` (`en`).
      Une traduction absente ne fait donc JAMAIS échouer le build ;
    - `pudocuments` bâtit son index à partir de ce qu'il trouve sur disque, sans
      confronter à `langues` ;
    - `dvdocuments.getDoc()` renvoie `null` sans repli : un couple manquant donne
      un lien « lire les conditions » mort, et pas une erreur.
  Le seul endroit où l'absence peut se voir, c'est ici.

⚠ CE QU'IL VÉRIFIE, ET POURQUOI CHAQUE POINT Y EST :
    1. COMPLÉTUDE — marché × état légal × langue × document. Un trou est une
       promesse faite dans `build.yml → langues` et non tenue.
    2. IDENTITÉ DE L'ÉDITEUR — exactement une mention `SIREN …, RCS Pontoise` par
       document ADULTE, aucune dans les documents enfants. Les scripts qui l'ont
       posée sont à usage unique : un document neuf qui naît sans elle n'aura
       jamais personne pour la lui ajouter.
    3. EN-TÊTE — libellé de région et numéro de version, dans la forme exacte que
       `derive_market_corpus._set_region` et `_set_version` savent reconnaître. Un
       en-tête mal formé ne casse pas ce document-ci : il casse la dérivation des
       onze autres marchés.
    4. ATTRIBUT `lang` — un document italien annoncé `lang="fr"` se fait lire à
       voix haute avec l'accent français par un lecteur d'écran.
    5. MÉDIATEUR DE LA CONSOMMATION — exactement une mention `CM2C` dans chaque
       CGU ADULTE de la souche `fr`, aucune ailleurs. Même raison qu'au point 2,
       et une raison de plus : l'article L616-1 impose de DÉSIGNER NOMMÉMENT le
       médiateur, sans seuil d'effectif ni de chiffre d'affaires, et le défaut
       d'information est puni jusqu'à 3 000 €. Un document neuf né sans la clause
       est donc une infraction, pas une coquille.
       ⚠ « Aucune ailleurs » se contrôle aussi, et vaut autant : la souche `us`
         renvoie aux autorités locales (FTC, ANPD, PROFECO…), pas à un médiateur
         français. L'y voir apparaître signalerait une dérivation qui a recopié
         la mauvaise souche.

Les tables de référence sont IMPORTÉES de `derive_market_corpus.py` : les deux ne
peuvent pas diverger, puisqu'il n'y en a qu'une.
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from derive_market_corpus import (  # noqa: E402
    DOCS, DOC_TYPES, LANGS, REGION_LABEL, REGION_TAG, STATES, VERSION_TAG,
)

# Les marchés qui ont un corpus. `eu` est dans REGION_LABEL comme libellé de
# souche historique, mais son corpus a été supprimé le 2026-08-28 : il n'a rien
# à vérifier.
MARCHES = ("fr", "euo", "eus", "eun", "eux", "uk", "ch",
           "us", "ca", "oceanie", "bresil", "hispam")

IDENTITE = "SIREN 109354092, RCS Pontoise"

# Les marchés soumis au droit de la consommation français ou européen, seuls à
# porter la désignation du médiateur. Ce sont les six dérivés de la souche `fr`,
# plus la souche elle-même. `posé par set_consumer_mediation.py` le 2026-09-09.
MARCHES_MEDIATION = ("fr", "euo", "eus", "eun", "eux", "uk", "ch")

MEDIATION = "CM2C"


def _compte(texte, litteral):
    """Occurrences, RETOURS À LA LIGNE TOLÉRÉS.

    Le corpus est enregistré en lignes courtes : une phrase coupée en deux est le
    cas normal. On compte donc comme `_as_pattern` de derive_market_corpus, sinon
    on signale des écarts qui n'existent pas et on rate ceux qui existent.
    """
    return len(re.findall(r"\s+".join(re.escape(m) for m in litteral.split()), texte))


def controle():
    ecarts = []
    attendus = 0

    for marche in MARCHES:
        for etat in STATES:
            for lang in LANGS:
                for doc in DOC_TYPES:
                    attendus += 1
                    path = DOCS / ("%s-%s-%s-%s-v1.html" % (marche, etat, lang, doc))
                    if not path.exists():
                        ecarts.append("ABSENT  %s" % path.name)
                        continue
                    texte = path.read_text(encoding="utf-8")

                    voulu = 1 if etat == "a" else 0
                    trouve = _compte(texte, IDENTITE)
                    if trouve != voulu:
                        ecarts.append("%s : identité %d fois, %d attendue(s)"
                                      % (path.name, trouve, voulu))

                    voulu_med = 1 if (etat == "a" and doc == "cgu"
                                      and marche in MARCHES_MEDIATION) else 0
                    trouve_med = _compte(texte, MEDIATION)
                    if trouve_med != voulu_med:
                        ecarts.append("%s : médiateur %d fois, %d attendue(s)"
                                      % (path.name, trouve_med, voulu_med))

                    tag_r, tag_v = REGION_TAG[lang], VERSION_TAG[lang]
                    entete = "<strong>%s</strong> %s" % (tag_r, REGION_LABEL[marche][lang])
                    if _compte(texte, entete) != 1:
                        ecarts.append("%s : en-tête région, attendu « %s »"
                                      % (path.name, REGION_LABEL[marche][lang]))
                    if len(re.findall(re.escape("<strong>%s</strong>" % tag_v), texte)) != 1:
                        ecarts.append("%s : en-tête version « %s » introuvable"
                                      % (path.name, tag_v))

                    if ('<html lang="%s">' % lang) not in texte:
                        ecarts.append("%s : attribut lang absent ou faux" % path.name)

    return attendus, ecarts


def main():
    attendus, ecarts = controle()
    presents = len(list(DOCS.glob("*.html")))
    if ecarts:
        print("%d écart(s) :" % len(ecarts))
        for e in ecarts:
            print("  " + e)
        raise SystemExit(1)
    print("corpus conforme : %d documents attendus, %d sur disque."
          % (attendus, presents))
    print("  %d marchés × %d états × %d langues × %d documents."
          % (len(MARCHES), len(STATES), len(LANGS), len(DOC_TYPES)))
    if presents != attendus:
        print("  ⚠ %d fichier(s) en trop : version antérieure conservée comme preuve,"
              " ou marché retiré. Vérifier que c'est voulu." % (presents - attendus))


if __name__ == "__main__":
    main()
