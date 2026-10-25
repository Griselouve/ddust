# -*- coding: utf-8 -*-
"""preuve_photo (ddust) : prend la photo de preuve d'une tache, sur l'ecran camera de dvcamera.

    - {tap: combat/ok}
    - outil: {nom: preuve_photo, telephone: enfant}

POURQUOI UNE PHOTO, ET PAS « SANS PREUVE ». Un joueur non chef qui touche « J'ai vaincu le
monstre ! » passe par `_camera.capture()` (worker_combat.dart:426). La preuve n'est zappee
(`noproof`) que si la camera est INDISPONIBLE (dvcamera.dart:137-180 : desktop, aucune camera,
permission refusee). Sur l'emulateur rien de cela n'arrive : l'APK est installe avec `-g`
(adb.py:59-62, permission CAMERA accordee) et l'AVD pixel_7 a une camera arriere emulee. La
touche RETOUR, elle, rend `cancelled` : on_combat_ok s'arrete sans rien changer
(worker_combat.dart:428). Il faut donc vraiment declencher.

LE DECLENCHEUR N'EST PAS UNE SHAPE. L'ecran de prise de vue est une route Flutter poussee par
dvcamera (_DvCaptureScreen, dvcamera.dart:520-570) : un GestureDetector de 84 dp, centre en
bas, 32 dp au-dessus du bord du corps, sous la phrase d'aide `camera_hint`. La sonde ne le
voit pas : on le touche par adb (`input tap`).
  1. si uiautomator voit la phrase d'aide (« Touche pour une photo... »), le declencheur est
     a ~66 dp sous son centre (12 dp de marge + 42 dp de demi-bouton + demi-ligne) ;
  2. sinon, positions calculees depuis `wm size` / `wm density` : bas de l'ecran moins
     74 dp (sans barre de navigation), 98 dp, puis 122 dp (barre a 3 boutons).

REUSSITE = la ligne « [camera] photo enregistree » (dvcamera.dart:187) de plus qu'avant le
geste. Un appui trop long ferait une video (« [camera] video enregistree ») : acceptee aussi,
c'est une preuve valable. Rend le nombre de tentatives.
"""

import re
import time

_AIDE = r"(Touche pour une photo|Tap for a photo|Toca para una foto)"
_FAIT = re.compile(r"\[camera\] (photo|vidéo) enregistrée")


def _taille(tel):

    sortie = tel.shell("wm size")
    m = re.findall(r"(\d+)x(\d+)", sortie)
    w, h = (int(m[-1][0]), int(m[-1][1])) if m else (1080, 2400)
    m = re.findall(r"(\d+)", tel.shell("wm density"))
    dens = int(m[-1]) if m else 420
    return w, h, dens / 160.0


def run(ctx, telephone, delai=60, attente=3, **_):

    j = ctx.joueur(telephone)
    avant = len(_FAIT.findall(j.tel.journal()))
    # Laisser la route camera s'ouvrir (availableCameras + push + initialize).
    time.sleep(float(attente))
    w, h, dp = _taille(j.tel)
    fixes = [h - 74 * dp, h - 98 * dp, h - 122 * dp]
    limite = time.time() + float(delai)
    essai = 0
    while time.time() < limite:
        cibles = []
        try:
            n = j.tel.cherche(_AIDE)
            if n:
                cibles.append(n["centre"][1] + 66 * dp)
        except Exception:
            pass
        cibles += fixes
        y = cibles[essai % len(cibles)]
        essai += 1
        ctx.log("BLUE", "\t\t%s : declencheur camera touche en (%d, %d)" % (telephone, w // 2, int(y)))
        j.tel.tape(w // 2, int(y))
        # La copie de la photo et le retour de la route prennent quelques secondes.
        fin = time.time() + 6
        while time.time() < fin:
            if len(_FAIT.findall(j.tel.journal())) > avant:
                ctx.log("BLUE", "\t\t%s : photo de preuve prise (%d essai(s))" % (telephone, essai))
                return essai
            time.sleep(1)
    ctx.capture(telephone, "camera-sans-photo")
    raise RuntimeError("preuve_photo : aucune photo enregistree sur %s apres %d essai(s)" % (telephone, essai))
