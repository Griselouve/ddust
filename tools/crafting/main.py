"""Crafting : un atelier pour les outils d'images du dossier (anneau.py…).

Outil de la console deva (tools/crafting/main.py) : bouton Tools du Builder ou d'une fiche.
Lancement à la main, depuis ce dossier : C:\\Asura\\Tools\\Python312\\python.exe main.py

1. On choisit un OUTIL : tout script `<nom>.py` de ce dossier (sauf main.py et les `_*.py`).
2. Un sélecteur de fichiers s'ouvre (plusieurs fichiers possibles), dans le dernier dossier
   utilisé.
3. Pour chaque fichier, l'outil tourne sur une COPIE (dossier temporaire : l'original et ses
   voisins ne sont jamais touchés pendant l'essai), puis l'avant et l'après s'affichent côte
   à côte. Trois choix :
     - Garder l'ancien        : le résultat est jeté ;
     - Remplacer l'ancien     : le résultat prend sa place (l'extension suit le résultat :
                                un .jpg remplacé par un .png devient <nom>.png) ;
     - Garder les deux        : le résultat est enregistré à côté, sous le nom choisi.
4. Le dernier fichier traité, le sélecteur se rouvre ; Annuler revient au choix de l'outil.

CONTRAT D'UN OUTIL (pour qu'il soit utilisable ici) : un script qui reçoit un ou plusieurs
chemins de fichiers en arguments, écrit son résultat dans un NOUVEAU fichier, et affiche le
chemin de ce fichier sur la DERNIÈRE ligne de sa sortie. La première ligne de sa docstring
sert de description. anneau.py le respecte.
"""
import ast
import json
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

import flet as ft

ICI = Path(__file__).resolve().parent
ETAT = Path.home() / ".deva_crafting.json"        # le dernier dossier utilisé
EXTENSIONS = ["png", "jpg", "jpeg", "webp"]

FOND, CARTE, TEXTE, TERNE = "#14121a", "#221e2c", "#ece6f6", "#9a93ab"
ACCENT, VERT, ROUGE, BLEU = "#C8A84B", "#2e6b3a", "#8a2b2b", "#2f4f8a"


# --------------------------------------------------------------------------- outils
def outils():
    """Les scripts du dossier : [(nom, description)], par nom."""
    out = []
    for p in sorted(ICI.glob("*.py")):
        if p.name == "main.py" or p.name.startswith("_"):
            continue
        desc = ""
        try:
            doc = ast.get_docstring(ast.parse(p.read_text(encoding="utf-8"))) or ""
            desc = doc.strip().splitlines()[0] if doc.strip() else ""
        except Exception:
            pass
        out.append((p.stem, desc))
    return out


def lis_etat():
    try:
        return json.loads(ETAT.read_text(encoding="utf-8"))
    except Exception:
        return {}


def ecris_etat(**kw):
    etat = lis_etat()
    etat.update(kw)
    try:
        ETAT.write_text(json.dumps(etat, ensure_ascii=False), encoding="utf-8")
    except Exception:
        pass


def execute(outil, source, travail):
    """Lance l'outil sur une COPIE de `source` dans `travail` ; rend (chemin produit, journal)."""
    copie = Path(travail) / source.name
    shutil.copy2(source, copie)
    proc = subprocess.run([sys.executable, str(ICI / f"{outil}.py"), str(copie)],
                          cwd=str(ICI), capture_output=True, text=True, encoding="utf-8",
                          errors="replace", creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    journal = (proc.stdout or "") + (proc.stderr or "")
    lignes = [l.strip() for l in (proc.stdout or "").splitlines() if l.strip()]
    produit = Path(lignes[-1]) if lignes else None
    if proc.returncode != 0 or produit is None or not produit.exists():
        return None, journal.strip() or f"code de sortie {proc.returncode}"
    return produit, journal.strip()


def nom_libre(dossier, nom):
    """`nom` s'il est libre dans `dossier`, sinon `<stem>_2<ext>`, `_3`…"""
    cible = Path(dossier) / nom
    i = 2
    while cible.exists():
        cible = Path(dossier) / f"{Path(nom).stem}_{i}{Path(nom).suffix}"
        i += 1
    return cible.name


# --------------------------------------------------------------------------- écran
def main(page: ft.Page):
    page.title = "Crafting"
    page.bgcolor = FOND
    page.theme_mode = ft.ThemeMode.DARK
    page.window.width = 1180
    page.window.height = 800
    page.padding = 16

    etat = {"outil": None, "file": [], "rang": 0, "total": 0, "produit": None, "travail": None}
    racine = ft.Column(expand=True, spacing=12)
    page.add(racine)

    def texte(v, size=14, color=TEXTE, weight=None, **kw):
        return ft.Text(v, size=size, color=color, weight=weight, **kw)

    def bouton(label, couleur, action, icone=None):
        return ft.ElevatedButton(label, icon=icone, on_click=lambda e: action(), bgcolor=couleur,
                                 color="#ffffff", height=46,
                                 style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=10)))

    def nettoie_travail():
        if etat["travail"]:
            shutil.rmtree(etat["travail"], ignore_errors=True)
        etat["travail"] = None

    # ---- 1. le choix de l'outil
    def ecran_outils():
        nettoie_travail()
        etat["outil"] = None
        liste = outils()
        cartes = []
        for nom, desc in liste:
            cartes.append(ft.Container(
                ft.Column([texte(nom, 20, ACCENT, ft.FontWeight.BOLD),
                           texte(desc or "(pas de description)", 13, TERNE)], spacing=4),
                bgcolor=CARTE, border_radius=12, padding=16,
                border=ft.border.all(1, "#3a3448"),
                on_click=lambda e, n=nom: choisit(n), ink=True))
        if not cartes:
            cartes = [texte("Aucun outil dans ce dossier (un script <nom>.py à côté de main.py).", 14, TERNE)]
        racine.controls = [
            texte("Crafting", 28, TEXTE, ft.FontWeight.BOLD),
            texte("Choisis un outil, puis les fichiers à traiter.", 14, TERNE),
            ft.Column(cartes, spacing=10, scroll=ft.ScrollMode.AUTO, expand=True),
        ]
        page.update()

    def choisit(nom):
        etat["outil"] = nom
        selection()

    # ---- 2. le sélecteur, en boucle
    def selection():
        nettoie_travail()
        racine.controls = [
            texte(f"Crafting · {etat['outil']}", 24, TEXTE, ft.FontWeight.BOLD),
            texte("Choisis un ou plusieurs fichiers… (Annuler revient aux outils)", 14, TERNE),
        ]
        page.update()
        dossier = lis_etat().get("dossier") or str(Path.home())
        picker.pick_files(dialog_title=f"{etat['outil']} : fichiers à traiter",
                          initial_directory=dossier if Path(dossier).exists() else None,
                          allowed_extensions=EXTENSIONS, allow_multiple=True)

    def choisis(e: ft.FilePickerResultEvent):
        fichiers = [Path(f.path) for f in (e.files or []) if f.path]
        if not fichiers:
            ecran_outils()
            return
        ecris_etat(dossier=str(fichiers[0].parent))
        etat["file"] = fichiers
        etat["rang"] = 0
        etat["total"] = len(fichiers)
        suivant()

    picker = ft.FilePicker(on_result=choisis)
    page.overlay.append(picker)

    # ---- 3. un fichier : l'outil, puis la comparaison
    def suivant():
        nettoie_travail()
        if not etat["file"]:
            selection()                         # la boucle : on rouvre le sélecteur
            return
        source = etat["file"].pop(0)
        etat["rang"] += 1
        etat["travail"] = tempfile.mkdtemp(prefix="crafting_")
        racine.controls = [
            texte(f"Crafting · {etat['outil']} · {etat['rang']}/{etat['total']}", 24, TEXTE, ft.FontWeight.BOLD),
            texte(str(source), 13, TERNE),
            ft.Row([ft.ProgressRing(color=ACCENT), texte("L'outil travaille…", 15)], spacing=12),
        ]
        page.update()

        def travaille():
            try:
                produit, journal = execute(etat["outil"], source, etat["travail"])
            except Exception as ex:
                produit, journal = None, str(ex)
            compare(source, produit, journal)
        threading.Thread(target=travaille, daemon=True).start()

    def vignette(titre, chemin, legende):
        return ft.Container(ft.Column([
            texte(titre, 16, ACCENT, ft.FontWeight.BOLD),
            ft.Container(ft.Image(src=str(chemin), fit=ft.ImageFit.CONTAIN), expand=True,
                         bgcolor="#0b0a10", border_radius=10, padding=8,
                         alignment=ft.alignment.center),
            texte(legende, 12, TERNE),
        ], spacing=6, expand=True), expand=True, bgcolor=CARTE, border_radius=12, padding=12)

    def taille(p):
        try:
            from PIL import Image
            with Image.open(p) as im:
                return f"{im.width}×{im.height}"
        except Exception:
            return "?"

    def compare(source, produit, journal):
        tete = [texte(f"Crafting · {etat['outil']} · {etat['rang']}/{etat['total']}", 24, TEXTE, ft.FontWeight.BOLD),
                texte(str(source), 13, TERNE)]
        if produit is None:
            racine.controls = tete + [
                ft.Container(texte(f"L'outil a échoué :\n{journal}", 13, "#ffb3b3", selectable=True),
                             bgcolor="#2a1414", border_radius=10, padding=12),
                ft.Row([bouton("Fichier suivant", BLEU, suivant, ft.Icons.SKIP_NEXT)]),
            ]
            page.update()
            return
        etat["produit"] = produit
        nom = ft.TextField(value=nom_libre(source.parent, produit.name), label="Nom du nouveau fichier",
                           width=360, color=TEXTE, border_color="#4a445a")
        cible_remplace = source.with_suffix(produit.suffix)

        def garder_ancien():
            suivant()

        def remplacer():
            try:
                shutil.copy2(produit, cible_remplace)
                if cible_remplace != source and source.exists():
                    source.unlink()
            except Exception as ex:
                return erreur(f"Remplacement impossible : {ex}")
            suivant()

        def garder_les_deux():
            n = (nom.value or "").strip()
            if not n:
                return erreur("Donne un nom au nouveau fichier.")
            if not Path(n).suffix:
                n += produit.suffix
            dest = source.parent / n
            if dest.exists():
                return erreur(f"{dest.name} existe déjà : choisis un autre nom.")
            try:
                shutil.copy2(produit, dest)
            except Exception as ex:
                return erreur(f"Enregistrement impossible : {ex}")
            suivant()

        def erreur(msg):
            page.open(ft.SnackBar(ft.Text(msg), bgcolor=ROUGE))

        remplace_txt = ("Remplacer l'ancien" if cible_remplace == source
                        else f"Remplacer l'ancien (→ {cible_remplace.name})")
        racine.controls = tete + [
            ft.Row([vignette("Avant", source, f"{source.name} · {taille(source)}"),
                    vignette("Après", produit, f"{produit.name} · {taille(produit)}")],
                   expand=True, spacing=12),
            ft.Row([bouton("Garder l'ancien", "#3a3448", garder_ancien, ft.Icons.UNDO),
                    bouton(remplace_txt, ROUGE, remplacer, ft.Icons.SWAP_HORIZ),
                    nom,
                    bouton("Garder les deux", VERT, garder_les_deux, ft.Icons.ADD_PHOTO_ALTERNATE)],
                   spacing=12, vertical_alignment=ft.CrossAxisAlignment.CENTER, wrap=True),
        ]
        page.update()

    ecran_outils()


if __name__ == "__main__":
    ft.app(target=main)
