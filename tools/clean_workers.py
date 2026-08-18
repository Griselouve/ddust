"""
Supprime tous les documents des collections workers via l'API REST Firestore (HTTP).
Utilise les Application Default Credentials (gcloud auth application-default login).
"""

import google.auth
import google.auth.transport.requests
import requests, shutil

PROJECT_ID = "dvddust"
DATABASE_ID = "eu-workers"
COLLECTIONS = ["clans","clans_tasks", "userindexes", "users"]
BUCKET_NAME = "dvddust-eu-assets-storage"

BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/{DATABASE_ID}/documents"


def get_session():
    creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    creds.refresh(google.auth.transport.requests.Request())
    s = requests.Session()
    s.headers["Authorization"] = f"Bearer {creds.token}"
    return s


def list_doc_names(session, collection):
    names = []
    page_token = None
    while True:
        params = {"pageSize": 300}
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


def batch_delete(session, doc_names):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/{DATABASE_ID}/documents:batchWrite"
    for i in range(0, len(doc_names), 500):
        writes = [{"delete": n} for n in doc_names[i:i + 500]]
        session.post(url, json={"writes": writes}).raise_for_status()


def delete_bucket_contents(session):
    GCS_BASE = f"https://storage.googleapis.com/storage/v1/b/{BUCKET_NAME}/o"
    deleted = 0
    page_token = None
    while True:
        params = {"maxResults": 1000}
        if page_token:
            params["pageToken"] = page_token
        resp = session.get(GCS_BASE, params=params)
        resp.raise_for_status()
        data = resp.json()
        objects = data.get("items", [])
        if not objects:
            break
        print(f"  {len(objects)} objet(s) trouvé(s), suppression...", flush=True)
        for obj in objects:
            name = requests.utils.quote(obj["name"], safe="")
            session.delete(f"{GCS_BASE}/{name}").raise_for_status()
            deleted += 1
        page_token = data.get("nextPageToken")
        if not page_token:
            break
    return deleted


def delete_collection(session, collection):
    deleted = 0
    while True:
        names = list_doc_names(session, collection)
        if not names:
            break
        print(f"  {len(names)} document(s) trouvés, suppression...", flush=True)
        batch_delete(session, names)
        deleted += len(names)
    return deleted


def main():
    print(f"Connexion à {PROJECT_ID}/{DATABASE_ID}...", flush=True)
    session = get_session()

    total = 0
    for collection in COLLECTIONS:
        print(f"\nNettoyage de '{collection}'...", flush=True)
        try:
            count = delete_collection(session, collection)
            print(f"  -> {count} document(s) supprimé(s)")
            total += count
        except Exception as e:
            print(f"  ERREUR: {type(e).__name__}: {e}")

    print(f"\nNettoyage du bucket '{BUCKET_NAME}'...", flush=True)
    try:
        count = delete_bucket_contents(session)
        print(f"  -> {count} objet(s) supprimé(s)")
    except Exception as e:
        print(f"  ERREUR: {type(e).__name__}: {e}")

    print("Deleting locals")
    shutil.rmtree("C:/Users/grisl/AppData/Roaming/com.grisloup/ddust_client",ignore_errors=True)
    shutil.rmtree("C:/Users/grisl/AppData/Local/com.grisloup/ddust_client",ignore_errors=True)
    shutil.rmtree("E:/Deva/deva/workspace/ddust/client/assets",ignore_errors=True)

    print(f"\nTerminé. {total} document(s) supprimé(s) au total.")


if __name__ == "__main__":
    main()
