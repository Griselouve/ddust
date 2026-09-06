#!/usr/bin/env python3
"""Repose l'ENSEMBLE du corpus légal en v1, daté du jour de la remise à plat.

⚠ SCRIPT DÉJÀ JOUÉ — il archive la remise à plat du 2026-08-28, et ne se relance
  pas tel quel (il ne trouverait plus rien à changer, et `DATE` est figée à la
  date du geste). Il est conservé pour la même raison que `gen_cgu_next.py` :
  la trace de ce qui a été fait au corpus vaut mieux que le corpus seul.

Contexte : les numéros de version étaient l'héritage de bumps successifs — `eu` en
cgu v6 / privacy v4 / k-cgu v5, `us` en cgu v4 / privacy v3, `fr` en v1. Ils ne
décrivaient plus rien :

  - les versions intermédiaires ont été retirées du disque, il ne reste qu'un
    fichier par famille : la « preuve de ce qui a été accepté » que la
    numérotation servait à porter n'existait donc plus ;
  - l'application n'a jamais été publiée, et le seul marché ouvert
    (`build.yml` → `documents.regions: [fr]`) était déjà reparti de v1 ;
  - les liens croisés avaient dérivé : `eu-a-fr-cgu-v6.html` renvoyait le lecteur
    vers `eu-a-fr-privacy-v3.html`, un fichier supprimé depuis. Un document légal
    qui pointe vers une version qui n'est plus en vigueur induit en erreur.

Trois substitutions par document, chacune vérifiée — une occurrence attendue,
sinon le script échoue. Un document légal modifié à moitié est pire qu'un document
non modifié :

  1. le nom du fichier      : `{marché}-{état}-{langue}-{type}-v{N}.html` -> `-v1.html`
  2. l'en-tête de version   : `Version : 6 — en vigueur au 19 août 2026` -> `1 — ... 28 août 2026`
  3. les liens internes     : toute URL `...-v{N}.html` du corpus -> `-v1.html`

Le NOM DU BUCKET n'est jamais réécrit : il suit le datacenter (`dvddust-eu-documents-storage`)
et non le marché, et contient donc « eu- » sans qu'aucun document n'y soit nommé.
C'est pourquoi le motif exige le suffixe `-v{N}.html`.

Pour un vrai bump de version, ce n'est pas ce script : voir `gen_cgu_next.py`.
Pour ouvrir un marché de plus : `derive_market_corpus.py`.

    python tools/reset_corpus_v1.py            # écrit
    python tools/reset_corpus_v1.py --check    # vérifie sans écrire
"""

import re
import sys
from pathlib import Path

DOCS = Path(__file__).parent.parent / "legal" / "documents"

# Étiquettes localisées de l'en-tête. Le français met une espace avant le
# deux-points, pas les deux autres.
VERSION_TAG = {"fr": "Version :", "en": "Version:", "es": "Versión:"}

# Date de la remise à plat. Les documents adultes annoncent une entrée en vigueur,
# ceux des mineurs se contentent de la date — leur rédaction évite le vocabulaire
# contractuel.
DATE_ADULT = {
    "fr": "en vigueur au 28 août 2026",
    "en": "in force as of 28 August 2026",
    "es": "en vigor desde el 28 de agosto de 2026",
}
DATE_KID = {
    "fr": "28 août 2026",
    "en": "28 August 2026",
    "es": "28 de agosto de 2026",
}

# Nom de fichier du corpus : {marché}-{état}-{langue}-{type}-v{N}.html
NAME_RE = re.compile(r"^([a-z0-9]+)-([ak])-([a-z]{2,3})-([a-z0-9]+)-v(\d+)\.html$")

# Référence à un document du corpus, où qu'elle se trouve (URL de bucket comprise).
LINK_RE = re.compile(r"([a-z0-9]+-[ak]-[a-z]{2,3}-[a-z0-9]+)-v\d+\.html")


def _set_version(text, lang, state, name):
    """Repose le numéro de version à 1 et la date d'entrée en vigueur."""
    tag = VERSION_TAG[lang]
    date = DATE_ADULT[lang] if state == "a" else DATE_KID[lang]
    pattern = re.compile(re.escape(f"<strong>{tag}</strong>") + r"[^<\n]*")
    text, n = pattern.subn(f"<strong>{tag}</strong> 1 — {date}", text)
    if n != 1:
        raise SystemExit(f"[{name}] en-tête « {tag} » : {n} occurrence(s), 1 attendue.")
    return text


def _reset_links(text, name):
    """Ramène toutes les références internes du corpus en v1.

    ⚠ RÉPARE AU PASSAGE LES LIENS PÉRIMÉS, et c'est un effet de bord voulu : tout
      le corpus étant en v1, un renvoi ne peut plus désigner un fichier absent.
    """
    text, n = LINK_RE.subn(lambda m: f"{m.group(1)}-v1.html", text)
    if n == 0:
        raise SystemExit(f"[{name}] aucun lien interne trouvé, au moins un attendu.")
    leftover = [m for m in re.findall(r"[a-z0-9]+-[ak]-[a-z]{2,3}-[a-z0-9]+-v(\d+)\.html", text) if m != "1"]
    if leftover:
        raise SystemExit(f"[{name}] version résiduelle dans un lien : v{', v'.join(leftover)}")
    return text, n


def main():
    check = "--check" in sys.argv
    done, untouched = [], []

    sources = sorted(p for p in DOCS.glob("*-v*.html") if NAME_RE.match(p.name))
    if not sources:
        raise SystemExit(f"aucun document dans {DOCS}")

    # Aucune famille ne doit porter deux versions : le renommage en écraserait une.
    families = {}
    for path in sources:
        market, state, lang, doc, version = NAME_RE.match(path.name).groups()
        families.setdefault((market, state, lang, doc), []).append(version)
    duplicates = {k: v for k, v in families.items() if len(v) > 1}
    if duplicates:
        raise SystemExit(
            "familles à plusieurs versions, le renommage en perdrait une :\n  "
            + "\n  ".join(f"{'-'.join(k)} : v" + ", v".join(sorted(v)) for k, v in duplicates.items())
        )

    for path in sources:
        market, state, lang, doc, version = NAME_RE.match(path.name).groups()
        if lang not in VERSION_TAG:
            raise SystemExit(f"[{path.name}] langue '{lang}' sans étiquette : compléter VERSION_TAG.")

        text = path.read_text(encoding="utf-8")
        new_text = _set_version(text, lang, state, path.name)
        new_text, links = _reset_links(new_text, path.name)

        target = DOCS / f"{market}-{state}-{lang}-{doc}-v1.html"
        renamed = target.name != path.name

        if new_text == text and not renamed:
            untouched.append(path.name)
            continue

        if not check:
            target.write_text(new_text, encoding="utf-8")
            if renamed:
                path.unlink()

        label = f"{path.name} -> {target.name}" if renamed else path.name
        done.append(f"{label}  (v{version} -> v1, {links} lien(s))")

    verb = "verifie" if check else "traite"
    print(f"{len(done)} document(s) {verb} :")
    for name in done:
        print(f"  {name}")
    if untouched:
        print(f"\n{len(untouched)} deja conforme(s) :")
        for name in untouched:
            print(f"  {name}")


if __name__ == "__main__":
    main()
