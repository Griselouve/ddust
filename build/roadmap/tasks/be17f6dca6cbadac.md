---
# Généré par la console deva depuis Firestore : ne pas éditer, réécrit à chaque envoi.
id: "be17f6dca6cbadac"
isp: 21
module: "ddust"
---

# join clan à distance + invite clan

Permettre à un parent d'inviter un utilisateur à rejoindre son clan à distance (par lien ou code), sans scan QR en présentiel. Couvre la génération d'invite, le partage, l'acceptation et la gestion des demandes en attente. Réestimé 34 → 21sp : l'audit montre que le flux « je n'ai pas le QR » (demande via `dvvirtuallobby`) est **déjà câblé** (voir item beta) ; il reste le pendant *invitation* (deeplink `ddust://invite`, `dvsocialshare`) à finaliser et tester. Reporté au lancement commercial (non bloquant pour la beta).
