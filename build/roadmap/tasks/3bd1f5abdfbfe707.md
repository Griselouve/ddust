---
# Généré par la console deva depuis Firestore : ne pas éditer, réécrit à chaque envoi.
id: "3bd1f5abdfbfe707"
isp: 3
module: "ddust"
---

# lier la Play Console au projet GCP et inviter deva-store@dvddust

Ce n'est pas de la paperasse, c'est de la **configuration** — et sans elle rien de la chaîne
d'achat ne fonctionne. `store_verify` (`build/backend/config.yml:598`) interroge
`androidpublisher` (`purchases.subscriptionsv2.get`) pour lire l'état canonique d'un
abonnement : c'est l'état Play qui fait autorité, le client ne fait que transmettre un jeton.
Sans le lien, l'API répond à côté, **aucun achat n'est acquitté, et Play rembourse
automatiquement**.

Deux gestes, dans la Play Console :

- **Lier le compte développeur au projet GCP `dvddust`** (Configuration → Accès à l'API).
- **Inviter le compte de service `deva-store@dvddust`** et lui donner les droits de lecture
  des achats. `androidpublisher.googleapis.com` est déjà dans la liste des API activées
  (`backend/config.yml:92`) ; c'est l'autorisation côté Play qui manque.

⚠ **Bloqueur de monétisation, pas de développement.** On peut coder sans ; on ne peut pas
tester un achat. À faire avant la première recette d'abonnement, pas au moment de la
publication.

⚠ Ne pas confondre avec l'identité qui écrit le catalogue : `pucatalog` publie avec le
**compte de service master**, délibérément séparé de `deva-store` pour que les prix ne soient
pas à portée d'une faille dans une fonction exposée (`backend/config.yml:7-11`). Cette tâche
ne touche qu'à la lecture des achats.

*Point de `docs/otherActions.txt` (revue « intérêt supérieur de l'enfant », 2026-09-08).*
