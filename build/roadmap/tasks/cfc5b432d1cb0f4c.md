---
# Généré par la console deva depuis Firestore : ne pas éditer, réécrit à chaque envoi.
id: "cfc5b432d1cb0f4c"
isp: 3
module: "ddust"
---

# attaque de bisous : désigner le joueur en difficulté ET un joueur tiré au sort

**Décision du 2026-09-16.** Désigner à chaque coffre le seul membre qui a le moins contribué se lit comme une dernière place, donc comme un classement (remarque répétée à la relecture du dossier « intérêt supérieur de l'enfant »). L'attaque de bisous désigne désormais **deux joueurs** : celui qui a le moins contribué au cycle, et un autre tiré au sort. Le texte ne change pas d'esprit : il parle de joueurs qui ont rencontré des difficultés, pas de perdants, et le second nom brouille les pistes.

**Aujourd'hui.** `_lowestContributor` (`client/modules/worker/worker_butin.dart:~1303`) retient un seul membre parmi `!admin && !horsConcours` (ex æquo départagés par tirage), puis `_prepareButinKiss(lowId, lowName)` (`:1663`) résout `butin_kiss` avec un seul `@@@name@@@`, et n'affiche rien sur l'appareil du joueur désigné.

**À faire.**
1. **Sélection** : garder le moins contributeur (même champ, même départage), puis tirer au sort un second joueur **dans le même champ** (non-chef, non hors concours), différent du premier, avec le même `rng` que le partage (fonction pure, reproductible). Si le champ ne compte qu'un joueur, un seul nom.
2. **Ordre des noms tiré au sort** : si le moins contributeur était toujours cité en premier, le brouillage ne servirait à rien.
3. **Texte** : `butin_kiss` reste pour un seul nom ; ajouter `butin_kiss_two` au pluriel, même esprit, 8 langues (fr : « @@@name1@@@ et @@@name2@@@ étaient en difficulté. Montrez-leur que vous les aimez : Attaque de bisous !!!! »). Formulations sans accord de genre là où la langue le permet.
4. **Discrétion** : rien ne s'affiche sur l'appareil d'**aucun** des deux joueurs désignés (ni leur nom, ni celui de l'autre) ; les autres membres voient les deux noms.
5. Vérifier tout ce qui lit le résultat (écran de récompenses, `_prepareButinKiss`, journal éventuel) et mettre à jour le commentaire de `_lowestContributor`.

**Documents déjà mis à jour le 2026-09-16** : `docs/child_interest.md` § 4.6, `build/legal/child_interest.md` § 3, page Expérience du site (8 langues). Ils décrivent le comportement cible : ne rien publier avant la livraison.
