"""
Photo AVANT/APRES du grand reset : compte, sans rien ecrire, tout ce que le bloc
`build.reset` de build/build.yml s'apprete a supprimer.

Lecture seule, strictement : aucun DELETE, aucun PATCH. Le seul verbe HTTP en ecriture
utilise ici est le POST de `listCollectionIds`, qui est une operation de LECTURE dans
l'API Firestore (le corps ne sert qu'a passer le pageToken).

Auth : service account maitre de deva-cloud.yml (l'ADC du poste est expire). gRPC est
bloque sur ce poste, donc REST + requests, jamais google.cloud.firestore.Client().

Usage :
    C:\\Asura\\Tools\\Python312\\python.exe E:\\Deva\\projects\\suites\\ddust\\tools\\count_data.py
"""

import sys

import yaml
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession

CLOUD_YML = r"E:\Deva\deva\deva-cloud.yml"
PROJECT = "dvddust"

# Le miroir exact du bloc `build.reset` de build/build.yml : ce qui DOIT tomber a zero.
TARGETS = {
    "workers": [
        "clans", "clans_tasks", "clans_items", "clans_chest_history", "clans_logs",
        "clans_players", "clans_pulse", "clans_store", "userindexes", "users",
    ],
    "store": ["store_purchases", "store_tokens", "store_codes", "store_code_attempts"],
    "virtuallobby": [
        "virtuallobbylock", "virtuallobbymanagement", "virtuallobbysubmission",
        "virtuallobbyexit", "virtuallobbysecret",
    ],
    "documents": ["documents_sessions", "documents_acceptance"],
    "messaging": ["msgregistry", "msgindex", "msgevents", "msgdata", "msgdesktops"],
    "sessions": ["sessions"],
}

# Ce qui doit rester INCHANGE apres le reset. C'est le vrai test que la purge a vise juste :
# un zero ici serait un degat collateral, pas un succes.
PRESERVED = {
    "workers": ["beta_signups"],
    "store": ["store_config"],
}

REGIONS = ["eu", "us"]


def get_session():

            with open(CLOUD_YML, encoding="utf-8") as fh:
                conf = yaml.safe_load(fh)
            sa = conf["cloud"]["master"]["service_account"]
            creds = service_account.Credentials.from_service_account_info(
                sa, scopes=["https://www.googleapis.com/auth/cloud-platform"]
            )
            return AuthorizedSession(creds)


def list_collection_ids(session, base, doc_name):

            host = base.rsplit("/projects/", 1)[0]
            url = f"{host}/{doc_name}:listCollectionIds"
            ids, page_token = [], None
            while True:
                body = {"pageToken": page_token} if page_token else {}
                resp = session.post(url, json=body)
                resp.raise_for_status()
                data = resp.json()
                ids.extend(data.get("collectionIds", []))
                page_token = data.get("nextPageToken")
                if not page_token:
                    break
            return ids


# Meme parcours que builder.py _reset_firestore_path, moins la suppression. showMissing=true
# est indispensable : clans_players/{clanId} n'a aucun champ mais porte la sous-collection
# players — sans lui, on compterait zero sur une base pleine.
def count_path(session, base, collection, depth=0):

            real, ghost, page_token = 0, 0, None
            names = []
            while True:
                params = {"pageSize": 300, "showMissing": "true"}
                if page_token:
                    params["pageToken"] = page_token
                resp = session.get(f"{base}/{collection}", params=params)
                if resp.status_code == 404:
                    return 0, 0
                resp.raise_for_status()
                data = resp.json()
                for doc in data.get("documents", []):
                    names.append(doc["name"])
                    if "fields" in doc or "createTime" in doc:
                        real += 1
                    else:
                        ghost += 1
                page_token = data.get("nextPageToken")
                if not page_token:
                    break

            # Une profondeur de 3 couvre tout le schema ddust (clans_players/{id}/players).
            if depth < 3:
                for name in names:
                    doc_path = name.split("/documents/", 1)[1]
                    for sub_id in list_collection_ids(session, base, name):
                        sub_real, sub_ghost = count_path(
                            session, base, f"{doc_path}/{sub_id}", depth + 1
                        )
                        real += sub_real
                        ghost += sub_ghost
            return real, ghost


def scan(session, region, db_suffix, collections, label):

            database = f"{region}-{db_suffix}"
            base = (f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
                    f"/databases/{database}/documents")
            total = 0
            for collection in collections:
                real, ghost = count_path(session, base, collection)
                total += real
                flag = "" if real == 0 else "  <--"
                extra = f" (+{ghost} fantome)" if ghost else ""
                print(f"  {label}{database:<18} {collection:<24} {real:>6}{extra}{flag}")
            return total


# Le point de decision de l'etape 2b du plan : purger store_purchases efface un droit
# d'achat. Anodin si tout est marque test, bloquant s'il existe un achat reel.
def dump_purchases(session):

            print("\n--- store_purchases (detail) ---")
            found = False
            for region in REGIONS:
                base = (f"https://firestore.googleapis.com/v1/projects/{PROJECT}"
                        f"/databases/{region}-store/documents")
                resp = session.get(f"{base}/store_purchases", params={"pageSize": 300})
                if resp.status_code == 404:
                    continue
                resp.raise_for_status()
                for doc in resp.json().get("documents", []):
                    found = True
                    fields = doc.get("fields", {})
                    flat = {}
                    for key, val in fields.items():
                        flat[key] = next(iter(val.values())) if val else None
                    print(f"  [{region}] {doc['name'].rsplit('/', 1)[1]}")
                    for key in sorted(flat):
                        print(f"        {key} = {flat[key]}")
            if not found:
                print("  (aucun achat enregistre)")


def main():

            session = get_session()

            print("=== A SUPPRIMER (doit tomber a zero apres le reset) ===")
            grand_total = 0
            for region in REGIONS:
                for db_suffix, collections in TARGETS.items():
                    grand_total += scan(session, region, db_suffix, collections, "")
            print(f"\n  TOTAL a supprimer : {grand_total} document(s)")

            print("\n=== A PRESERVER (doit rester INCHANGE) ===")
            preserved_total = 0
            for region in REGIONS:
                for db_suffix, collections in PRESERVED.items():
                    preserved_total += scan(session, region, db_suffix, collections, "")
            print(f"\n  TOTAL a preserver : {preserved_total} document(s)")

            dump_purchases(session)


if __name__ == "__main__":
            sys.exit(main())
