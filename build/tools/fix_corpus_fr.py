#!/usr/bin/env python3
"""Corrige les trois défauts du corpus `fr` avant qu'ils ne se propagent.

Contexte : le corpus `fr` a été dérivé de `eu` par `derive_market_corpus.py`, qui
ne réécrit que TROIS choses (l'en-tête `Région :`, la version, les liens
internes). Tout ce qui nomme la région DANS LE CORPS du texte est passé à
travers. Ouvrir `euo`, `eus`, `eun` ou `eux` en dérivant depuis `fr` recopierait
donc le défaut quatre fois de plus — d'où cette passe avant, et non après.

Trois familles de corrections, toutes vérifiées à une occurrence :

  1. RÉGION — six mentions par langue disent encore « Union Européenne » là où
     l'en-tête dit « France ». Elles ne sont PAS toutes fautives : le §1 des CGU
     (« stockage des données dans l'Union Européenne »), le §7 (« infrastructure
     située dans… ») et le §12 (« votre pays de résidence au sein de… ») parlent
     du DATACENTER ou du droit applicable, et sont justes. Seules sont reprises
     les mentions qui nomment le MARCHÉ — celles qui, laissées telles quelles,
     servent à un joueur français des conditions présentées comme européennes.

  2. ODR — la plateforme européenne de règlement en ligne des litiges a FERMÉ le
     20 juillet 2025. Le §12 y renvoyait encore. Un lien mort dans une clause de
     recours ne se contente pas d'être inerte : il fait croire à un recours qui
     n'existe plus. Il est remplacé par le droit qui, lui, subsiste — saisir la
     juridiction de son lieu de résidence (règlement Bruxelles I bis, art. 18).

     ⚠ CE N'EST PAS LA MISE EN CONFORMITÉ COMPLÈTE. L'article L612-1 du code de
       la consommation impose de désigner NOMMÉMENT un médiateur de la
       consommation. Aucun n'est souscrit à ce jour, et un script n'a pas à en
       inventer un. La mention reste à ajouter le jour où l'adhésion est prise.

  3. CONSERVATION — le document enfant annonçait un effacement « au bout de trois
     mois » quand le document adulte du même corpus annonce « deux ans après le
     blocage ». C'est le document adulte qui dit vrai : `backend/config.yml:746`
     porte `"purge_day":730`, et le commentaire qui l'accompagne (l.726-742)
     explique le choix des deux ans. Le document enfant est aligné dessus.
     (Les commentaires `suppression j90` / `J90` de `backend/build.yml` et
     `backend/config.yml` portaient la même erreur. Ils ont été alignés à la main
     le même jour : ce sont des commentaires de code, hors du champ d'un script
     qui ne touche qu'au corpus.)

Le corpus `eu-*` n'est PAS touché. Il n'est servi à personne
(`build.yml → documents.regions: [fr]`) et n'est conservé que comme trace de ce
qui a existé ; le réécrire effacerait justement ce qu'il sert à prouver.

Aucun bump de version : l'application n'a jamais été publiée, personne n'a donc
accepté ces documents. Bumper créerait un flux de ré-acceptation pour des
utilisateurs qui n'existent pas.

    python tools/fix_corpus_fr.py            # écrit
    python tools/fix_corpus_fr.py --check    # vérifie sans écrire

⚠ SCRIPT À USAGE UNIQUE, comme `reset_corpus_v1.py` : une fois joué, il ne
  retrouve plus ses motifs et échoue. C'est le contrat — une substitution qui ne
  trouve pas exactement une occurrence est une erreur, jamais un silence.
"""

import re
import sys
from pathlib import Path

DOCS = Path(__file__).parent.parent / "legal" / "documents"

# (fichier, motif, remplacement). Le motif tolère les retours à la ligne du
# source HTML (`\s+`) ; le remplacement les recolle en une espace simple, ce que
# le rendu HTML fait de toute façon.
FIXES = [

    # ── 1. RÉGION : le marché nommé en clair dans le corps ────────────────────

    # CGU adulte §3 — « les présentes conditions sont celles de la région … »
    ("fr-a-fr-cgu-v1.html",
     r"sont\s+celles\s+de\s+la\s+région\s+Union\s+Européenne",
     "sont celles de la région France"),
    ("fr-a-en-cgu-v1.html",
     r"are\s+those\s+of\s+the\s+European\s+Union\s+region",
     "are those of the France region"),
    ("fr-a-es-cgu-v1.html",
     r"son\s+las\s+de\s+la\s+región\s+Unión\s+Europea",
     "son las de la región Francia"),

    # Politique adulte §2 — ligne « Région » du tableau des données collectées
    ("fr-a-fr-privacy-v1.html",
     r"\(aujourd'hui\s*:\s*Union\s+Européenne\)",
     "(aujourd'hui : France)"),
    ("fr-a-en-privacy-v1.html",
     r"\(today:\s*European\s+Union\)",
     "(today: France)"),
    ("fr-a-es-privacy-v1.html",
     r"\(hoy:\s*Unión\s+Europea\)",
     "(hoy: Francia)"),

    # Politique adulte §7 — la parenthèse qui rattache le marché à ses centres
    # de données. Le marché change de nom, le datacenter reste l'UE : c'est
    # exactement la distinction région ≠ datacenter, et elle doit se lire.
    ("fr-a-fr-privacy-v1.html",
     r"\(pour\s+l'Union\s+Européenne\s*:\s*des\s+centres",
     "(pour la France : des centres"),
    ("fr-a-en-privacy-v1.html",
     r"\(for\s+the\s+European\s+Union:\s*data\s+centres",
     "(for France: data centres"),
    ("fr-a-es-privacy-v1.html",
     r"\(para\s+la\s+Unión\s+Europea:\s*centros",
     "(para Francia: centros"),

    # Politique adulte §7 — « La présente politique est celle de la région … »
    ("fr-a-fr-privacy-v1.html",
     r"politique\s+est\s+celle\s+de\s+la\s+région\s+Union\s+Européenne",
     "politique est celle de la région France"),
    ("fr-a-en-privacy-v1.html",
     r"policy\s+is\s+the\s+one\s+for\s+the\s+European\s+Union\s+region",
     "policy is the one for the France region"),
    ("fr-a-es-privacy-v1.html",
     r"política\s+es\s+la\s+de\s+la\s+región\s+Unión\s+Europea",
     "política es la de la región Francia"),

    # Documents enfants — « Pour l'instant, c'est … »
    ("fr-k-fr-cgu-v1.html",     r"c'est\s+l'Union\s+Européenne",  "c'est la France"),
    ("fr-k-fr-privacy-v1.html", r"c'est\s+l'Union\s+Européenne",  "c'est la France"),
    ("fr-k-en-cgu-v1.html",     r"it\s+is\s+the\s+European\s+Union", "it is France"),
    ("fr-k-en-privacy-v1.html", r"it\s+is\s+the\s+European\s+Union", "it is France"),
    ("fr-k-es-cgu-v1.html",     r"es\s+la\s+Unión\s+Europea",      "es Francia"),
    ("fr-k-es-privacy-v1.html", r"es\s+la\s+Unión\s+Europea",      "es Francia"),

    # ── 2. ODR : plateforme fermée le 20 juillet 2025 ─────────────────────────

    ("fr-a-fr-cgu-v1.html",
     r"Vous\s+pouvez\s+également\s+recourir\s+à\s+la\s+plateforme\s+européenne\s+de\s+règlement\s+en\s+ligne\s+des\s+litiges\s+"
     r"\(<a\s+href=\"https://ec\.europa\.eu/consumers/odr\">ec\.europa\.eu/consumers/odr</a>\)\.",
     "Vous conservez en tout état de cause le droit de saisir la juridiction compétente de votre lieu de\n"
     "résidence."),
    ("fr-a-en-cgu-v1.html",
     r"You\s+may\s+also\s+use\s+the\s+European\s+online\s+dispute\s+resolution\s+platform\s+"
     r"\(<a\s+href=\"https://ec\.europa\.eu/consumers/odr\">ec\.europa\.eu/consumers/odr</a>\)\.",
     "You retain in any event the right to bring proceedings before the competent court of your place of\n"
     "residence."),
    ("fr-a-es-cgu-v1.html",
     r"También\s+puede\s+recurrir\s+a\s+la\s+plataforma\s+europea\s+de\s+resolución\s+de\s+litigios\s+en\s+línea\s+"
     r"\(<a\s+href=\"https://ec\.europa\.eu/consumers/odr\">ec\.europa\.eu/consumers/odr</a>\)\.",
     "Usted conserva en todo caso el derecho de acudir al órgano jurisdiccional competente de su lugar de\n"
     "residencia."),

    # ── 3. CONSERVATION : le document enfant contredisait l'adulte ────────────

    ("fr-k-fr-cgu-v1.html",
     r"ses\s+informations\s+sont\s+effacées\s+au\s+bout\s+de\s+trois\s+mois",
     "ses informations sont effacées au bout de deux ans"),
    ("fr-k-en-cgu-v1.html",
     r"its\s+information\s+is\s+erased\s+after\s+three\s+months",
     "its information is erased after two years"),
    ("fr-k-es-cgu-v1.html",
     r"su\s+información\s+se\s+borra\s+al\s+cabo\s+de\s+tres\s+meses",
     "su información se borra al cabo de dos años"),
]


def main():
    check = "--check" in sys.argv

    # Groupé par fichier : plusieurs substitutions visent le même document, et on
    # ne veut ni le relire ni le réécrire trois fois.
    by_file = {}
    for name, pattern, replacement in FIXES:
        by_file.setdefault(name, []).append((pattern, replacement))

    total = 0
    for name in sorted(by_file):
        path = DOCS / name
        if not path.exists():
            raise SystemExit(f"introuvable : {path}")

        text = path.read_text(encoding="utf-8")
        for pattern, replacement in by_file[name]:
            text, n = re.subn(pattern, replacement.replace("\\", "\\\\"), text, flags=re.S)
            if n != 1:
                raise SystemExit(
                    f"[{name}] motif « {pattern[:60]}… » : {n} occurrence(s), 1 attendue."
                )
            total += 1

        if not check:
            path.write_text(text, encoding="utf-8")
        print(f"  {name}  ({len(by_file[name])} substitution(s))")

    verb = "verifiee(s)" if check else "appliquee(s)"
    print(f"\n{total} substitution(s) {verb} sur {len(by_file)} fichier(s).")


if __name__ == "__main__":
    main()
