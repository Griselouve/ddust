# -*- coding: utf-8 -*-
"""code_test (ddust) : fabrique un code cadeau de test et rend sa valeur en clair.

    - outil: {nom: code_test, telephone: papa, mois: 1, garde: code}
    - outil: {nom: code_test, telephone: papa, etat: expire, garde: perime}

Écrit directement `eut-store/store_codes/{sha256(code normalisé)}`, ce que ferait
`store_mint` (pustore/config.yml, l. 1566-1580), sans passer par le callable (qui exige
un jeton d'éditeur, l. 1521-1526). Le code est relu par `store_claim` (l. 1276-1416),
dont la base est `<deva_regions.primary>-store`, soit `eut-store` à l'essai.

Normalisation (l. 1151-1157) : majuscules, tout ce qui n'est pas [0-9A-Z] retiré,
I/L -> 1, O -> 0. Le code tiré est dans l'alphabet Crockford (l. 1504), sans I, L, O ni
U : sa forme normalisée est lui-même, sans les tirets. On rend la forme affichée
« XXXX-XXXX-XXXX » (l. 1520), celle qu'un parent recopie.

`etat` : ""        un code neuf, valable (verdict `ok`) ;
         expire    `expires_at` d'hier (verdict `expired`, l. 1351) ;
         revoque   `revoked: true` (verdict `invalid`, l. 1313) ;
         epuise    `uses = max_uses` (verdict `exhausted`, l. 1355).

Un code est consommé une fois par clan (`claims/{scopeId}`) : le présenter une seconde
fois rend `used` (l. 1347). Les codes de test restent dans eut-store (libellé `dvtest`).
"""

import datetime
import hashlib
import secrets

from ddust_ids import maintenant
from modules.dvtest.firestore import Base

ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
LONGUEUR = 12


def normalise(brut):

    s = "".join(c for c in str(brut or "").upper() if c.isascii() and c.isalnum())
    return s.replace("I", "1").replace("L", "1").replace("O", "0")


def run(ctx, telephone="", mois=1, max_uses=1, etat="", code="", **_):

    brut = code or "".join(secrets.choice(ALPHABET) for _ in range(LONGUEUR))
    norme = normalise(brut)
    affiche = "%s-%s-%s" % (norme[0:4], norme[4:8], norme[8:12]) if len(norme) == 12 else norme
    empreinte = hashlib.sha256(norme.encode("utf-8")).hexdigest()
    doc = {"label": "dvtest", "batch": "dvtest", "reward": "months", "months": int(mois),
           "max_uses": int(max_uses), "uses": 0, "hint": affiche[-4:],
           "created_at": maintenant(), "created_by": "dvtest"}
    if etat == "expire":
        doc["expires_at"] = maintenant() - datetime.timedelta(days=1)
    elif etat == "revoque":
        doc["revoked"] = True
    elif etat == "epuise":
        doc["uses"] = int(max_uses)
    elif etat:
        raise RuntimeError("code_test : etat inconnu « %s »" % etat)
    store = Base(ctx.firestore.projet, "eut-store")
    store.ecrit("store_codes/%s" % empreinte, doc)
    ctx.log("BLUE", "\t\tcode de test %s (%s mois, %s) pour %s" % (affiche, mois, etat or "neuf", telephone))
    return affiche
