# -*- coding: utf-8 -*-
"""mul_demande (ddust) : attend qu'une demande d'entrée dans un autre clan (multiclan)
prenne un statut, dans la représentation de l'enfant.

    - outil: {nom: mul_demande, kid: "{kid}", statut: closed, delai: 180}

`guardianship/{kid}.join_requests.{joinId}.status` (worker_multiclan.dart) :
pending -> accepted | refused, puis, appliqué par l'app de l'enfant : closed (refusée),
expired (7 jours passés), used (entrée faite), lost.

Remplace l'attente de la ligne « [guardian] notif guest_*_notif » : elle n'est écrite que
si le chef du clan B a un jeton de notification, ce qu'un émulateur de test n'a pas.
Rend le joinId de la demande trouvée.
"""

import time

from modules.dvtest.firestore import valeur_a


def run(ctx, kid, statut, delai=180, **_):

    limite = time.time() + float(delai)
    vus = {}
    while True:
        g = ctx.firestore.lit("guardianship/%s" % kid) or {}
        demandes = valeur_a(g, "join_requests") or {}
        vus = {jid: (d or {}).get("status") for jid, d in demandes.items() if isinstance(d, dict)}
        for jid, st in vus.items():
            if str(st) == str(statut):
                ctx.log("BLUE", "\t\tdemande %s : %s" % (jid, st))
                return jid
        if time.time() > limite:
            raise RuntimeError("mul_demande : aucune demande « %s » pour %s apres %ss (vu %r)"
                               % (statut, kid, delai, vus))
        time.sleep(2)
