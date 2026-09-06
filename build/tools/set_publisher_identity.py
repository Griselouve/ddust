#!/usr/bin/env python3
"""Écrit l'identification légale de l'éditeur dans tout le corpus et sur le site.

Contexte : la micro-entreprise a été soumise le 2026-08-31, avec domiciliation.
Jusque-là, les 144 documents du corpus et les trois pages légales du site
n'identifiaient l'éditeur que par « grisloup.com » — qui est le NOM COMMERCIAL
(`build.yml → publisher.trade_name`), pas une identification légale.

⚠ LE NOM COMMERCIAL NE SUFFIT PAS, ET NE PEUT PAS SUFFIRE. L'article R526-27 du
  code de commerce impose à un entrepreneur individuel une dénomination
  INCORPORANT SON NOM, immédiatement précédé ou suivi des mots « entrepreneur
  individuel ». La formule retenue met « Grisloup » devant — c'est ce sous quoi
  le service est connu — puis l'identité civile, qui est l'obligation.

⚠ LES DOUZE MARCHÉS REÇOIVENT LE MÊME BLOC, et c'est une correction. Il avait été
  écrit le 2026-08-28 que le marché `us` n'avait « pas d'obligation générale
  équivalente ». C'est faux : COPPA (16 CFR 312.4(d)) impose à la politique de
  confidentialité d'indiquer les nom, ADRESSE, TÉLÉPHONE et courriel de
  l'opérateur. Même exigence côté mexicain (LFPDPPP, « identidad y domicilio del
  responsable » dans l'aviso de privacidad), australien (APP 1.3), canadien
  (LPRPDE), brésilien (LGPD) et européen (LCEN art. 6-III, directive 2000/31
  art. 5). Aucune exception.

⚠ L'ADRESSE EST UNE DOMICILIATION, PAS UN DOMICILE. C'est ce qui débloque cet
  item : l'adresse d'une entreprise est destinée à être publique, là où le
  domicile personnel de Courdimanche — encore dans `build.yml → publisher.address`
  — relève de l'item « données personnelles hors de build.yml ». Le téléphone
  publié est de même celui de la structure, pas le mobile personnel.

⚠ LES DOCUMENTS ENFANTS NE SONT PAS TOUCHÉS. Vérifié : ils ne citent
  « grisloup.com » que comme adresse de courriel, jamais comme identification.
  Un document écrit pour un enfant n'a pas à porter une mention d'immatriculation.

⚠ SIREN ABSENT — SECOND PASSAGE À PRÉVOIR. L'immatriculation est soumise, pas
  obtenue. Dès qu'elle l'est, l'article R123-237 du code de commerce impose le
  numéro sur les documents : il faudra repasser ici, et basculer
  `publisher.registration_number` (aujourd'hui `~`).

Les corpus SOUCHES `fr` et `us` sont patchés comme les autres : toute dérivation
future hérite ainsi du bloc, et `derive_market_corpus.py` n'a rien à savoir de
l'identité de l'éditeur.

    python tools/set_publisher_identity.py            # écrit
    python tools/set_publisher_identity.py --check    # vérifie sans écrire

⚠ SCRIPT À USAGE UNIQUE, comme `fix_corpus_fr.py` : une fois joué, il ne retrouve
  plus ses motifs et échoue. C'est le contrat — une substitution qui ne trouve pas
  exactement une occurrence est une erreur, jamais un silence.
"""

import re
import sys
from pathlib import Path

BUILD = Path(__file__).parent.parent
DOCS  = BUILD / "legal" / "documents"
SITE  = BUILD / "hosting" / "web"

# ── L'identité, en un seul endroit ───────────────────────────────────────────
NOM_COMMERCIAL = "Grisloup"
NOM_CIVIL      = "Guillaume Marchal De Greef"
ADRESSE        = "20 rue Lavoisier, 95300 Pontoise"
TELEPHONE      = "+33 7 44 47 09 44"

# Qualité et pays, par langue. « entrepreneur individuel » suit immédiatement le
# nom : c'est ce que l'article R526-27 exige, et l'ordre compte.
_QUALITE = {
    "fr": "entrepreneur individuel",
    "en": "sole trader",
    "es": "empresario individual",
}
_NOM_COMMERCIAL_DE = {
    "fr": "nom commercial de",
    "en": "the trading name of",
    "es": "nombre comercial de",
}
_PAYS = {"fr": "France", "en": "France", "es": "Francia"}
_TEL  = {"fr": "Téléphone", "en": "Telephone", "es": "Teléfono"}
_SEP  = {"fr": " : ", "en": ": ", "es": ": "}


def _identite(lang, telephone=True):
    """« Grisloup, nom commercial de … , entrepreneur individuel — adresse [. tél] »"""
    bloc = (f"<strong>{NOM_COMMERCIAL}</strong>, {_NOM_COMMERCIAL_DE[lang]} {NOM_CIVIL}, "
            f"{_QUALITE[lang]} — {ADRESSE}, {_PAYS[lang]}")
    if telephone:
        bloc += f". {_TEL[lang]}{_SEP[lang]}{TELEPHONE}"
    return bloc


def _identite_parenthese(lang):
    """Même identité, mais en incise : la phrase doit pouvoir continuer après."""
    return (f"<strong>{NOM_COMMERCIAL}</strong> ({_NOM_COMMERCIAL_DE[lang]} {NOM_CIVIL}, "
            f"{_QUALITE[lang]}, {ADRESSE}, {_PAYS[lang]}, "
            f"{_TEL[lang].lower()} {TELEPHONE})")


# ── Les trois formes de phrase, et où elles vivent ───────────────────────────
# CGU §1 : la MÊME phrase dans les douze marchés, européens comme américains.
_CGU_SRC = {
    "fr": "est éditée par <strong>grisloup.com</strong>.",
    "en": "is published by <strong>grisloup.com</strong>.",
    "es": "es editada por <strong>grisloup.com</strong>.",
}
_CGU_DST = {
    "fr": lambda: f"est éditée par {_identite('fr')}.",
    "en": lambda: f"is published by {_identite('en')}.",
    "es": lambda: f"es editada por {_identite('es')}.",
}

# Politique §1, souche EUROPÉENNE — « Le responsable du traitement … est X. »
# Le téléphone n'y figure pas : il est aux CGU, et le RGPD n'en exige pas.
_PRIV_EU_SRC = {
    "fr": "est <strong>grisloup.com</strong>.",
    "en": "is <strong>grisloup.com</strong>.",
    "es": "es <strong>grisloup.com</strong>.",
}
_PRIV_EU_DST = {
    "fr": lambda: f"est {_identite('fr', telephone=False)}.",
    "en": lambda: f"is {_identite('en', telephone=False)}.",
    "es": lambda: f"es {_identite('es', telephone=False)}.",
}

# Politique §1, souche AMÉRICAINE — « … est éditée et exploitée par X, qui décide »
# ⚠ TÉLÉPHONE INCLUS ICI, contrairement à la souche européenne : COPPA et la
#   LFPDPPP l'exigent dans la POLITIQUE elle-même, pas seulement aux conditions.
_PRIV_US_SRC = {
    "fr": "par <strong>grisloup.com</strong>, qui décide",
    "en": "by <strong>grisloup.com</strong>, which decides",
    "es": "por <strong>grisloup.com</strong>, que decide",
}
# ⚠ FORME PARENTHÉSÉE, ET C'EST UNE CORRECTION. La première version réutilisait
#   `_identite()` telle quelle, qui termine par « . Téléphone : … » : la phrase
#   devenait « … Téléphone : +33 … , qui décide quelles informations » — la
#   relative se rattachait au NUMÉRO et non à l'éditeur. Une substitution peut
#   trouver son occurrence unique et produire une phrase fausse ; le compteur ne
#   voit que la première moitié du problème.
_PRIV_US_DST = {
    "fr": lambda: f"par {_identite_parenthese('fr')}, qui décide",
    "en": lambda: f"by {_identite_parenthese('en')}, which decides",
    "es": lambda: f"por {_identite_parenthese('es')}, que decide",
}

# Site — bloc « Éditeur / Publisher / Editor » des trois pages légales.
# ⚠ LA LCEN VISE D'ABORD LE SITE, pas l'application : c'est un service de
#   communication au public en ligne au sens de son article 6.
_SITE_SRC = {
    "fr": "est édité par <strong>grisloup.com</strong>.",
    "en": "is published by <strong>grisloup.com</strong>.",
    "es": "está editado por <strong>grisloup.com</strong>.",
}
_SITE_DST = {
    "fr": lambda: f"est édité par {_identite('fr')}.",
    "en": lambda: f"is published by {_identite('en')}.",
    "es": lambda: f"está editado por {_identite('es')}.",
}

# Souche du corpus par marché : elle décide de la forme du §1 de la politique.
MARCHES_EU = ("fr", "euo", "eus", "eun", "eux", "uk", "ch")
MARCHES_US = ("us", "ca", "oceanie", "bresil", "hispam")
LANGS = ("fr", "en", "es")


def _cibles():
    """(chemin, motif, remplacement) pour chacun des 75 fichiers."""
    for marche in MARCHES_EU + MARCHES_US:
        for lang in LANGS:
            yield (DOCS / f"{marche}-a-{lang}-cgu-v1.html",
                   _CGU_SRC[lang], _CGU_DST[lang]())
            src, dst = ((_PRIV_EU_SRC, _PRIV_EU_DST) if marche in MARCHES_EU
                        else (_PRIV_US_SRC, _PRIV_US_DST))
            yield (DOCS / f"{marche}-a-{lang}-privacy-v1.html",
                   src[lang], dst[lang]())
    for lang in LANGS:
        yield (SITE / lang / "legal" / "index.html",
               _SITE_SRC[lang], _SITE_DST[lang]())


def _as_pattern(literal):
    """Motif tolérant les retours à la ligne du source HTML."""
    return r"\s+".join(re.escape(w) for w in literal.split())


def main():
    check = "--check" in sys.argv
    n = 0

    for path, source, replacement in _cibles():
        if not path.exists():
            raise SystemExit(f"introuvable : {path}")
        text = path.read_text(encoding="utf-8")
        text, hits = re.subn(_as_pattern(source),
                             replacement.replace("\\", "\\\\"), text)
        if hits != 1:
            raise SystemExit(
                f"[{path.name}] « {source[:48]}… » : {hits} occurrence(s), 1 attendue."
            )
        if not check:
            path.write_text(text, encoding="utf-8")
        n += 1

    verb = "verifie(s)" if check else "ecrit(s)"
    print(f"{n} fichier(s) {verb} — 72 documents adultes + 3 pages du site.")
    print(f"  {NOM_COMMERCIAL}, {_NOM_COMMERCIAL_DE['fr']} {NOM_CIVIL}, "
          f"{_QUALITE['fr']} — {ADRESSE}, {_PAYS['fr']}. {_TEL['fr']}: {TELEPHONE}")
    print("  SIREN : non attribue -> second passage a prevoir.")


if __name__ == "__main__":
    main()
