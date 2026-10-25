# -*- coding: utf-8 -*-
"""lien_event (ddust) : les paramètres d'un lien `ddust://...`, en dictionnaire.

    - outil: {nom: lien_event, url: "{patte}", garde: ev}
    - papa:  {action: worker.on_join_link, event: "{ev}"}

Ce que dvdeeplink passe à l'action d'une route (dvdeeplink_motor.dart : les paramètres de
l'URL en Map). Sert à donner un QR lu au chef SANS passer par un lien profond Android :
ouvrir un lien met l'app en pause un instant (page masquée), ce que le lecteur de QR
intégré ne fait pas. Constat du 2026-10-18 (CLN-05) : par ce chemin, l'erreur posée par
le contrôle de région était aussitôt masquée par la réapparition de la page.
"""

from urllib.parse import parse_qsl, urlparse


def run(ctx, url, **_):

    return dict(parse_qsl(urlparse(url).query, keep_blank_values=True))
