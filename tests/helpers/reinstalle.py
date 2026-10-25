# -*- coding: utf-8 -*-
"""reinstalle (ddust) : l'app repart SANS AUCUNE DONNEE LOCALE, au milieu d'un test.

    - outil: {nom: reinstalle, telephone: papa}

Pour les tests qui ont besoin d'un heros DEJA en base puis d'un appareil vierge (ONB-03
« Retrouver son heros », ONB-05 conflit de liaison). `relance` ne suffit pas : l'etat local
(layers, session dvcloud, `worker.*` stores) survit a un simple arret de l'app.

Fait ce que le moteur fait avant un test (moteur.py, `_prepare`), sans toucher aux comptes :
desinstallation + installation de l'APK de test, journal vide (sauf `vide_journal: false`),
lancement, sonde rebranchee, intro marquee vue (sauf `intro: jouee`), puis les valeurs
`poses` de phones.yml et du test (dvtuto.suspended, serveurs d'essai).

Le compte Google de l'emulateur, lui, reste : c'est un compte du systeme, pas de l'app.
"""


def run(ctx, telephone, intro="vue", vide_journal=True, **_):

    j = ctx.joueur(telephone)
    j.tel.installe(ctx.apk, ctx.paquet, propre=True)
    if vide_journal:
        j.tel.journal_vide()
    j.tel.lance(ctx.paquet)
    j.sonde.branche()
    # L'identité de test (connexion sans Google) : la désinstallation l'a effacée avec le
    # reste. Sans elle, l'app retombe sur le vrai écran Google natif (vu le 2026-10-18).
    ctx.moteur.pose_identite(j)
    if intro == "vue":
        j.sonde.pose("worker.intro_seen", "true", "device")
    poses = dict(ctx.config.get("poses", {}) or {})
    poses.update(ctx.test.get("poses", {}) or {})
    for cle, val in poses.items():
        j.sonde.pose(cle, val)
    ctx.log("BLUE", "\t\t%s : app reinstallee sans donnee locale" % telephone)
    return True
