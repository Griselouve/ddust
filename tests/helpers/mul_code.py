# -*- coding: utf-8 -*-
"""mul_code (ddust) : le code d'une phrase affichée, dans une variable.

    - outil: {nom: mul_code, telephone: tonton, shape: guardian_qr_page/code, garde: pin}
    - outil: {nom: mul_code, telephone: maman, shape: join_show_screen/code, motif: join, garde: code}

Certaines shapes ne montrent pas le code seul mais une phrase qui le contient (ex.
`guardian_qr_code` : « Code : {code} », worker_multiclan.dart ; `join_show_code` : « Ton code :
48E-D8 », worker_join.dart). Lit le texte par la sonde et rend le premier code trouvé :

  - par défaut, la première suite de `chiffres` chiffres (6 par défaut) ;
  - `motif: join` : le code d'une boîte d'adhésion, cinq caractères de l'alphabet sans
    0 O 1 I L, affiché en deux groupes (« 48E-D8 ») ; rendu SANS le tiret (« 48ED8 »),
    l'identifiant de la boîte (`clans_joins/{code}`) ;
  - `motif: <regex>` : une expression à un groupe, rendue telle quelle.
"""

import re
import time

_JOIN = r"(?<![A-Z0-9])([A-HJKMNP-Z2-9]{3})-([A-HJKMNP-Z2-9]{2})(?![A-Z0-9])"


def run(ctx, telephone, shape, chiffres=6, motif="", delai=30, **_):

    j = ctx.joueur(telephone)
    if motif == "join":
        rx = re.compile(_JOIN)
    elif motif:
        rx = re.compile(motif)
    else:
        rx = re.compile(r"(?<!\d)(\d{%d})(?!\d)" % int(chiffres))
    limite = time.time() + float(delai)
    texte = ""
    while time.time() < limite:
        texte = str(j.sonde.shape(shape).get("text", "") or "")
        m = rx.search(texte)
        if m:
            code = "".join(m.groups()) if motif == "join" else m.group(1)
            ctx.log("BLUE", "\t\tcode lu sur %s : %s" % (shape, code))
            return code
        # Le texte n'est pas traduit (clé brute « join_show_code ») : le code se lit alors
        # dans le QR de la même boîte (`c=`). DÉFAUT DE L'APP signalé le 2026-10-18 : avant le
        # choix du royaume, l'app prend le thème du bucket de PRODUCTION, plus ancien que sa
        # copie embarquée ; un snapshot dont les textes ne sont pas encore en production les
        # affiche en clés. Ce repli laisse avancer les tests qui ont besoin du code ; le test
        # qui vérifie le texte affiché (ONB-02) reste, lui, en échec.
        if motif == "join" and texte.strip() == "join_show_code":
            qr = str(j.sonde.shape("join_show_screen/qrcode").get("content", "") or "")
            m = re.search(r"[?&]c=([A-HJKMNP-Z2-9]{5})(?:&|$)", qr)
            if m:
                ctx.log("YELLOW", "		code NON affiché (clé brute) : lu dans le QR : %s" % m.group(1))
                return m.group(1)
        time.sleep(1)
    raise RuntimeError("mul_code : aucun code (%s) sur %s (%r)" % (motif or "%s chiffres" % chiffres, shape, texte[:80]))
