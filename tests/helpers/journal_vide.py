# -*- coding: utf-8 -*-
"""journal_vide (ddust) : vide le journal Flutter d'un telephone en cours de test.

    - outil: {nom: journal_vide, telephone: papa}

Pour qu'une verification `journal` ne porte que sur ce qui suit (ONB-08 : le second
lancement ne doit PAS rejouer l'intro).
"""


def run(ctx, telephone, **_):

    ctx.joueur(telephone).tel.journal_vide()
    return True
