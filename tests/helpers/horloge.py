# -*- coding: utf-8 -*-
"""horloge (ddust) : fait passer le temps, en reculant des dates dans Firestore d'essai.

    - outil: {nom: horloge, telephone: enfant, quoi: mort}
    - outil: {nom: horloge, telephone: papa, quoi: butin}
    - outil: {nom: horloge, telephone: maman, quoi: code_join, code: "{code}"}
    - outil: {nom: horloge, telephone: enfant, quoi: demande_7j}
    - outil: {nom: horloge, telephone: enfant, quoi: consentement}

  mort          clans_players/{clan}/players/{joueur}.last_task à J-11 : PV affichés à 0
                (pv 10, decay 1 jour). Constatée au prochain dashboard ou Personnage.
  butin         clans/{clan}.butin_xp = last_butin_xp + 500 : jauge pleine.
  code_join     la boîte d'adhésion `clans_joins/{code}` échue (expires_at et expiration une
                heure en arrière) : le chef qui la réclame ou y dépose est refusé. Le candidat
                peut être encore anonyme : aucun joueur n'est lu.
  demande_7j    les demandes d'autres clans de l'enfant (guardianship/{enfant}.join_requests,
                multiclan) échues : 7 jours et 1 heure en arrière.
  consentement  retrait de consentement de l'enfant échu (guardianship.consent.withdrawn_at
                et consent_due de ses fiches) : 3 jours et 1 heure en arrière.
"""

import datetime

from ddust_ids import iso, joueur, maintenant


def run(ctx, telephone, quoi, code="", **_):

    w = ctx.firestore
    if quoi == "code_join":
        if not code:
            raise RuntimeError("horloge code_join : il faut `code:` (lu par mul_code, motif join)")
        passe = maintenant() - datetime.timedelta(hours=1)
        w.ecrit("clans_joins/%s" % code, {"expires_at": iso(passe), "expiration": passe})
        ctx.log("BLUE", "		horloge : boîte %s échue" % code)
        return code
    j = joueur(ctx, telephone)
    clan = j["clan"]
    if quoi == "mort":
        w.ecrit("clans_players/%s/players/%s" % (clan, j["userId"]),
                {"last_task": iso(maintenant() - datetime.timedelta(days=11))})
    elif quoi == "butin":
        c = w.lit("clans/%s" % clan) or {}
        w.ecrit("clans/%s" % clan, {"butin_xp": int(c.get("last_butin_xp") or 0) + 500})
    elif quoi == "demande_7j":
        echu = maintenant() - datetime.timedelta(days=7, hours=1)
        g = w.lit("guardianship/%s" % j["userId"]) or {}
        for jid, req in (g.get("join_requests") or {}).items():
            if isinstance(req, dict) and req.get("status") == "pending":
                w.ecrit("guardianship/%s" % j["userId"], {"join_requests.%s.expires_at" % jid: iso(echu)})
    elif quoi == "consentement":
        echu = maintenant() - datetime.timedelta(days=3, hours=1)
        w.ecrit("guardianship/%s" % j["userId"], {"consent.withdrawn_at": iso(echu)})
        for c in j["clans"]:
            if w.lit("clans_players/%s/players/%s" % (c, j["userId"])):
                w.ecrit("clans_players/%s/players/%s" % (c, j["userId"]),
                        {"consent_due": iso(maintenant() - datetime.timedelta(hours=1))})
    else:
        raise RuntimeError("horloge : quoi inconnu « %s »" % quoi)
    ctx.log("BLUE", "\t\thorloge : %s (clan %s, joueur %s)" % (quoi, clan, j["userId"]))
    return clan
