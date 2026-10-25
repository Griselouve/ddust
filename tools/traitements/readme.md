# traitements

Les traitements d'images que le builder applique aux assets générés (`traitements:` de
`build/build_assets.yml`, cf. `deva/python/modules/builder/assetgen_traitements.py`) :

- `remove_bg.py` : retire le fond (rembg) ;
- `alpha_tools.py` : `opacify`, `trim`, `unbg_flat`, ce qu'on fait après `remove_bg`.

Pas de `main.py` : ce ne sont pas des outils de la console (bouton Tools), seulement des
fonctions que l'assemblage importe. `anneau` vit dans `tools/crafting/` (outil de la console
ET traitement) ; le builder cherche un outil dans `tools/` puis dans chacun de ses
sous-dossiers.
