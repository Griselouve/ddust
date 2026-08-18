#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Genere tasks_balance.db : le catalogue des taches ddust avec leur poids dans l'economie du jeu.

FORMULE (miroir de worker._taskBaseXp / conf worker.xp_per_effort + worker.xp_respawn_div) :

    xp_per_run  = (XP_FLAT + respawn_h / XP_RESPAWN_DIV) x effort

La part variable donne du poids aux corvees rares et lourdes : a effort egal, nettoyer le four
(720 h) vaut 350 XP quand mettre la table (6 h) en vaut 10.

PLAFOND HEBDOMADAIRE. L'XP reellement creditee est proratisee sur la fenetre dead -> revive
(worker.getTaskXPs). En jouant la tache en boucle, le total hebdomadaire plafonne donc a :

    xp_per_week = HOURS_PER_WEEK x xp_per_run / respawn_h
                = 1120 x effort / respawn_h  +  9,3 x effort      (valeurs par defaut)

Ce plafond ne depend NI de la cadence de jeu, NI du type (une mortelle jouee des chaque
resurrection atteint le meme total qu'une immortelle). Passe XP_FLAT x XP_RESPAWN_DIV heures de
recharge (120 h) le second terme domine et le rendement ne depend plus que de l'effort : c'est la
zone equilibree. En dessous de 24 h une tache devient tres lucrative a la semaine.

HOURS_PER_WEEK = 112, soit 16 h eveillees x 7 jours : on ne compte pas les 8 h de sommeil, pendant
lesquelles aucune tache n'est jouable. C'est un cadre volontairement CONSERVATEUR : le code du jeu,
lui, fait courir l'horloge 24 h/24, donc une tache a 6 h de recharge est entierement regeneree au
reveil et son plafond reel est un peu plus haut (~26 executions/semaine au lieu de 19).

Relancer ce script apres chaque retouche des recharges pour voir l'effet sur l'equilibrage.

Usage :
    C:\\Asura\\Tools\\Python312\\python.exe build/tools/gen_tasks_balance.py
"""

import math
import os
import re
import sqlite3

# --- Barème : memes valeurs que le bloc `worker:` de build/client/config.yml -------------------
XP_FLAT = 10          # worker.xp_per_effort  : part fixe
XP_RESPAWN_DIV = 12   # worker.xp_respawn_div : diviseur de la part variable
HOURS_PER_WEEK = 112  # 16 h eveillees x 7 jours

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.dirname(HERE)
TASKS_YML = os.path.join(BUILD, "resources_cloud", "layers", "tasks-base-global.yml")
TREE_YML = os.path.join(BUILD, "resources_cloud", "layers", "decisiontree-donjon-global.yml")
DB_PATH = os.path.join(HERE, "tasks_balance.db")

# Les commentaires ne se derivent pas des donnees : ils sont rediges a la main, tache par tache.
# Les chiffres cites sont ceux du barème courant (xp/exec et xp/sem).
COMMENTS = {
    # --- salon ---
    "salon_01": "OK",
    "salon_02": "OK",
    "salon_03": "OK",
    "salon_04": "OK depuis le passage a 7 j, coherent sur les 6 pieces",
    "salon_05": "Type incoherent : la meme tache est immortelle en chambres et dans l'entree",
    "salon_06": "OK",
    "salon_07": "Ranger a 4 recharges selon la piece : 24 h (ch. enfant), 36 h (ici et ch. parents), 48 h (bureau)",
    "salon_08": "OK",
    "salon_09": "190 XP a l'unite depuis le passage a 14 j : la grosse corvee est enfin payee",
    # --- chambre parentale ---
    "chambre_parentale_01": "OK",
    "chambre_parentale_02": "OK",
    "chambre_parentale_03": "OK",
    "chambre_parentale_04": "OK depuis le passage a 7 j",
    "chambre_parentale_05": "OK",
    "chambre_parentale_06": "Voir Ranger au salon : 4 recharges differentes pour la meme tache",
    "chambre_parentale_08": "Maladie, sueur : besoin immediat, refuse pendant 10 jours (type mortelle)",
    "chambre_parentale_09": "Meme titre, type et recharge que la version ch. enfant, mais effort 4 contre 2. A harmoniser",
    "chambre_parentale_10": "Type incoherent avec Laver les murs du salon et Nettoyer les murs des toilettes (mortelles)",
    # --- chambre enfant ---
    "chambre_enfant_01": "Avec un chien et 3 enfants c'est quotidien. Type immortelle donc pas bloquant",
    "chambre_enfant_02": "OK",
    "chambre_enfant_03": "OK",
    "chambre_enfant_04": "OK depuis le passage a 7 j",
    "chambre_enfant_05": "OK",
    "chambre_enfant_06": "Ranger a 4 recharges selon la piece : 24 h ici, 36 h (salon, ch. parents), 48 h (bureau)",
    "chambre_enfant_09": "PIRE VERROU DU CATALOGUE : un pipi au lit se traite dans l'heure, refuse 10 jours",
    "chambre_enfant_10": "Type incoherent avec la version salon et toilettes (mortelles)",
    "chambre_enfant_11": "Meme titre, type et recharge que la version ch. parents, mais effort 2 contre 4. A harmoniser",
    # --- cuisine ---
    "cuisine_01": "2 j en cuisine vs 3 j partout ailleurs",
    "cuisine_03": "Evenementiel (un verre renverse). Type deja correct",
    "cuisine_05": "205 XP/sem : 3e tache la plus lucrative hors repas/vaisselle. 24 h la ramenerait a 112",
    "cuisine_04": "OK depuis le passage a 7 j",
    "cuisine_06": "Evenementiel (apres chaque cuisine), OK sur le type",
    "cuisine_07": "OK",
    "cuisine_08": "OK",
    "cuisine_09": "OK",
    "cuisine_10": "152 XP a l'unite depuis le passage a 14 j",
    "cuisine_11": "350 XP a l'unite, le plus gros gain du jeu avec les haies et le desencombrement. Bien calibre",
    "cuisine_12": "Evenementiel : apres un debordement, c'est tout de suite",
    "cuisine_13": "Verrou legitime",
    "cuisine_15": "OK",
    "cuisine_18": "OK",
    "cuisine_19": "OK",
    # --- repas ---
    "repas_06": "DOUBLON EXACT de repas_10 : 588 XP/sem chacun, 1176 pour une seule corvee reelle. A fusionner",
    "repas_07": "196 XP/sem pour un micro-ondes (effort 1) : autant que mettre la table. 8 h le ramenerait a 149",
    "repas_10": "DOUBLON EXACT de repas_06 (Cuisiner un plat simple). A fusionner ou differencier",
    "repas_11": "Bien calibre. Mais concurrence par Cuisiner un plat simple a 588",
    # --- vaisselle ---
    "vaisselle_01": "Verrou 6 h : impossible apres le diner si deja fait au dejeuner",
    "vaisselle_02": "224 XP/sem depuis le passage a 24 h, contre 560 avant. Bien recadre",
    "vaisselle_03": "Evenementiel pur, verrou incoherent avec Vider le lave-vaisselle (12 h)",
    "vaisselle_04": "Evenementiel : des que le cycle est fini",
    "vaisselle_05": "Sous-etape de la vaisselle, payee autant que la vaisselle elle-meme",
    "vaisselle_06": "Les 3 sous-etapes (secher, ranger, petite vaisselle) cumulent 1176 XP/sem pour une corvee reelle",
    "vaisselle_07": "Trivial (effort 1) mais 196 XP/sem, contre 131 pour la cuvette (effort 4). Verrou 6 h = petit-dej + dejeuner refuses",
    "vaisselle_08": "3 repas/jour contre un verrou de 6 h",
    "vaisselle_09": "OK",
    # --- salle de bain ---
    "salle_de_bain_01": "OK",
    "salle_de_bain_02": "OK",
    "salle_de_bain_03": "OK",
    "salle_de_bain_04": "OK depuis le passage a 7 j",
    "salle_de_bain_05": "Evenementiel, type correct",
    "salle_de_bain_06": "OK",
    "salle_de_bain_07": "OK",
    "salle_de_bain_08": "OK",
    "salle_de_bain_10": "Evenementiel (serviette tombee, invites)",
    "salle_de_bain_11": "Verrou parfaitement legitime",
    "salle_de_bain_12": "OK",
    # --- toilettes ---
    "toilettes_01": "OK",
    "toilettes_02": "7 j ici vs 4 j dans les pieces : incoherent",
    "toilettes_03": "OK",
    "toilettes_04": "La plus ingrate du catalogue (effort 4) et pourtant 131 XP/sem contre 196 pour mettre la table",
    "toilettes_06": "Type incoherent : la meme tache est immortelle en chambres et dans l'entree",
    # --- entree / couloir ---
    "couloir_01": "OK",
    "couloir_02": "7 j ici vs 4 j dans les pieces : incoherent",
    "couloir_03": "OK",
    "couloir_04": "Type incoherent avec Laver les murs du salon et Nettoyer les murs des toilettes (mortelles)",
    "entree_01": "OK",
    "entree_02": "7 j ici vs 4 j dans les pieces : incoherent",
    "entree_03": "OK",
    "entree_04": "Type incoherent avec Laver les murs du salon et Nettoyer les murs des toilettes (mortelles)",
    # --- bureau ---
    "bureau_01": "4 j au bureau vs 3 j ailleurs",
    "bureau_02": "OK",
    "bureau_03": "7 j au bureau vs 3-4 j ailleurs",
    "bureau_04": "OK depuis le passage a 7 j",
    "bureau_05": "2 j au bureau contre 12 h en cuisine, pour la meme tache",
    "bureau_06": "4e valeur differente pour Ranger (24 h, 36 h, 36 h, 48 h)",
    # --- terrasse / balcon ---
    "terrasse_01": "OK",
    "terrasse_02": "OK",
    "terrasse_03": "Immortelle ici, mortelle au jardin pour la meme tache. Harmoniser",
    "balcon_01": "OK",
    "balcon_02": "OK",
    # --- jardin ---
    "jardin_01": "Quotidien en novembre, jamais en juin. Type immortelle = bon choix",
    "jardin_02": "Effort ramene de 6 a 4 : plus aucune tache du catalogue ne depasse 5. 120 XP a l'unite",
    "jardin_03": "En canicule c'est quotidien voire 2x/jour. Et la version terrasse est immortelle : incoherent",
    "jardin_04": "OK",
    "jardin_05": "Tres saisonnier : nul en hiver, hebdo au printemps",
    "jardin_06": "350 XP a l'unite : le haut du bareme, merite pour la corvee",
    # --- linge ---
    "linge_01": "Precede la machine (2 j) : incoherence de chaine",
    "linge_02": "Une famille de 5 lance une machine/jour, donc refus 2 fois sur 3",
    "linge_02_alt": "Bien calibre",
    "linge_03": "Chaine du linge, cadence dictee par le volume",
    "linge_04": "Chaine du linge, cadence dictee par le volume",
    "linge_05": "Suit la machine, donc meme cadence qu'elle",
    "linge_06": "Chaine du linge, cadence dictee par le volume",
    "linge_08": "Peut attendre, verrou acceptable",
    "linge_09": "OK",
    # --- dechets ---
    "dechets_01": "Passee de 48 h a 8 h : debloquee, mais propulsee a 448 XP/sem (3e du jeu) et TOUJOURS mortelle donc verrouillee dur. Immortelle a 24 h donnerait le meme deblocage a 112 XP/sem",
    "dechets_02": "Verrou dur alors que Trier les dechets (meme domaine, meme recharge) est immortelle",
    "dechets_03": "Le bon reglage, a repliquer sur le reste du domaine",
    "dechets_04": "Evenementiel (bac plein), mais 7 j reste plausible",
    "dechets_05": "Un seau a biodechets se remplit en 2-3 jours l'ete",
    "dechets_06": "Evenementiel",
    "dechets_07": "Verrou legitime",
    # --- animaux ---
    "animaux_01": "Un chien mange 2x/jour, un chat en libre-service davantage. Verrou dur inadapte",
    "animaux_02": "L'eau d'un chien se change 2x/jour en ete",
    "animaux_03": "Passee a 24 h : 224 XP/sem, au niveau de la grosse vaisselle. Nettoyer une cage a fond chaque jour est peu realiste, 48 h la ramenerait a 124",
    "animaux_05": "Periode de mue = quotidien",
    # --- vehicules ---
    "voiture_01": "OK",
    "voiture_02": "OK",
    "moto_01": "OK",
    # --- garage ---
    "garage_01": "OK",
    "garage_02": "OK",
    "garage_03": "OK",
    "garage_04": "350 XP a l'unite depuis le passage a 30 j : la corvee est enfin a sa place",
    "garage_05": "OK",
    "garage_06": "PUREMENT EVENEMENTIEL : un enfant ne choisit pas quand papa bricole. Verrou 14 j absurde",
    # --- courses ---
    "courses_01": "Beaucoup de foyers font les courses 2-3x/semaine",
    "courses_02": "Enchaine Faire les courses, meme cadence",
    "courses_03": "Suit Porter les courses",
    "courses_04": "Effort remonte a 2 : aligne sur le reste du domaine",
    "courses_05": "Effort remonte a 2. Reste que va chercher le pain est quotidien et verrouille 4 jours",
    # --- extras ---
    "extras_01": "Certaines plantes veulent de l'eau tous les jours",
    "extras_02": "Le facteur passe tous les jours ; verrou dur inutile",
    "extras_03": "Evenementiel (bac plein)",
    "extras_04": "Passee de 60 j mortelle a 3 j immortelle : une ampoule grille quand elle veut, c'est le bon reglage",
    "extras_05": "OK",
    "extras_06": "OK",
    "extras_07": "Passee a 24 h : 56 XP/sem contre 140 avant. Ouvrir une fenetre n'est plus le meilleur rapport du jeu",
    "extras_08": "Fourre-tout par nature : le verrou dur est le plus absurde ici",
}

def dart_round(x):
    """Arrondi de num.round() en Dart : au plus proche, et A L'OPPOSE DE ZERO a mi-chemin.

    round() en Python arrondit a l'entier PAIR a mi-chemin (10.5 -> 10), Dart donne 11. Les taches
    a 6 h de recharge et effort impair tombent pile sur .5 (mettre la table : 10.5) : sans ce
    helper, la base afficherait 10 la ou le jeu crediterait 11.
    """
    return math.floor(x + 0.5)


TITLE_RE = re.compile(r"^\s*(dt_t_[a-z0-9_]+):\s*$")
LANG_RE = re.compile(r'^\s*(fr|en|es):\s*"(.*)"\s*$')
TASK_RE = re.compile(r"^    ([a-z0-9_]+):\s*$")
FIELD_RE = re.compile(r"^      ([a-z_]+):\s*(.*)$")


def read_titles():
    """dt_t_xxx -> {"fr": ..., "en": ..., "es": ...} depuis la couche decisiontree."""
    lines = open(TREE_YML, encoding="utf-8").read().split("\n")
    out = {}
    for i, line in enumerate(lines):
        m = TITLE_RE.match(line)
        if not m:
            continue
        langs = {}
        for j in range(i + 1, min(i + 4, len(lines))):
            ml = LANG_RE.match(lines[j])
            if not ml:
                break
            langs[ml.group(1)] = ml.group(2)
        out[m.group(1)] = langs
    return out


def read_tasks():
    """Liste des blocs `tasks:` de tasks-base-global.yml, tels quels."""
    tasks, cur = [], None
    for line in open(TASKS_YML, encoding="utf-8").read().split("\n"):
        m = TASK_RE.match(line)
        if m:
            if cur and "respawn_h" in cur:
                tasks.append(cur)
            cur = {"id": m.group(1)}
            continue
        if cur is None:
            continue
        mf = FIELD_RE.match(line)
        if mf:
            cur[mf.group(1)] = mf.group(2).strip()
    if cur and "respawn_h" in cur:
        tasks.append(cur)
    # les blocs `domains:` n'ont pas de respawn_h, ils sont deja ecartes ci-dessus
    return [t for t in tasks if "domain" in t]


def main():
    titles = read_titles()
    tasks = read_tasks()

    rows = []
    for t in tasks:
        key = t["title"].strip('"').replace("@@@T:", "").replace("@@@", "")
        tr = titles.get(key, {})
        effort = int(t["effort"])
        respawn = int(t["respawn_h"])
        xp_run = dart_round(effort * (XP_FLAT + respawn / XP_RESPAWN_DIV))
        rows.append((
            t["id"],
            tr.get("fr", key),
            tr.get("en", ""),
            tr.get("es", ""),
            t["domain"],
            effort,
            xp_run,
            respawn,
            t["type"],
            HOURS_PER_WEEK / respawn,
            HOURS_PER_WEEK * xp_run / respawn,
            t.get("multiple", ""),
            COMMENTS.get(t["id"], ""),
        ))

    missing = [r[0] for r in rows if not r[12]]
    if missing:
        raise SystemExit("Commentaire manquant pour : " + ", ".join(missing))
    orphans = sorted(set(COMMENTS) - {r[0] for r in rows})
    if orphans:
        raise SystemExit("Commentaire orphelin (tache inconnue) : " + ", ".join(orphans))

    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.executescript("""
        DROP VIEW  IF EXISTS v_classement;
        DROP TABLE IF EXISTS tasks;
        CREATE TABLE tasks (
          id            TEXT PRIMARY KEY,
          title_fr      TEXT NOT NULL,
          title_en      TEXT,
          title_es      TEXT,
          domain        TEXT NOT NULL,
          effort        INTEGER NOT NULL,
          xp_per_run    INTEGER NOT NULL,   -- (10 + respawn_h/12) x effort
          respawn_h     INTEGER NOT NULL,
          type          TEXT NOT NULL,      -- mortelle (verrouillee) | immortelle (jouable, XP au prorata)
          runs_per_week REAL NOT NULL,      -- 112 / respawn_h  (112 h = 16 h eveillees x 7 j)
          xp_per_week   REAL NOT NULL,      -- runs_per_week x xp_per_run : le plafond en jouant en boucle
          multiple      TEXT,
          comment       TEXT NOT NULL
        );
        CREATE INDEX idx_tasks_xpw    ON tasks(xp_per_week);
        CREATE INDEX idx_tasks_domain ON tasks(domain);
        CREATE VIEW v_classement AS
          SELECT ROUND(xp_per_week) AS xp_sem, xp_per_run AS xp_exec, title_fr, domain, effort,
                 respawn_h, type, ROUND(runs_per_week, 1) AS exec_sem, comment
          FROM tasks ORDER BY xp_per_week DESC;
    """)
    cur.executemany("INSERT INTO tasks VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", rows)
    con.commit()

    n = cur.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
    nm = cur.execute("SELECT COUNT(*) FROM tasks WHERE type='mortelle'").fetchone()[0]
    rlo, rhi = cur.execute("SELECT MIN(xp_per_run), MAX(xp_per_run) FROM tasks").fetchone()
    wlo, whi = cur.execute("SELECT MIN(xp_per_week), MAX(xp_per_week) FROM tasks").fetchone()
    con.close()

    print(f"{DB_PATH}")
    print(f"  bareme : ({XP_FLAT} + respawn_h/{XP_RESPAWN_DIV}) x effort, semaine utile {HOURS_PER_WEEK} h")
    print(f"  {n} taches ({nm} mortelles, {n - nm} immortelles)")
    print(f"  XP/exec : {rlo} a {rhi}")
    print(f"  XP/sem  : {wlo:.0f} a {whi:.0f}  (ecart {whi / wlo:.1f}x)")


if __name__ == "__main__":
    main()
