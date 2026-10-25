# -*- coding: utf-8 -*-
"""bou_impaye (ddust) : met le clan d'un chef dans une phase d'impayé, sans Play.

    - outil: {nom: bou_impaye, telephone: papa, phase: soft}
    - outil: {nom: bou_impaye, telephone: papa, phase: ""}      # régularisé

Écrit dans `eut-workers/clans_store/{clan}` ce que le balayage de pustore y laisse
(pustore/config.yml, l. ~3615-3646 ; STORE_LIFECYCLE dans backend/config.yml l. 1327) :
  dunning_phase  soft (J10-19), firm (J20-39), last (J40-49), farewell (J750-780) ;
  state          grace pour soft, hold au-delà (états à droit maintenu, dvstore_motor:1270) ;
  default_since  maintenant moins le jour de début de la phase ;
  tier, expiry   un abonnement échu, comme Play en défaut.
Le client ne lit QUE `dunning_phase` (dvstore_motor.dart:784 → store.subscription.dunning_phase,
worker_store.dart:530). Phase vide : retour à `active`, le bandeau tombe.

⚠ JAMAIS `locked` (J50) : ce serait le gel du donjon (locked_page), pas un bandeau.
⚠ JAMAIS `simulated: true` : le balayage d'essai effacerait le document.
Le client relit la projection à son lancement : relancer l'app après l'outil.
"""

import datetime

from ddust_ids import joueur, maintenant

_DEBUT = {"soft": 10, "firm": 20, "last": 40, "farewell": 750}


def run(ctx, telephone, phase="soft", palier="ddust_essentiel", **_):

    if phase and phase not in _DEBUT:
        raise RuntimeError("bou_impaye : phase inconnue « %s » (soft, firm, last, farewell, \"\")" % phase)
    j = joueur(ctx, telephone)
    if not j["clan"]:
        raise RuntimeError("bou_impaye : %s n'a pas de clan" % telephone)
    w = ctx.firestore
    clan = w.lit("clans/%s" % j["clan"]) or {}
    now = maintenant()
    doc = {"ownerId": clan.get("ownerId", ""), "tier": palier, "updated_at": now}
    if phase:
        doc.update({"state": "grace" if phase == "soft" else "hold", "dunning_phase": phase,
                    "default_since": now - datetime.timedelta(days=_DEBUT[phase]),
                    "expiry": now - datetime.timedelta(days=_DEBUT[phase]),
                    "auto_renewing": True})
    else:
        doc.update({"state": "active", "dunning_phase": "",
                    "expiry": now + datetime.timedelta(days=30), "auto_renewing": True})
    w.ecrit("clans_store/%s" % j["clan"], doc)
    ctx.log("BLUE", "\t\tclan %s : impayé phase=%s" % (j["clan"], phase or "(aucune)"))
    return j["clan"]
