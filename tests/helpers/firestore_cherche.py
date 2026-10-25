# -*- coding: utf-8 -*-
"""firestore_cherche (ddust) : un champ du premier document qui repond a une requete.

    - outil: {nom: firestore_cherche, collection: players, groupe: true,
              champ: name, egal: Lou, lire: id, garde: lou}

`lire` : un champ (chemin pointe accepte) ; `__id__` pour l'identifiant du document,
`__chemin__` pour son chemin complet. Attend jusqu'a `delai` secondes que le document
paraisse (ecriture du client encore en vol).
"""

import time

from modules.dvtest.firestore import valeur_a


def run(ctx, collection, champ, egal, lire="__id__", groupe=False, delai=30, **_):

    limite = time.time() + float(delai)
    while True:
        docs = ctx.firestore.cherche(collection, champ, egal, groupe=bool(groupe))
        if docs:
            d = docs[0]
            v = d.get(lire) if lire.startswith("__") else valeur_a(d, lire)
            ctx.log("BLUE", "\t\t%s[%s=%r].%s = %r" % (collection, champ, egal, lire, v))
            return v
        if time.time() > limite:
            raise RuntimeError("firestore_cherche : aucun document %s %s = %r" % (collection, champ, egal))
        time.sleep(2)
