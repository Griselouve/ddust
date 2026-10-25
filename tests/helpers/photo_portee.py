# -*- coding: utf-8 -*-
"""photo_portee (ddust) : ce qu'une photo emporte pour un compte de test.

Appelé par le moteur (dvtest/photo.py) à l'export d'une photo, avec les uid des
téléphones du test. Rend les racines à photographier, [(base, chemin)] : chaque racine
part avec tout ce qu'elle porte (sous-collections). MÊME PÉRIMÈTRE que reset_comptes,
qui efface ces mêmes documents avant chaque test : ce qu'une photo remet est exactement
ce que la remise à zéro a retiré.

Hors photo, exprès :
  - msgregistry (eut-messaging) : la fiche d'un APPAREIL, réinscrite par l'app au login ;
  - clans_joins : des boîtes d'adhésion de 15 minutes, périmées à la réimportation ;
  - le compte Firebase Auth : recréé par la connexion de test (custom token).
"""

from modules.dvtest.firestore import Base

PROJET = "dvddust"
ESSAI = "eut-"

# Les collections indexées par clan (comme reset_comptes._PAR_CLAN).
_PAR_CLAN = ["clans_tasks", "clans_items", "clans_chest_history", "clans_logs", "clans_players",
             "clans_pulse", "clans_store", "clans_owned", "clans_shop"]


def run(ctx, uids, **_):

    w = Base(PROJET, ESSAI + "workers")
    docs = Base(PROJET, ESSAI + "documents")
    out = []

    def _ajoute(base, chemin):
        if (base, chemin) not in out:
            out.append((base, chemin))

    for uid in uids:
        index = w.lit("userindexes/%s" % uid) or {}
        user_id = index.get("userId", "")
        _ajoute(ESSAI + "workers", "userindexes/%s" % uid)
        clans = list((index.get("clans") or {}).keys())
        if user_id:
            for d in w.cherche("users", "userId", user_id):
                clans += list((d.get("clans") or {}).keys())
        for clan_id in dict.fromkeys(clans):
            clan = w.lit("clans/%s" % clan_id)
            if clan is None:
                continue
            if user_id and (clan.get("founder") == user_id or user_id in (clan.get("admins") or [])):
                _ajoute(ESSAI + "workers", "clans/%s" % clan_id)
                for col in _PAR_CLAN:
                    _ajoute(ESSAI + "workers", "%s/%s" % (col, clan_id))
                _ajoute(ESSAI + "store", "store_mock_clans/%s" % clan_id)
            elif user_id:
                _ajoute(ESSAI + "workers", "clans_players/%s/players/%s" % (clan_id, user_id))
        if user_id:
            _ajoute(ESSAI + "workers", "users/%s" % user_id)
            _ajoute(ESSAI + "workers", "guardianship/%s" % user_id)
            for d in w.cherche("stats_active", "userId", user_id):
                _ajoute(ESSAI + "workers", d["__chemin__"])
        for ident in filter(None, (uid, user_id)):
            # Les CGU acceptées (accepted_versions, legalstate) : sans elles, la reprise
            # repasse par l'écran d'acceptation (dvdocuments hasNewDocuments).
            _ajoute(ESSAI + "documents", "documents_sessions/%s" % ident)
            for d in docs.cherche("documents_acceptance", "ownerId", ident):
                _ajoute(ESSAI + "documents", d["__chemin__"])
        _ajoute(ESSAI + "sessions", "sessions/%s" % uid)
        _ajoute(ESSAI + "store", "store_code_attempts/%s" % uid)
    return out
