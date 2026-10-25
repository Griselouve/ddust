# -*- coding: utf-8 -*-
"""url_param (ddust) : remplace un parametre d'un lien profond, dans une variable.

    - outil: {nom: url_param, url: "{invitation}", param: region, valeur: us, garde: forge}

Le reste du lien est garde tel quel (pas de re-encodage). Un parametre absent est ajoute.
"""

import re


def run(ctx, url, param, valeur, **_):

    motif = r"([?&]%s=)[^&]*" % re.escape(param)
    if re.search(motif, url):
        out = re.sub(motif, lambda m: m.group(1) + str(valeur), url, count=1)
    else:
        out = url + ("&" if "?" in url else "?") + "%s=%s" % (param, valeur)
    ctx.log("BLUE", "\t\tlien : %s=%s" % (param, valeur))
    return out
