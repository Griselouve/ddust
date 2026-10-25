# -*- coding: utf-8 -*-
"""compte_firebase (ddust) : le compte Google d'un telephone a-t-il une entree Firebase Auth ?

    verifs:
      - outil: {nom: compte_firebase, telephone: papa, existe: false}

Rend vrai si l'etat constate est celui attendu (`existe`, vrai par defaut). Sert aux parcours
qui ne doivent RIEN laisser : « Retrouver mon heros » sur un compte inconnu (entree purgee,
config.yml `existing.purge_on_reject: true`), app tuee avant la liaison Google.
"""

from ddust_ids import uid_du_joueur


def run(ctx, telephone, existe=True, **_):

    uid = uid_du_joueur(ctx, telephone)
    ctx.log("BLUE", "\t\t%s : entree Firebase Auth %s" % (telephone, uid or "absente"))
    return bool(uid) == bool(existe)
