# -*- coding: utf-8 -*-
"""cnf_notif (ddust) : constate le silence des notifications d'un téléphone (vérification).

    verifs:
      - outil: {nom: cnf_notif, telephone: papa, muted: false, clan_coupe: false}

Les réglages « notifications » du kebab Personnage n'écrivent rien en local : ils posent la
fiche de l'APPAREIL dans `eut-messaging/msgregistry/{deviceId}` (dvmessaging_motor.dart:740-762) :
  muted         true = tout coupé sur ce téléphone ;
  muted_scopes  les clans coupés (clanId).
La fiche est retrouvée par `ownerId` = uid Firebase du compte (comme reset_comptes).
`muted` / `clan_coupe` : ce qu'on attend (omis = non vérifié). Rend True si conforme.
"""

from ddust_ids import joueur
from modules.dvtest.firestore import Base


def run(ctx, telephone, muted=None, clan_coupe=None, exige=False, **_):

    """`exige: true` : lève une erreur si non conforme (usage en ÉTAPE, où le résultat
    d'un outil n'est pas vérifié)."""
    ok = _verifie(ctx, telephone, muted, clan_coupe)
    if exige and not ok:
        raise RuntimeError("cnf_notif : %s n'est pas muted=%s clan_coupe=%s" % (telephone, muted, clan_coupe))
    return ok


def _verifie(ctx, telephone, muted, clan_coupe):

    j = joueur(ctx, telephone)
    msg = Base(ctx.firestore.projet, "eut-messaging")
    fiches = msg.cherche("msgregistry", "ownerId", j["uid"])
    if not fiches:
        raise RuntimeError("cnf_notif : aucune fiche msgregistry pour %s (uid %s)" % (telephone, j["uid"]))
    for f in fiches:
        m = f.get("muted") is True
        c = j["clan"] in (f.get("muted_scopes") or [])
        ok = (muted is None or m == bool(muted)) and (clan_coupe is None or c == bool(clan_coupe))
        ctx.log("BLUE", "\t\tmsgregistry/%s : muted=%s clan coupé=%s" % (f["__id__"], m, c))
        if ok:
            return True
    return False
