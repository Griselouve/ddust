# -*- coding: utf-8 -*-
"""identite (ddust) : un identifiant du joueur d'un telephone, dans une variable.

    - outil: {nom: identite, telephone: enfant, champ: userId, garde: kid}
    - outil: {nom: identite, telephone: enfant, champ: clan,   garde: clan}
    - outil: {nom: identite, telephone: papa,   champ: uid,    garde: uid_papa}

`champ` : uid (Firebase Auth), userId (docId metier de users / clans_players), clan (premier
clan actif de son index). Lu sur la cible d'essai par ddust_ids.joueur. Leve une erreur si
le compte n'a pas encore d'entree Firebase (joueur pas encore connecte a Google).
"""

from ddust_ids import joueur


def run(ctx, telephone, champ="userId", **_):

    j = joueur(ctx, telephone)
    if champ not in j:
        raise RuntimeError("identite : champ inconnu « %s » (uid, userId, clan, clans)" % champ)
    if not j[champ]:
        raise RuntimeError("identite : %s n'a pas de %s sur la cible d'essai" % (telephone, champ))
    ctx.log("BLUE", "\t\t%s.%s = %s" % (telephone, champ, j[champ]))
    return j[champ]
