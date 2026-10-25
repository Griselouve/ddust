# -*- coding: utf-8 -*-
"""but_objet (ddust) : pose un objet dans l'inventaire d'un joueur, rend son identifiant.

    - outil: {nom: but_objet, telephone: papa, type: potion_pv, cout: 20, garde: objet}

Un clan neuf n'a aucun objet donnable ni déposable : seulement le coffre (`butin`), sa
bourse (`wallet`) et la bourse de chaque joueur (`wallet_<userId>`). Les objets naissent
d'un événement « bienfaiteur » (worker_events.dart:522-528) ou d'un palier de titre
(worker_items.dart:781-795) : on écrit donc l'objet comme le fait `_writeButinDoc`
(worker_butin.dart:140-154), dans `clans_items/{clan}/items/{id}` :
  ownerId = secret du clan (`clans/{clan}.ownerId`, exigé par les règles), type, owner =
  userId du joueur, quantity, cost (valeur, pèse dans le partage du butin).

Le joueur doit RECHARGER l'onglet Items (`testme`) pour que le miroir local le connaisse
(worker_items.dart:138-160) : y aller APRÈS cet outil.
"""

import secrets

from ddust_ids import joueur


def run(ctx, telephone, type="potion_pv", cout=20, nom_objet="", **_):

    j = joueur(ctx, telephone)
    if not j["clan"] or not j["userId"]:
        raise RuntimeError("but_objet : %s n'a pas de clan" % telephone)
    w = ctx.firestore
    clan = w.lit("clans/%s" % j["clan"]) or {}
    secret = clan.get("ownerId", "")
    if not secret:
        raise RuntimeError("but_objet : clan %s sans secret (ownerId)" % j["clan"])
    ident = "dvtest_%s" % secrets.token_hex(4)
    doc = {"ownerId": secret, "type": type, "owner": j["userId"], "quantity": 1, "cost": int(cout)}
    if nom_objet:
        doc["name"] = nom_objet
    w.ecrit("clans_items/%s/items/%s" % (j["clan"], ident), doc)
    ctx.log("BLUE", "\t\tobjet %s (%s) pour %s dans le clan %s" % (ident, type, j["userId"], j["clan"]))
    return ident
