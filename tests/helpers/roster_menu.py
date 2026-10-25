# -*- coding: utf-8 -*-
"""roster_menu (ddust) : les options du menu d'une tuile du roster, vues par un telephone.

    - outil: {nom: roster_menu, telephone: papa, cible: {id: "{kid}", name: Kid, legal_state: k, ...},
              garde: options}
    verifs:
      - outil: {nom: roster_menu, telephone: papa, cible: {...}, absent: [promote_chief], present: [player_log]}
      - outil: {nom: roster_menu, telephone: enfant, cible: {...}, vide: true}

Les options du menu `clan_page/roster_menu` (DvMenu, non tapable) sont choisies par son
selecteur `worker.clan_selector` (registry_clan_page.yml:1066, worker_screen_clan.dart:512),
qui recoit la ligne du joueur poussee au DvRoster (`_refreshRoster`,
worker_screen_clan.dart:367-417 : id, name, legal_state, admin, founder, original_clan,
no_account, dead, has_device, xp...). On l'appelle par la sonde avec cette ligne (`cible`).

La sonde n'attend une action que 2 s (dvtestprobe.dart:247-261) ; le selecteur lit la session
et le doc clan : un premier appel peut revenir sans resultat. On rappelle jusqu'a `essais`
fois (les lectures sont alors en cache).

Sans `absent`/`present`/`vide` : rend la liste `selectable`. Avec : rend vrai si toutes les
conditions tiennent (pour une verification), et journalise ce qui a ete vu. `strict: true` :
leve une erreur au lieu de rendre faux, pour constater le menu AU MILIEU des etapes (le
resultat d'un outil d'etape n'est pas controle par le moteur).
"""

import time


def _liste(v):

    if v is None:
        return []
    return list(v) if isinstance(v, (list, tuple)) else [v]


def run(ctx, telephone, cible, absent=None, present=None, vide=None, strict=False, essais=8, **_):

    j = ctx.joueur(telephone)
    vu = None
    for _i in range(int(essais)):
        r = j.sonde.action("worker.clan_selector", cible)
        if r.get("ok") and r.get("done") and isinstance(r.get("result"), dict):
            vu = r["result"]
            break
        time.sleep(1.5)
    if vu is None:
        raise RuntimeError("roster_menu : worker.clan_selector sans reponse sur %s" % telephone)
    options = [str(o) for o in (vu.get("selectable") or [])]
    grises = [str(o) for o in (vu.get("disabled") or [])]
    ctx.log("BLUE", "\t\troster_menu %s sur %s : %s (grisees : %s)"
            % (telephone, (cible or {}).get("name", "?"), options, grises))
    if absent is None and present is None and vide is None:
        return options
    ok = True
    for o in _liste(absent):
        if o in options:
            ctx.log("RED", "\t\troster_menu : option « %s » proposee, attendue absente" % o)
            ok = False
    for o in _liste(present):
        if o not in options:
            ctx.log("RED", "\t\troster_menu : option « %s » absente, attendue proposee" % o)
            ok = False
    if vide is not None and bool(vide) != (not options and not grises):
        ctx.log("RED", "\t\troster_menu : menu %s, attendu %s"
                % ("vide" if not options else "non vide", "vide" if vide else "non vide"))
        ok = False
    if strict and not ok:
        raise RuntimeError("roster_menu : menu inattendu sur %s : %s" % (telephone, options))
    return ok
