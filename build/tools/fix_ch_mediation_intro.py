#!/usr/bin/env python3
"""Requalifie la médiation suisse en engagement volontaire de l'éditeur.

Joué le 2026-09-09, quelques heures après `set_consumer_mediation.py`, pour la
raison que celui-ci avait laissée ouverte : sa phrase d'introduction s'ouvre sur
« Conformément aux dispositions du Code de la consommation », et le §12 du marché
`ch` vient de dire que les présentes conditions sont régies par le DROIT SUISSE.
Le lecteur suisse lisait donc qu'un code étranger lui ouvrait un recours.

⚠ CE N'EST PAS UN RETRAIT. Arbitrage du 2026-09-09 : on offre CM2C aux joueurs
  suisses quand même. Seule la justification change — un engagement de l'éditeur,
  et non l'effet d'une loi qui ne s'applique pas à eux. Les coordonnées qui
  suivent la phrase ne bougent pas, et `check_corpus.MARCHES_MEDIATION` continue
  d'exiger `CM2C` dans les CGU adultes de `ch`.

⚠ POURQUOI LA SUISSE N'EXIGE RIEN. Elle n'a aucun équivalent de l'art. L616-1 :
  pas d'obligation générale d'adhérer à un organisme de médiation, ni pour une
  entreprise suisse ni pour une entreprise étrangère. Les ombudsmans y sont
  sectoriels — banques, assurance privée, télécoms, voyages, poste, transports
  publics, textile — et aucun ne couvre l'édition de jeux. Seul le domaine
  financier ancre la conciliation préalable dans la loi (art. 74 LSFin).

  ⚠ NE PAS CONFONDRE avec l'art. 14 al. 1 LPD, qui impose à un responsable de
    traitement établi à l'étranger de désigner un REPRÉSENTANT EN SUISSE. C'est
    l'équivalent de l'art. 27 RGPD : un point de contact pour la protection des
    données, qui ne règle aucun litige contractuel. Ses trois conditions sont
    CUMULATIVES (traitement de grande ampleur, régulier, à risque élevé) et
    relèvent d'un dossier distinct. Le corpus `ch` ne prétend nulle part avoir
    désigné un tel représentant, et ce silence est correct tant que les trois
    conditions ne sont pas réunies.

⚠ LES TEXTES NE SONT PAS ICI. Ils vivent dans `derive_market_corpus._CH_MEDIATION`,
  déclarés comme les autres écarts suisses et appliqués par `_ch_blocks`. Ce
  script ne fait que RATTRAPER les sept fichiers déjà sur disque, que la
  dérivation refuse d'écraser (`main()` : « On n'écrase JAMAIS un document déjà
  dérivé »). Sans le bloc dans la table, un `ch` régénéré un jour reviendrait en
  silence à la phrase française ; sans ce script, la table dirait vrai et les
  fichiers diraient faux. Il faut les deux, et c'est pour ça qu'on IMPORTE les
  tables au lieu de les recopier.

⚠ AUCUN BUMP DE VERSION, même motif que son aîné : l'application n'a jamais été
  publiée, personne n'a accepté ces documents.

    python tools/fix_ch_mediation_intro.py            # écrit
    python tools/fix_ch_mediation_intro.py --check    # vérifie sans écrire

⚠ SCRIPT À USAGE UNIQUE. Ici l'ancre est CONSOMMÉE par la substitution, donc
  rejouer échoue tout seul : la phrase française n'est plus là pour être trouvée.
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from derive_market_corpus import (  # noqa: E402
    DOCS, LANGS, _CH_MEDIATION, _MEDIATION_SRC, _as_pattern,
)

MARCHE = "ch"


def main():
    check = "--check" in sys.argv
    n = 0

    for lang in LANGS:
        path = DOCS / ("%s-a-%s-cgu-v1.html" % (MARCHE, lang))
        if not path.exists():
            raise SystemExit("introuvable : %s" % path)
        text = path.read_text(encoding="utf-8")

        remplacement = _CH_MEDIATION[lang].replace("\\", "\\\\")
        text, hits = re.subn(_as_pattern(_MEDIATION_SRC[lang]), remplacement, text)
        if hits != 1:
            raise SystemExit(
                "[%s] phrase d'introduction : %d occurrence(s), 1 attendue."
                % (path.name, hits))

        if not check:
            path.write_text(text, encoding="utf-8")
        n += 1

    verb = "verifie(s)" if check else "ecrit(s)"
    print("%d fichier(s) %s - CGU adultes du marche %s, %d langues."
          % (n, verb, MARCHE, len(LANGS)))
    print("  La mediation y est presentee comme un engagement volontaire :"
          " la Suisse n'impose aucun mediateur.")
    print("  Coordonnees CM2C inchangees ; check_corpus les exige toujours.")


if __name__ == "__main__":
    main()
