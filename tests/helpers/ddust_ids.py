# -*- coding: utf-8 -*-
"""ddust_ids : l'identité d'un joueur de test sur la cible d'essai (module commun des
helpers ddust, pas un outil). Email -> uid Firebase -> userindexes -> userId, clans."""

import datetime
import json

PROJET = "dvddust"


def maintenant():

    return datetime.datetime.now(datetime.timezone.utc)


def iso(d):

    return d.astimezone(datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def existe(base, uid):

    """Vrai si l'uid a une entrée dans Firebase Auth."""
    r = base.s.post("https://identitytoolkit.googleapis.com/v1/projects/%s/accounts:lookup" % PROJET,
                    data=json.dumps({"localId": [uid]}),
                    headers={"Content-Type": "application/json", "X-Goog-User-Project": PROJET})
    r.raise_for_status()
    return bool(r.json().get("users"))


def uid_du_joueur(ctx, alias):

    """L'uid Firebase du téléphone `alias` : son identité de test (dvtest), ou le compte
    Google de son email (`connexion: google`). "" s'il n'existe pas encore."""
    j = ctx.joueur(alias)
    if j.uid:
        return j.uid if existe(ctx.firestore, j.uid) else ""
    return uid_de(ctx.firestore, j.compte.get("email", ""))


def uid_de(base, email):

    r = base.s.post("https://identitytoolkit.googleapis.com/v1/projects/%s/accounts:lookup" % PROJET,
                    data=json.dumps({"email": [email]}),
                    headers={"Content-Type": "application/json", "X-Goog-User-Project": PROJET})
    r.raise_for_status()
    users = r.json().get("users", [])
    return users[0]["localId"] if users else ""


def joueur(ctx, alias):

    """{uid, userId, clans: [clanId...], clan: le premier clan actif} du telephone `alias`."""
    w = ctx.firestore
    uid = uid_du_joueur(ctx, alias)
    if not uid:
        raise RuntimeError("%s n'a pas de compte Firebase" % alias)
    index = w.lit("userindexes/%s" % uid) or {}
    clans = list((index.get("clans") or {}).keys())
    actifs = [c for c in clans if (w.lit("clans/%s" % c) or {}).get("enabled", True) is not False]
    return {"uid": uid, "userId": index.get("userId", ""), "clans": clans,
            "clan": actifs[0] if actifs else (clans[0] if clans else "")}
