#!/usr/bin/env python3
"""Unifie l'écriture du nom de l'éditeur sur la forme du registre.

Quatrième et dernier passage sur l'identité, décidé le 2026-09-03.

    Guillaume Marchal De Greef   ->   MARCHAL DE GREEF Guillaume

⚠ CE N'EST PAS UNE CORRECTION, C'EST UNE RÈGLE DE NOMMAGE. Les trois passages
  précédents écrivaient l'ordre naturel, et ce n'était pas faux : une entreprise
  individuelle n'a AUCUNE dénomination sociale, ni à l'INSEE ni au greffe. Ces
  registres ne stockent pas un « nom d'entreprise » mais des champs séparés — nom
  de naissance, nom d'usage, prénoms — que chaque service RECOMPOSE à sa façon.
  Il n'existe donc pas de forme officielle à recopier : il existe une forme à
  CHOISIR, puis à tenir.

⚠ POURQUOI L'ORDRE DU REGISTRE A ÉTÉ RETENU. Le premier formulaire qui réclame un
  « nom de l'entreprise » est celui du D-U-N-S, et c'est LUI qui fixera la
  référence pour tout le reste : Google confronte le profil de paiement à la fiche
  D&B, la banque au profil de paiement, la facturation Cloud à la banque. Autant
  que la chaîne partie chez Altares soit celle du Kbis, qui est la pièce
  justificative jointe — « MARCHAL DE GREEF Guillaume, Flavien ».

⚠ CE QUI EST DÉLIBÉRÉMENT ABSENT DE LA CHAÎNE :
    - le second prénom « Flavien » — le risque de vérification porte sur la chaîne
      du NOM DE FAMILLE, jamais sur les prénoms ; omettre un second prénom est
      banal et partout toléré ;
    - le TRAIT D'UNION de la pièce d'identité (« MARCHAL-DE GREEF ») — c'est
      l'extrait d'immatriculation que Google confronte en vérification
      organisation, pas la carte. Cf. le tableau d'identité du plan ;
    - la mention « EI » — obligatoire sur les FACTURES et les MENTIONS LÉGALES
      seulement. Ailleurs elle fabrique la divergence qu'on cherche à éviter.

⚠ LES CAPITALES SONT VOULUES, ce n'est pas un cri. C'est la convention des
  registres français pour distinguer le nom des prénoms, et elle lève l'ambiguïté
  réelle de « Marchal De Greef » — trois mots dont on ne devine pas, hors contexte,
  lesquels forment le patronyme. Dans une phrase française, la casse surprend ;
  dans un texte juridique, elle est usuelle.

⚠ LE CORPUS EST TOUCHÉ AUSSI, ET C'EST L'OBJET. Une règle de nommage qui
  s'arrêterait aux formulaires laisserait deux formes dans le dépôt, donc une
  question qui se reposerait à chaque nouveau front. 72 documents adultes,
  3 pages du site, 2 occurrences par page (identité + directeur de publication).

⚠ TOUJOURS AUCUN BUMP DE VERSION — même arbitrage que les passages 2 et 3 : la
  partie au traitement ne change pas, c'est son ÉCRITURE qui s'unifie. Les
  fichiers restent en `v1`. Cf. `stores/google/dpa.md` §3.

⚠ LES DOCUMENTS ENFANTS NE CITENT PAS L'IDENTITÉ — vérifié, 0 occurrence. Ils ne
  sont donc pas dans la liste, et ce n'est pas un oubli.

    python tools/set_publisher_name_order.py            # écrit
    python tools/set_publisher_name_order.py --check    # vérifie sans écrire

⚠ SCRIPT À USAGE UNIQUE, même contrat que ses aînés : un fichier qui ne rend pas
  le nombre d'occurrences attendu est une erreur, jamais un silence.
"""

import sys
from pathlib import Path

BUILD = Path(__file__).parent.parent
DOCS = BUILD / "legal" / "documents"
SITE = BUILD / "hosting" / "web"

ANCIEN = "Guillaume Marchal De Greef"
NOUVEAU = "MARCHAL DE GREEF Guillaume"

MARCHES = ("fr", "euo", "eus", "eun", "eux", "uk", "ch",
           "us", "ca", "oceanie", "bresil", "hispam")
LANGS = ("fr", "en", "es")


def _cibles():
    """(chemin, occurrences attendues). Le nom n'est jamais coupé sur deux
    lignes dans ces fichiers — vérifié — donc pas de motif tolérant."""
    for marche in MARCHES:
        for lang in LANGS:
            for kind in ("cgu", "privacy"):
                yield DOCS / f"{marche}-a-{lang}-{kind}-v1.html", 1
    for lang in LANGS:
        # 2 occurrences : le bloc « Éditeur » et le directeur de la publication.
        yield SITE / lang / "legal" / "index.html", 2


def main():
    check = "--check" in sys.argv
    fichiers = substitutions = 0

    for path, attendu in _cibles():
        if not path.exists():
            raise SystemExit(f"introuvable : {path}")
        text = path.read_text(encoding="utf-8")
        hits = text.count(ANCIEN)
        if hits != attendu:
            raise SystemExit(
                f"[{path.name}] « {ANCIEN} » : {hits} occurrence(s), {attendu} attendue(s)."
            )
        if not check:
            path.write_text(text.replace(ANCIEN, NOUVEAU), encoding="utf-8")
        fichiers += 1
        substitutions += hits

    verb = "verifie(s)" if check else "ecrit(s)"
    print(f"{fichiers} fichier(s) {verb}, {substitutions} substitution(s) "
          f"— 72 documents adultes + 3 pages du site.")
    print(f"  {ANCIEN}  ->  {NOUVEAU}")


if __name__ == "__main__":
    main()
