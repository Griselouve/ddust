"""
Backfill du champ `gold` (= 0) sur les personnages existants.

Parcourt clans_players/{clanId}/players/{userId} et pose `gold: 0` sur chaque
fiche joueur qui n'en a pas encore. Idempotent (ré-exécutable sans risque) :
les docs déjà pourvus sont ignorés, l'updateMask ne touche que le champ `gold`.

Utilise l'API REST Firestore (HTTP) + Application Default Credentials
(gcloud auth application-default login), car gRPC est bloqué en desktop.
"""

import google.auth
import google.auth.transport.requests
import requests

PROJECT_ID = "dvddust"
DATABASE_ID = "eu-workers"

BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/{DATABASE_ID}/documents"


def get_session():
    creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    creds.refresh(google.auth.transport.requests.Request())
    s = requests.Session()
    s.headers["Authorization"] = f"Bearer {creds.token}"
    return s


def list_doc_names(session, collection, show_missing=False):
    """Liste les noms complets des documents d'une (sous-)collection, paginé."""
    names = []
    page_token = None
    while True:
        params = {"pageSize": 300}
        if show_missing:
            params["showMissing"] = "true"
        if page_token:
            params["pageToken"] = page_token
        resp = session.get(f"{BASE}/{collection}", params=params)
        resp.raise_for_status()
        data = resp.json()
        for doc in data.get("documents", []):
            names.append(doc["name"])
        page_token = data.get("nextPageToken")
        if not page_token:
            break
    return names


def list_players(session, clan_id):
    """Liste les docs joueurs (avec leurs champs) d'un clan, paginé."""
    players = []
    page_token = None
    while True:
        params = {"pageSize": 300}
        if page_token:
            params["pageToken"] = page_token
        resp = session.get(f"{BASE}/clans_players/{clan_id}/players", params=params)
        resp.raise_for_status()
        data = resp.json()
        players.extend(data.get("documents", []))
        page_token = data.get("nextPageToken")
        if not page_token:
            break
    return players


def set_gold_zero(session, doc_name):
    """PATCH gold=0 en deep-merge (updateMask limité à `gold`)."""
    url = f"https://firestore.googleapis.com/v1/{doc_name}"
    resp = session.patch(
        url,
        params={"updateMask.fieldPaths": "gold"},
        json={"fields": {"gold": {"integerValue": "0"}}},
    )
    resp.raise_for_status()


def clan_id_from_name(doc_name):
    # .../documents/clans_players/{clanId}  ->  {clanId}
    return doc_name.rsplit("/", 1)[-1]


def main():
    print(f"Connexion à {PROJECT_ID}/{DATABASE_ID}...", flush=True)
    session = get_session()

    # Parents implicites des sous-collections : showMissing pour les docs "fantômes".
    clan_names = list_doc_names(session, "clans_players", show_missing=True)
    print(f"{len(clan_names)} clan(s) trouvé(s) dans clans_players.", flush=True)

    updated = 0
    already = 0
    total = 0
    for clan_name in clan_names:
        clan_id = clan_id_from_name(clan_name)
        players = list_players(session, clan_id)
        for player in players:
            total += 1
            fields = player.get("fields", {})
            if "gold" in fields:
                already += 1
                continue
            set_gold_zero(session, player["name"])
            updated += 1
            print(f"  + gold=0 -> {player['name'].rsplit('/', 1)[-1]} (clan {clan_id})", flush=True)

    print(
        f"\nTerminé. {total} personnage(s) examiné(s) : "
        f"{updated} mis à jour, {already} déjà pourvus."
    )


if __name__ == "__main__":
    main()
