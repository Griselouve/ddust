# -*- coding: utf-8 -*-
"""bou_cotisation (ddust) : amène le clan au seuil de la première cotisation.

    - outil: {nom: bou_cotisation, telephone: papa}

Le mur se calcule depuis `clans/{clan}` (worker_store.dart:1007-1099) :
  validations          tâches validées par le clan (+1 par validation, l. 956-975) ;
  validations_anchor   le compteur quand le clan a cessé d'être seul ;
  due = validations >= ancre + store.pitch.after_growth (3) pour un clan constitué.
On pose validations = 3 et validations_anchor = "0" : trois validations à deux, sans jouer
trois tâches (c'est le parcours des tests `taches`). `pitch_defers` et `pitch_due_since`
sont remis à vide : la présentation compte un report à chaque session (l. 1181-1207).
Le mur paraît au prochain passage au dashboard (worker_screen_tiroir.dart:135-145).
"""

from ddust_ids import joueur


def run(ctx, telephone, validations=3, ancre=0, **_):

    j = joueur(ctx, telephone)
    if not j["clan"]:
        raise RuntimeError("bou_cotisation : %s n'a pas de clan" % telephone)
    ctx.firestore.ecrit("clans/%s" % j["clan"], {
        "validations": int(validations), "validations_anchor": str(int(ancre)),
        "pitch_defers": "0", "pitch_due_since": ""})
    ctx.log("BLUE", "\t\tclan %s : %s validation(s), ancre %s" % (j["clan"], validations, ancre))
    return j["clan"]
