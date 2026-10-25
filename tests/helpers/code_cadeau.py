# -*- coding: utf-8 -*-
"""code_cadeau (ddust) : le clan d'un chef passe sur un palier payant, sans Play.

    - outil: {nom: code_cadeau, telephone: papa, palier: ddust_tribu}

Ce qu'un code cadeau consommé puis ouvert par le balayage laisse dans la projection lue
par le client (`eut-workers/clans_store/{clan}`, dvstore_motor) : un palier actif, un
mois offert. Écrit DIRECTEMENT dans Firestore d'essai (décision du 2026-10-17) : le
plafond de 2 joueurs et le mur de première cotisation ne bloquent plus le test.

⚠ UN CODE SEUL N'OUVRE AUCUN PALIER (`tier` vide), d'où l'écriture du palier lui-même.
⚠ JAMAIS `simulated: true` : le balayage d'essai sauterait ou effacerait le document.

Paliers (build.yml) : ddust_essentiel 2 joueurs, ddust_clan 4, ddust_tribu 7,
ddust_guilde 12, ddust_royaume illimité. Le client relit la projection au plus toutes
les 60 s : le helper attend `attente` secondes (65 par défaut).
"""

import datetime
import time

from ddust_ids import joueur, maintenant


def run(ctx, telephone, palier="ddust_tribu", jours=30, attente=65, **_):

    j = joueur(ctx, telephone)
    if not j["clan"]:
        raise RuntimeError("%s n'a pas de clan" % telephone)
    w = ctx.firestore
    clan = w.lit("clans/%s" % j["clan"]) or {}
    fin = maintenant() + datetime.timedelta(days=int(jours))
    w.ecrit("clans_store/%s" % j["clan"], {
        "ownerId": clan.get("ownerId", ""), "tier": palier, "state": "active",
        "expiry": fin, "credit_active": True, "credit_until": fin, "credit_months": 0,
        "auto_renewing": False, "updated_at": maintenant()})
    ctx.log("BLUE", "\t\tclan %s : palier %s jusqu'au %s" % (j["clan"], palier, fin.date()))
    time.sleep(float(attente))
    return j["clan"]
