"""
alpha_tools.py — Ce qu'il faut faire à une image APRÈS `remove_bg`.

Pourquoi ce fichier existe
---------------------------------------------------------------------------------------
`rembg` segmente par réseau de neurones : il rend un masque de PROBABILITÉ, pas un
découpage net. Sur un sujet fin et métallique — une lame d'épée sur fond uni — sa
confiance reste basse PARTOUT, y compris au milieu du sujet. Relevé du 2026-09-13 sur
`sword_left.png` :

    alpha >=   1 : 7,57 % des pixels      <- le sujet, contour compris
    alpha >= 224 : 2,50 %
    alpha >= 255 : 0,17 %                 <- presque rien n'est franchement opaque

À l'écran, l'épée entière était translucide et laissait voir le bouclier au travers.

Et `rembg` rend l'image ENTIÈRE, sujet minuscule au milieu. Une épée qui n'occupe que 7 %
de son carré arrive sept fois trop petite, quelle que soit la boîte qu'on lui donne : le
cadrage `RATIO_IN` ajuste l'IMAGE, pas ce qu'elle contient.

Les deux fonctions ci-dessous se chaînent après `remove_bg` dans `traitements:`.

⚠ ELLES SUPPOSENT UN DÉTOURAGE EN AMONT. Sur une image opaque, `opacify` ne trouve rien à
  durcir et `trim` aucun vide à retirer : elles rendent alors l'image inchangée plutôt que
  d'échouer — une chaîne mal ordonnée ne doit pas casser un build — mais l'ordre juste
  reste `remove_bg`, puis celles-ci.
"""

from pathlib import Path


def opacify(input_path: Path, seuil: float = 0.12, boucher: int = 5,
            adoucir: float = 1.2) -> Path:
    """Durcit un canal alpha mou : ce qui est probable devient certain.

    Tout pixel au-dessus de `seuil` passe à 255, le reste à 0 ; un flou léger rend
    ensuite au contour l'antialiasing qu'on vient de lui retirer.

    ⚠ `seuil` À 0,25 ET NON 0,5. Le masque de `rembg` est globalement sous-confiant sur les
      sujets fins : à 0,5 on perd la pointe des lames et les ajours de la garde. À 0,25 on
      capte 5,2 % de l'image là où le sujet en occupe 7,6 % contour compris — c'est le bon
      compromis mesuré.

    ⚠ ON NE PRÉSERVE PAS L'ALPHA D'ORIGINE SUR LE CONTOUR, et une première version le
      faisait : elle y réintroduisait exactement le bruit qu'on cherche à supprimer, et
      laissait 3 % de l'image en demi-teinte. Un flou d'un pixel sur le masque DURCI donne
      un bord propre sans rien ramener du masque mou.
    """
    from PIL import Image, ImageFilter

    image = Image.open(input_path).convert("RGBA")
    alpha = image.getchannel("A")

    limite = max(1, int(seuil * 255))
    dur = alpha.point(lambda v: 255 if v >= limite else 0)

    # FERMETURE MORPHOLOGIQUE : dilatation puis erosion de meme rayon. Elle rebouche les
    # trous sans deformer le contour — ce que ni un seuil plus bas ni un flou ne savent
    # faire. Sans elle, la lame ressortait CRIBLEE : le masque de `rembg` s'effondre au
    # milieu des surfaces metalliques uniformes, la ou il n'a aucun bord auquel se
    # raccrocher, et l'on voyait le bouclier a travers l'acier.
    if boucher > 0:
        taille = 2 * boucher + 1
        dur = dur.filter(ImageFilter.MaxFilter(taille)).filter(ImageFilter.MinFilter(taille))

    if adoucir > 0:
        dur = dur.filter(ImageFilter.GaussianBlur(adoucir))

    image.putalpha(dur)
    sortie = input_path.with_stem(input_path.stem + "_op")
    image.save(sortie, "PNG")
    return sortie


def trim(input_path: Path, marge_pct: float = 4.0, seuil: float = 0.5) -> Path:
    """Rogne l'image sur le contenu visible, en gardant une marge relative.

    ⚠ LA BOÎTE SE CALCULE SUR UN ALPHA BINARISÉ. `getbbox()` retient tout pixel non
      strictement nul : sur un masque de `rembg`, le bruit résiduel s'étend jusqu'aux
      bords et la boîte couvre alors l'image entière — le rognage ne rogne rien. Seuiller
      d'abord, à la moitié, ne retient que ce qui est réellement du sujet.

    Rend un CARRÉ : les objets d'une scène dvflame sont cadrés en `RATIO_IN` dans une
    boîte, et un rognage au plus juste ferait dépendre leur taille à l'écran des
    proportions du sujet — deux épées d'une même paire n'auraient pas la même.
    """
    from PIL import Image

    image = Image.open(input_path).convert("RGBA")
    limite = max(1, int(seuil * 255))
    net = image.getchannel("A").point(lambda v: 255 if v >= limite else 0)
    boite = net.getbbox()
    if boite is None:                      # rien de visible : on ne touche à rien
        return input_path

    gauche, haut, droite, bas = boite
    cote = int(max(droite - gauche, bas - haut) * (1.0 + marge_pct / 100.0))
    cx, cy = (gauche + droite) // 2, (haut + bas) // 2
    carre = (cx - cote // 2, cy - cote // 2, cx + cote // 2, cy + cote // 2)

    # `crop` accepte des bornes hors image et remplit de transparent : c'est exactement ce
    # qu'on veut quand le sujet touche un bord.
    sortie = input_path.with_stem(input_path.stem + "_tr")
    image.crop(carre).save(sortie, "PNG")
    return sortie


def unbg_flat(input_path: Path, tolerance: int = 42, adoucir: float = 1.0) -> Path:
    """Détoure un fond UNI par propagation depuis les bords. Rend un PNG RGBA.

    ⚠ À PRÉFÉRER À `rembg` QUAND LE FOND EST PLAT, et l'écart n'est pas marginal. `rembg`
      segmente par probabilité : sur une lame d'épée, il confond les reflets clairs du
      métal avec le gris du fond et rend une lame CRIBLÉE DE TROUS que ni un seuil ni une
      fermeture morphologique ne rattrapent — on voyait le bouclier à travers l'acier.
      Ici on ne devine rien : on part des bords, on propage tant que la couleur reste
      proche, et tout ce qui n'est pas atteint est le sujet. Un reflet enclavé dans la
      lame n'est jamais atteint, donc jamais percé.

    ⚠ EXIGE CE QUE LE PROMPT DEMANDE : un fond uni, sans dégradé ni ombre portée. Sur un
      fond travaillé, la propagation déborde ou s'arrête trop tôt — c'est `rembg` qu'il
      faut alors, avec ses défauts.

    `tolerance` est la distance de couleur admise, sur 255. 42 laisse passer le bruit de
    compression d'un aplat sans mordre sur un sujet contrasté.
    """
    from PIL import Image, ImageDraw, ImageFilter

    image = Image.open(input_path).convert("RGB")
    l, h = image.size

    # Le fond est ce qu'on trouve aux quatre coins : on prend leur moyenne plutôt qu'un
    # seul point, pour ne pas se laisser piéger par un pixel aberrant.
    coins = [image.getpixel(p) for p in ((0, 0), (l - 1, 0), (0, h - 1), (l - 1, h - 1))]
    fond = tuple(sum(c[i] for c in coins) // len(coins) for i in range(3))

    # On peint le fond en magenta pur — une couleur qu'aucun décor de ce jeu ne contient —
    # puis on en fait le masque. Départ depuis les quatre coins ET le milieu de chaque
    # bord : un sujet qui touche un coin ne doit pas enfermer la propagation.
    marque = (255, 0, 255)
    travail = image.copy()
    departs = [(0, 0), (l - 1, 0), (0, h - 1), (l - 1, h - 1),
               (l // 2, 0), (l // 2, h - 1), (0, h // 2), (l - 1, h // 2)]
    for xy in departs:
        if travail.getpixel(xy) == marque:
            continue
        ImageDraw.floodfill(travail, xy, marque, thresh=tolerance)

    masque = travail.point(lambda v: 0).convert("L")
    px_t, px_m = travail.load(), masque.load()
    for y in range(h):
        for x in range(l):
            px_m[x, y] = 0 if px_t[x, y] == marque else 255

    if adoucir > 0:
        masque = masque.filter(ImageFilter.GaussianBlur(adoucir))

    sortie_img = image.convert("RGBA")
    sortie_img.putalpha(masque)
    sortie = input_path.with_stem(input_path.stem + "_flat")
    sortie_img.save(sortie, "PNG")
    return sortie
