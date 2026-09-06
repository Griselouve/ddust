#!/usr/bin/env python3
"""Ajoute le SIREN à l'identification de l'éditeur, dans tout le corpus et sur le site.

C'est le SECOND PASSAGE annoncé par `set_publisher_identity.py` : celui-là avait
posé le nom, la qualité et l'adresse de domiciliation le 2026-08-31, en laissant
un trou explicite — « SIREN ABSENT, l'immatriculation est soumise, pas obtenue ».

Elle l'est : **SIREN `109354092`, immatriculé au RNE le 2026-09-02**, code APE
`58.29C` (édition de logiciels applicatifs). L'article R123-237 du code de
commerce impose dès lors le numéro sur les documents de l'entreprise ; il n'y
avait rien à écrire avant, il n'y a plus de raison d'attendre.

⚠ AUCUN BUMP DE VERSION, ET C'EST UN ARBITRAGE, pas un oubli. Le responsable de
  traitement reste LA MÊME PERSONNE PHYSIQUE : seules sa qualification, son
  adresse et son numéro changent. Ajouter une identification qui manquait n'altère
  ni les droits ni les obligations de personne — bumper les CGU déclencherait le
  flux d'acceptation et forcerait à re-notifier tous les inscrits de la beta pour
  neuf chiffres. Les fichiers restent en `v1` et sont modifiés SUR PLACE.
  Décision du 2026-09-03, à relire si un jour une clause de fond bouge : celle-là,
  elle, se bumpe.

⚠ CE QUI N'EST PAS ÉCRIT ICI, ET POURQUOI :
    - le SIRET — le SIREN est connu, ses cinq derniers chiffres sont à relever sur
      l'extrait d'immatriculation. R123-237 se satisfait du SIREN ;
    - le numéro de TVA intracommunautaire — il N'EXISTE PAS encore (demande au SIE,
      cf. plan §2.1). Écrire un numéro plausible serait pire que l'omettre ;
    - le RCS et sa ville de greffe — l'activité est commerciale, donc la mention est
      due, mais la ville se lit sur l'extrait et ne s'invente pas.
  Les trois sont tracés dans le tableau « ce qui manque encore » de
  `grisloup/docs/plan-creation-micro-entreprise.md` §5.2. Il y aura donc un
  TROISIÈME passage, court, le jour où l'extrait est sous les yeux.
  (Il l'a été le jour même : cf. `set_publisher_rcs.py`, le Kbis étant arrivé
  une heure plus tard.)

⚠ LES DOCUMENTS ENFANTS RESTENT INTACTS, pour la même raison que la première fois :
  un document écrit pour un mineur n'a pas à porter une mention d'immatriculation.
  72 documents adultes, 3 pages du site.

    python tools/set_publisher_siren.py            # écrit
    python tools/set_publisher_siren.py --check    # vérifie sans écrire

⚠ SCRIPT À USAGE UNIQUE, même contrat que ses aînés : une substitution qui ne
  trouve pas EXACTEMENT une occurrence est une erreur, jamais un silence. Une fois
  joué, il ne retrouve plus ses motifs et échoue — c'est ainsi qu'on le sait joué.
"""

import re
import sys
from pathlib import Path

BUILD = Path(__file__).parent.parent
DOCS = BUILD / "legal" / "documents"
SITE = BUILD / "hosting" / "web"

# ── Ce que l'immatriculation a rendu ─────────────────────────────────────────
SIREN = "109354092"
NOM_CIVIL = "Guillaume Marchal De Greef"
ADRESSE = "20 rue Lavoisier, 95300 Pontoise"

# L'ancre est l'adresse suivie du pays : posée par `set_publisher_identity.py`,
# elle est présente UNE FOIS ET UNE SEULE dans chacun des 75 fichiers, quelle
# que soit la forme de phrase (CGU, politique européenne, politique américaine
# parenthésée, bloc du site). Le SIREN se glisse juste derrière, avant la
# ponctuation qui suit — la phrase continue donc sans être retouchée.
_PAYS = {"fr": "France", "en": "France", "es": "Francia"}

MARCHES = ("fr", "euo", "eus", "eun", "eux", "uk", "ch",
           "us", "ca", "oceanie", "bresil", "hispam")
LANGS = ("fr", "en", "es")


def _ancre(lang):
    return f"{ADRESSE}, {_PAYS[lang]}"


def _avec_siren(lang):
    # « SIREN » n'est pas traduit : c'est un identifiant, pas un mot. Les registres
    # étrangers le citent tel quel, et le traduire le rendrait introuvable.
    return f"{_ancre(lang)}, SIREN {SIREN}"


# ── Le bloc « Éditeur » du site reçoit en plus le directeur de publication ───
# ⚠ EXIGENCE PROPRE AU SITE, pas à l'application : l'article 6-III de la LCEN vise
#   les services de communication au public en ligne et impose de nommer le
#   directeur de la publication. Pour une entreprise individuelle, c'est
#   l'entrepreneur — la ligne est courte, son absence est une infraction.
_SITE_ANCRE = {
    "fr": 'Contact&nbsp;: <a href="mailto:donjons@grisloup.com">donjons@grisloup.com</a><br>',
    "en": 'Contact: <a href="mailto:donjons@grisloup.com">donjons@grisloup.com</a><br>',
    "es": 'Contacto: <a href="mailto:donjons@grisloup.com">donjons@grisloup.com</a><br>',
}
_SITE_DIRECTEUR = {
    "fr": f"Directeur de la publication&nbsp;: {NOM_CIVIL}<br>",
    "en": f"Publication director: {NOM_CIVIL}<br>",
    "es": f"Director de la publicación: {NOM_CIVIL}<br>",
}


def _cibles():
    """(chemin, motif littéral, remplacement) — 75 fichiers, 78 substitutions."""
    for marche in MARCHES:
        for lang in LANGS:
            for kind in ("cgu", "privacy"):
                yield (DOCS / f"{marche}-a-{lang}-{kind}-v1.html",
                       _ancre(lang), _avec_siren(lang))
    for lang in LANGS:
        page = SITE / lang / "legal" / "index.html"
        yield (page, _ancre(lang), _avec_siren(lang))
        yield (page, _SITE_ANCRE[lang],
               _SITE_ANCRE[lang] + "\n    " + _SITE_DIRECTEUR[lang])


def _as_pattern(literal):
    """Motif tolérant les retours à la ligne du source HTML."""
    return r"\s+".join(re.escape(w) for w in literal.split())


def main():
    check = "--check" in sys.argv
    fichiers, substitutions = set(), 0

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
        fichiers.add(path)
        substitutions += 1

    verb = "verifie(s)" if check else "ecrit(s)"
    print(f"{len(fichiers)} fichier(s) {verb}, {substitutions} substitution(s) "
          f"— 72 documents adultes + 3 pages du site.")
    print(f"  SIREN {SIREN} — {ADRESSE}, France. APE 58.29C, RNE du 2026-09-02.")
    print("  TVA intracom, SIRET et RCS : non attribues -> troisieme passage a prevoir.")


if __name__ == "__main__":
    main()
