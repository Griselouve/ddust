# -*- coding: utf-8 -*-
"""reset_comptes (ddust) : les comptes de test repartent comme des joueurs neufs.

Appele par le moteur avant chaque test (sauf `reset: false`), avec les comptes des
telephones du test. Pour chaque compte, sur la CIBLE D'ESSAI seulement (bases `eut-*`) :

  1. uid Firebase : l'identite de test (`dvtest-*`), ou le compte Google de son email ;
  2. `userindexes/{uid}` -> userId metier, ses clans ;
  3. chaque clan dont il est fondateur ou chef : le clan ENTIER et tout ce qui est
     indexe par lui (les clans des tests n'ont que des comptes de test) ; ailleurs, sa
     seule fiche de joueur ;
  4. ses documents personnels (users, userindexes, guardianship, documents, sessions,
     messagerie, essais de codes) ;
  5. son compte Firebase Auth. Sans cela, « Je pars a l'aventure » tomberait sur l'ecran
     de conflit (« ce compte Google est deja lie a un heros ») au lieu d'un parcours neuf.

⚠ POURQUOI PAS `delete_user_data`. Le callable exige le jeton du joueur lui-meme, et sa
  suppression est LOGIQUE (enabled:false, pierres tombales, representation close) : le
  meme userId reviendrait, avec une representation d'enfant fermee.

⚠ L'ANNUAIRE AUTH EST COMMUN A LA PRODUCTION ET A L'ESSAI. Seuls les emails de la
  reserve de test (apps_tests/ddust) passent ici, et le moteur ne connait qu'eux. Le
  helper verifie en lecture que le compte n'a rien en production (`eu-workers`) et
  s'arrete sinon.
"""

import json

from modules.dvtest.firestore import Base

PROJET = "dvddust"
ESSAI = "eut-"

# Les collections indexees par clan (build.yml, reset.firestore, &worker_collections).
_PAR_CLAN = ["clans_tasks", "clans_items", "clans_chest_history", "clans_logs", "clans_players",
             "clans_pulse", "clans_store", "clans_owned", "clans_shop"]


def _identite(s, email):

    r = s.post("https://identitytoolkit.googleapis.com/v1/projects/%s/accounts:lookup" % PROJET,
               data=json.dumps({"email": [email]}),
               headers={"Content-Type": "application/json", "X-Goog-User-Project": PROJET})
    r.raise_for_status()
    users = r.json().get("users", [])
    return users[0]["localId"] if users else ""


def _efface_auth(s, uid):

    r = s.post("https://identitytoolkit.googleapis.com/v1/projects/%s/accounts:delete" % PROJET,
               data=json.dumps({"localId": uid}),
               headers={"Content-Type": "application/json", "X-Goog-User-Project": PROJET})
    r.raise_for_status()


def _efface_clan(w, store, clan_id, log):

    n = 0
    for col in _PAR_CLAN:
        n += w.efface_tout("%s/%s" % (col, clan_id))
    n += w.efface_tout("clans/%s" % clan_id)
    n += store.efface_tout("store_mock_clans/%s" % clan_id)
    log("BLUE", "\t\treset : clan %s efface (%d document(s))" % (clan_id, n))


def run(ctx, comptes, **_):

    w = Base(PROJET, ESSAI + "workers")
    store = Base(PROJET, ESSAI + "store")
    docs = Base(PROJET, ESSAI + "documents")
    sessions = Base(PROJET, ESSAI + "sessions")
    msg = Base(PROJET, ESSAI + "messaging")
    prod = Base(PROJET, "eu-workers", lecture_seule=True)
    s = w.s

    for compte in comptes:
        email = compte.get("email", "")
        # L'identité de test (uid `dvtest-*`) quand le moteur en a une, le compte Google
        # de l'email sinon (`connexion: google`).
        uid = compte.get("uid", "")
        auth = True
        if uid:
            r = s.post("https://identitytoolkit.googleapis.com/v1/projects/%s/accounts:lookup" % PROJET,
                       data=json.dumps({"localId": [uid]}),
                       headers={"Content-Type": "application/json", "X-Goog-User-Project": PROJET})
            r.raise_for_status()
            # Une identité de test SANS compte Auth peut avoir des documents : ceux d'une
            # photo réimportée (photo.py ne crée pas le compte Auth, la connexion de test
            # le fait) dont le test s'est arrêté avant de se connecter. On les efface quand
            # même (vu le 2026-10-18 : l'onboarding suivant retrouvait l'ancien userindexes).
            auth = bool(r.json().get("users"))
            if not auth and not uid.startswith("dvtest-"):
                uid = ""
        else:
            uid = _identite(s, email)
        if not uid:
            ctx.log("BLUE", "\t\treset : %s n'a pas de compte Firebase, rien a faire" % email)
            continue
        if prod.lit("userindexes/%s" % uid):
            raise RuntimeError("reset refuse : %s a des donnees en PRODUCTION (eu-workers/userindexes/%s)"
                               % (email, uid))

        index = w.lit("userindexes/%s" % uid) or {}
        user_id = index.get("userId", "")
        clans = list((index.get("clans") or {}).keys())
        if user_id:
            for d in w.cherche("users", "userId", user_id):
                clans += list((d.get("clans") or {}).keys())
        for clan_id in dict.fromkeys(clans):
            clan = w.lit("clans/%s" % clan_id)
            if clan is None:
                continue
            if user_id and (clan.get("founder") == user_id or user_id in (clan.get("admins") or [])):
                _efface_clan(w, store, clan_id, ctx.log)
            elif user_id:
                w.efface_tout("clans_players/%s/players/%s" % (clan_id, user_id))

        if user_id:
            w.efface_tout("users/%s" % user_id)
            w.efface_tout("guardianship/%s" % user_id)
            for d in w.cherche("stats_active", "userId", user_id):
                w.efface(d["__chemin__"])
        w.efface_tout("userindexes/%s" % uid)
        for ident in filter(None, (uid, user_id)):
            docs.efface_tout("documents_sessions/%s" % ident)
            for d in docs.cherche("documents_acceptance", "ownerId", ident):
                docs.efface(d["__chemin__"])
        sessions.efface_tout("sessions/%s" % uid)
        for d in msg.cherche("msgregistry", "ownerId", uid):
            msg.efface(d["__chemin__"])
        store.efface_tout("store_code_attempts/%s" % uid)
        if auth:
            _efface_auth(s, uid)
        ctx.log("BLUE", "\t\treset : %s remis a zero (uid %s, joueur %s)" % (email, uid, user_id or "-"))
    return True
