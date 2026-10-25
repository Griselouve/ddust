# -*- coding: utf-8 -*-
"""bou_faux_store (ddust) : pilote le faux Google Play de la cible d'essai (pustoremock).

    - outil: {nom: bou_faux_store, telephone: papa, quoi: inscrire, code: "{mock_code}"}
    - outil: {nom: bou_faux_store, telephone: papa, quoi: payer}

Remplace les deux gestes humains du pilotage `storemock_ui` (pustoremock/config.yml) :
  inscrire  POST /admin/clans/add {code: "<clan>:<uid>"} (l. 1358, addClan l. 855) : le clan
            passe au faux store (eut-store/store_mock_clans/{clan}). Le code est la valeur
            Deva `store.mock.code` (dvstore_motor.dart:1379), que montre la tuile « Mon ID ».
  payer     GET /admin/sheets (l. 1324) jusqu'à la feuille en attente du compte du
            téléphone, puis POST /admin/action {token, action: sheet_pay} (l. 743-750).
            La feuille s'abandonne d'elle-même après 170 s (SHEET_TIMEOUT) : `delai` reste
            en dessous.

L'adresse de la fonction : la valeur Deva `cloud.cloud_functions.eut-storemock`, lue par
la sonde (celle que lit dvstore, dvstore_motor.dart:492), ou `url:`.
La clé du pilotage : Secret Manager `<projet>__storemock_pilot_key`
(bld_storemock.py:189-226), lue par ADC, ou `cle:`. Envoyée en `x-storemock-key` (l. 279).
"""

import base64
import time

import requests

from modules.dvtest.firestore import session

PROJET = "dvddust"


def _cle(projet):

    s = session()
    r = s.get("https://secretmanager.googleapis.com/v1/projects/%s/secrets/%s__storemock_pilot_key"
              "/versions/latest:access" % (projet, projet))
    r.raise_for_status()
    return base64.b64decode(r.json()["payload"]["data"]).decode("utf-8")


def run(ctx, telephone, quoi, code="", url="", cle="", projet=PROJET, region="eut", delai=150, **_):

    j = ctx.joueur(telephone)
    url = (url or str(j.sonde.lit("cloud.cloud_functions.%s-storemock" % region) or "")).rstrip("/")
    if not url or url == "None":
        raise RuntimeError("bou_faux_store : adresse du faux store inconnue (storemock non déployé ?)")
    h = {"x-storemock-key": cle or _cle(projet), "Content-Type": "application/json"}

    if quoi == "inscrire":
        if not code:
            raise RuntimeError("bou_faux_store : code « clan:joueur » vide (store.mock.code)")
        r = requests.post(url + "/admin/clans/add", json={"code": code}, headers=h, timeout=30)
        if r.status_code != 200:
            raise RuntimeError("bou_faux_store : inscription refusée (%s) %s" % (r.status_code, r.text[:200]))
        ctx.log("BLUE", "\t\tfaux store : clan inscrit (%s)" % code)
        return code

    if quoi == "payer":
        email = (j.compte.get("email", "") or "").lower()
        limite = time.time() + float(delai)
        while time.time() < limite:
            r = requests.get(url + "/admin/sheets", headers=h, timeout=30)
            r.raise_for_status()
            feuilles = [f for f in r.json().get("sheets", [])
                        if not email or str(f.get("account", "")).lower() == email]
            if feuilles:
                jeton = feuilles[-1]["token"]
                p = requests.post(url + "/admin/action", json={"token": jeton, "action": "sheet_pay"},
                                  headers=h, timeout=30)
                if p.status_code != 200:
                    raise RuntimeError("bou_faux_store : paiement refusé (%s) %s" % (p.status_code, p.text[:200]))
                ctx.log("BLUE", "\t\tfaux store : feuille %s payée (%s)" % (jeton[:20], feuilles[-1].get("product")))
                return jeton
            time.sleep(3)
        raise RuntimeError("bou_faux_store : aucune feuille de paiement pour %s en %ss" % (email, delai))

    raise RuntimeError("bou_faux_store : quoi inconnu « %s » (inscrire, payer)" % quoi)
