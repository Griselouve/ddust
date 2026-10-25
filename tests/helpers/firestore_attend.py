# -*- coding: utf-8 -*-
"""firestore_attend (ddust) : attend qu'un champ d'un document prenne une valeur.

    - outil: {nom: firestore_attend, doc: "clans_players/{clan}/players/{kid}",
              champ: legal_state, egal: t, delai: 120}
    - outil: {nom: firestore_attend, doc: "...", champ: consent_due, non_vide: true}

Pour constater un etat INTERMEDIAIRE au fil des etapes (une verification ne se fait qu'a
la fin du test). `egal` : comparaison en texte ; `non_vide: true` : present et non vide.
Rend la valeur lue ; leve une erreur a l'echeance.
"""

import time

from modules.dvtest.firestore import valeur_a


def run(ctx, doc, champ, egal=None, non_vide=False, delai=120, **_):

    limite = time.time() + float(delai)
    vu = None
    while True:
        d = ctx.firestore.lit(doc) or {}
        vu = valeur_a(d, champ)
        if non_vide and vu not in (None, ""):
            break
        if egal is not None and vu is not None and str(vu) == str(egal):
            break
        if time.time() > limite:
            raise RuntimeError("firestore_attend : %s.%s = %r apres %ss (attendu %s)"
                               % (doc, champ, vu, delai, "non vide" if non_vide else repr(egal)))
        time.sleep(2)
    ctx.log("BLUE", "\t\t%s.%s = %r" % (doc, champ, vu))
    return vu
