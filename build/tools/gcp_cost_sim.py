#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Simulation des couts Google Cloud pour Donjons & Savons (ddust).

Modele derive de l'analyse du code (2026-08-10) :
  - Le client Flutter parle DIRECTEMENT a Firestore (pas de backend applicatif).
    Les couts sont domines par les lectures Firestore cote client.
  - Couts unitaires par evenement mesures dans build/client/modules/worker/*.dart
    (references fichier:ligne dans les constantes ci-dessous).
  - Perimetre : appareils Android uniquement (listeners en push natif, pas de
    polling REST desktop).

Tarifs consignes le 2026-08-10 (USD, region europe-west9 sauf mention) :
  - Firestore Standard : lectures 0.03 $/100k, ecritures 0.09 $/100k,
    suppressions 0.01 $/100k, stockage ~0.15 $/GiB/mois.
    Sources : cloud.google.com/firestore/pricing (table regionale dynamique,
    valeurs relevees via recherche ; incertitude ~+/-15 %, surcharger avec
    --price-read/--price-write/--price-delete si besoin).
  - Palier gratuit Firestore : 50k lectures/jour, 20k ecritures/jour,
    20k suppressions/jour, 1 GiB — applique a UNE SEULE base par projet
    (la premiere creee). ddust n'utilise que des bases nommees (eu_workers...)
    -> le palier ne couvre au mieux que la base "chaude" eu_workers.
    Source : firebase.google.com/docs/firestore/pricing.
  - Cloud Functions v2 (tarif Cloud Run) : 0.40 $/M requetes au-dela de 2M/mois,
    vCPU 0.000024 $/vCPU-s (180k gratuits/mois), RAM 0.0000025 $/GiB-s
    (360k gratuits/mois). Source : cloud.google.com/run/pricing.
  - Cloud Storage : stockage standard ~0.023 $/Go/mois, egress Internet (EU)
    ~0.12 $/Go. Source : cloud.google.com/storage/pricing.
  - Vertex AI Gemini 2.5 Flash-Lite : 0.10 $/M tokens entree, 0.40 $/M sortie
    (2.5 Pro : 1.25 / 10 $). Le projet plafonne Vertex a 5 $/mois avec
    auto-disable (build/backend/config.yml, module pubudget).
  - FCM : gratuit. Firebase Auth : gratuit (< 50k MAU). Cloud Scheduler :
    3 jobs gratuits/projet (ddust en a 1). Hosting : gratuit a cette echelle.

Usage :
  python gcp_cost_sim.py                        # 3 scenarios x 1/10/100/1000 familles
  python gcp_cost_sim.py --tasks-per-child 4    # scenario unique
  python gcp_cost_sim.py --no-free-tier         # palier gratuit non applique a eu_workers
"""

import argparse

# ---------------------------------------------------------------------------
# Couts unitaires en operations Firestore par evenement (mesures dans le code).
# R = lectures de documents, W = ecritures, D = suppressions, CF = invocations
# de la Cloud Function `messaging` (1 par destinataire de notification).
# ---------------------------------------------------------------------------

# Login / demarrage a froid — worker_session.dart:102
#   scan 2 regions (userindexes + users x2), dvsession invoque 2x (~14 R),
#   _loadClanTasks (liste ~159 taches + 19 domaines), _writeClanPlayer,
#   vigilance + ceremonies + premier dashboard (_onPlayerDocChanged = 16 R).
LOGIN = dict(r=215, w=6, d=0, cf=0)

# Tache validee de bout en bout (les 2 appareils), APRES delta-sync (2026-08) :
# _refreshTaskStatuses ne reliste plus les ~160 docs — requete touched > curseur
# (0-3 docs, plancher 1 lecture facturee par requete), doc users servi par un
# cache TTL, double lecture du verdict fusionnee.
#   prise (_selectTask worker_tasks.dart)                :   2 R,  3 W, 1 D
#   soumission preuve (on_combat_ok worker_combat.dart)  :  18 R,  4 W, 2 CF
#   verdict parent (_applyVerdict worker_verdict.dart,
#     dont 2x refresh DELTA ~2 R chacun)                 :  20 R,  6 W, 1 CF
#   reception verdict enfant (_resolveValidation +
#     _celebrateAfterAccept + refresh delta)             : 100 R,  4 W
# AVANT delta-sync : TASK_CYCLE = dict(r=644, w=17, d=1, cf=3)
#   (verdict parent 352 R avec 2x full list ~161 R ; reception enfant 270 R).
TASK_CYCLE = dict(r=140, w=17, d=1, cf=3)

# Visite d'ecran moyenne (hors tiroir deja compte dans TASK_CYCLE) :
#   Combat/domaine ~161 R -> ~3 R (delta), Clan ~175 R -> ~17 R (delta + roster),
#   Dashboard ~21 R, Personnage ~6 R, Items ~25 R -> moyenne ponderee ~15 R.
# AVANT delta-sync : SCREEN_VISIT = dict(r=100, ...)
SCREEN_VISIT = dict(r=15, w=0, d=0, cf=0)

# Journal de famille (worker_log.dart) : borne aux JOURNAL_READ_CAP evenements les
# plus recents (orderBy date desc + limit) — la collection clans_logs reste
# append-only et jamais purgee, mais son cout de LECTURE ne croit plus avec l'age
# du clan (le stockage, lui, croit toujours).
# AVANT : liste complete, cout = nb de logs accumules a chaque ouverture.
LOGS_PER_TASK = 2.0          # TaskDone + TaskValidated* par tache validee
JOURNAL_READ_CAP = 300       # limit de _buildLogStory (= plainMax)

# Ceremonie du butin (worker_butin.dart), ~1x/semaine pour 5 joueurs :
#   ~75 R (listes players/items x plusieurs + claims), ~25 W, ~15 CF.
BUTIN_WEEKLY = dict(r=75, w=25, d=0, cf=15)

# Surtaxe des regles de securite : get(userindexes/...) par operation sur les
# collections de clan (build/backend/config.yml, rules) -> ~+9 % de lectures.
RULES_SURCHARGE = 1.09

# ---------------------------------------------------------------------------
# Tarifs (USD) — surchargeable en CLI.
# ---------------------------------------------------------------------------
PRICES = dict(
    fs_read_per_100k=0.03,
    fs_write_per_100k=0.09,
    fs_delete_per_100k=0.01,
    fs_storage_gib_month=0.15,
    cf_per_million_req=0.40,
    cf_vcpu_second=0.000024,
    cf_gib_second=0.0000025,
    gcs_storage_gb_month=0.023,
    gcs_egress_gb=0.12,
)

FREE = dict(
    fs_reads_day=50_000,      # sur UNE base du projet (la premiere creee)
    fs_writes_day=20_000,
    fs_deletes_day=20_000,
    fs_storage_gib=1.0,
    cf_requests_month=2_000_000,
    cf_vcpu_s_month=180_000,
    cf_gib_s_month=360_000,
)

DAYS = 30.4  # jours moyens par mois

# Cloud Function : 256 MiB -> 0.25 GiB / 0.167 vCPU, duree moyenne ~400 ms.
CF_VCPU, CF_GIB, CF_SECONDS = 0.167, 0.25, 0.4

# budget-check : cron */5 min (pubudget) = cout fixe projet.
BUDGET_CHECK_PER_DAY = 288

# Assets Cloud Storage : ~577 Mo x 2 regions au repos ; ~50 Mo telecharges par
# appareil a l'installation, revalidation partielle (~20 Mo/appareil/mois,
# cache 30 j — dvcloudassets max_age_days: 30).
ASSETS_AT_REST_GB = 1.15
INSTALL_EGRESS_GB = 0.050
MONTHLY_EGRESS_GB = 0.020

# Vertex AI : conte du butin ~1x/sem (2.5 Pro) + inspirations occasionnelles
# (2.5 Flash-Lite). Estimation large ; plafond projet 5 $/mois (auto-disable).
VERTEX_PER_FAMILY_MONTH = 0.05
VERTEX_PROJECT_CAP = 5.0

# Stockage Firestore par clan : ~90 KiB + ~0.45 KiB par log (jamais purge).
CLAN_BASE_KIB = 90
LOG_DOC_KIB = 0.45


def family_daily_ops(p):
    """Operations Firestore par jour pour UNE famille (hors journal)."""
    people = p.children + p.adults
    tasks = p.children * p.tasks_per_child + p.adults * p.tasks_per_adult
    logins = people * p.sessions_per_person

    r = (logins * LOGIN["r"] + tasks * TASK_CYCLE["r"]
         + p.screen_visits * SCREEN_VISIT["r"] + BUTIN_WEEKLY["r"] / 7)
    w = (logins * LOGIN["w"] + tasks * TASK_CYCLE["w"] + BUTIN_WEEKLY["w"] / 7)
    d = tasks * TASK_CYCLE["d"]
    cf = tasks * TASK_CYCLE["cf"] + BUTIN_WEEKLY["cf"] / 7
    return dict(reads=r, writes=w, deletes=d, cf=cf, tasks=tasks, logins=logins)


def journal_reads_per_day(p, month):
    """Lectures/jour dues au journal : les JOURNAL_READ_CAP logs les plus recents
    a chaque ouverture (la collection grossit de ~LOGS_PER_TASK docs par tache
    validee, mais la lecture est bornee)."""
    tasks = p.children * p.tasks_per_child + p.adults * p.tasks_per_adult
    logs_mid_month = (month - 0.5) * DAYS * tasks * LOGS_PER_TASK
    return p.journal_opens * min(logs_mid_month, JOURNAL_READ_CAP)


def simulate_month(p, families, month, free_tier_on_workers):
    """Cout du mois `month` (1-indexe) pour `families` familles. Retourne un
    dict poste -> USD, plus quelques indicateurs."""
    ops = family_daily_ops(p)
    reads_day_fam = (ops["reads"] + journal_reads_per_day(p, month)) * RULES_SURCHARGE
    reads_day = reads_day_fam * families
    writes_day = ops["writes"] * families
    deletes_day = ops["deletes"] * families

    # --- Firestore (palier gratuit : quotas/jour sur une seule base) --------
    free_r = FREE["fs_reads_day"] if free_tier_on_workers else 0
    free_w = FREE["fs_writes_day"] if free_tier_on_workers else 0
    free_d = FREE["fs_deletes_day"] if free_tier_on_workers else 0
    fs_reads = max(0.0, reads_day - free_r) * DAYS
    fs_writes = max(0.0, writes_day - free_w) * DAYS
    fs_deletes = max(0.0, deletes_day - free_d) * DAYS
    fs_cost = (fs_reads / 1e5 * p.price_read
               + fs_writes / 1e5 * p.price_write
               + fs_deletes / 1e5 * p.price_delete)

    # Stockage Firestore (x2 regions ; logs jamais purges)
    tasks = ops["tasks"]
    logs_total = month * DAYS * tasks * LOGS_PER_TASK
    fs_gib = families * (CLAN_BASE_KIB + logs_total * LOG_DOC_KIB) / (1024 * 1024) * 2
    fs_storage_cost = max(0.0, fs_gib - (FREE["fs_storage_gib"] if free_tier_on_workers else 0)) \
        * PRICES["fs_storage_gib_month"]

    # --- Cloud Functions v2 (tarif Cloud Run) -------------------------------
    cf_month = (ops["cf"] * families + BUDGET_CHECK_PER_DAY) * DAYS
    cf_req_cost = max(0.0, cf_month - FREE["cf_requests_month"]) / 1e6 * PRICES["cf_per_million_req"]
    vcpu_s = cf_month * CF_SECONDS * CF_VCPU
    gib_s = cf_month * CF_SECONDS * CF_GIB
    cf_compute = (max(0.0, vcpu_s - FREE["cf_vcpu_s_month"]) * PRICES["cf_vcpu_second"]
                  + max(0.0, gib_s - FREE["cf_gib_s_month"]) * PRICES["cf_gib_second"])
    cf_cost = cf_req_cost + cf_compute

    # --- Cloud Storage ------------------------------------------------------
    devices = (p.children + p.adults) * families
    egress_gb = devices * (INSTALL_EGRESS_GB if month == 1 else 0.0) \
        + devices * MONTHLY_EGRESS_GB
    gcs_cost = ASSETS_AT_REST_GB * PRICES["gcs_storage_gb_month"] \
        + egress_gb * PRICES["gcs_egress_gb"]

    # --- Vertex AI (plafonne par le budget auto-disable) --------------------
    vertex_cost = min(VERTEX_PER_FAMILY_MONTH * families, VERTEX_PROJECT_CAP)

    total = fs_cost + fs_storage_cost + cf_cost + gcs_cost + vertex_cost
    return dict(
        firestore_ops=fs_cost, firestore_storage=fs_storage_cost,
        cloud_functions=cf_cost, storage=gcs_cost, vertex=vertex_cost,
        fcm_auth_hosting=0.0, total=total,
        reads_day=reads_day, writes_day=writes_day, cf_day=ops["cf"] * families,
    )


def fmt_usd(x):
    return ("%.2f $" % x) if x >= 0.005 else "~0 $"


def fmt_int(x):
    return format(int(round(x)), ",").replace(",", " ")


def run_scenario(p, label, family_counts, free_tier):
    print()
    print("=" * 78)
    print("SCENARIO %s — %d enfants x %.0f taches/j + %d adultes x %.0f taches/j"
          % (label, p.children, p.tasks_per_child, p.adults, p.tasks_per_adult))
    print("=" * 78)

    ops = family_daily_ops(p)
    m1 = simulate_month(p, 1, 1, free_tier)
    print("Profil d'UNE famille : %s taches validees/j, %s logins/j, "
          "%s lect./j (mois 1, regles incluses), %s ecr./j, %s appels CF/j"
          % (fmt_int(ops["tasks"]), fmt_int(ops["logins"]),
             fmt_int(m1["reads_day"]), fmt_int(m1["writes_day"]), fmt_int(m1["cf_day"])))
    print()

    hdr = ("%9s | %14s | %10s | %10s | %10s | %12s"
           % ("Familles", "Lect./j projet", "Total M1", "Total M6", "Total M12", "$/fam. M12"))
    print(hdr)
    print("-" * len(hdr))
    for f in family_counts:
        r1 = simulate_month(p, f, 1, free_tier)
        r6 = simulate_month(p, f, 6, free_tier)
        r12 = simulate_month(p, f, 12, free_tier)
        print("%9s | %14s | %10s | %10s | %10s | %12s"
              % (fmt_int(f), fmt_int(r12["reads_day"]), fmt_usd(r1["total"]),
                 fmt_usd(r6["total"]), fmt_usd(r12["total"]),
                 fmt_usd(r12["total"] / f)))

    # Detail par service pour 1 famille, mois 1 et mois 12
    print()
    print("Detail 1 famille (USD/mois) :        mois 1      mois 12")
    d1 = simulate_month(p, 1, 1, free_tier)
    d12 = simulate_month(p, 1, 12, free_tier)
    rows = [("Firestore operations", "firestore_ops"),
            ("Firestore stockage", "firestore_storage"),
            ("Cloud Functions / Run", "cloud_functions"),
            ("Cloud Storage (assets)", "storage"),
            ("Vertex AI (plafond 5$)", "vertex"),
            ("FCM / Auth / Hosting", "fcm_auth_hosting")]
    for name, key in rows:
        print("  %-32s %9s    %9s" % (name, fmt_usd(d1[key]), fmt_usd(d12[key])))
    print("  %-32s %9s    %9s" % ("TOTAL", fmt_usd(d1["total"]), fmt_usd(d12["total"])))


def main():
    ap = argparse.ArgumentParser(description="Simulation des couts GCP pour ddust")
    ap.add_argument("--children", type=int, default=3)
    ap.add_argument("--adults", type=int, default=2)
    ap.add_argument("--tasks-per-child", type=float, default=None,
                    help="si absent : 3 scenarios (2 / 3 / 5)")
    ap.add_argument("--tasks-per-adult", type=float, default=2)
    ap.add_argument("--sessions-per-person", type=float, default=3,
                    help="demarrages d'app par personne et par jour")
    ap.add_argument("--screen-visits", type=float, default=20,
                    help="visites d'ecran supplementaires par famille et par jour")
    ap.add_argument("--journal-opens", type=float, default=2,
                    help="ouvertures du journal par famille et par jour")
    ap.add_argument("--families", type=int, nargs="+", default=[1, 10, 100, 1000])
    ap.add_argument("--no-free-tier", action="store_true",
                    help="ne pas appliquer le palier gratuit Firestore a eu_workers")
    ap.add_argument("--price-read", type=float, default=PRICES["fs_read_per_100k"],
                    help="$/100k lectures (defaut %(default)s)")
    ap.add_argument("--price-write", type=float, default=PRICES["fs_write_per_100k"])
    ap.add_argument("--price-delete", type=float, default=PRICES["fs_delete_per_100k"])
    p = ap.parse_args()
    free_tier = not p.no_free_tier

    print("Simulation des couts Google Cloud — Donjons & Savons")
    print("Perimetre : Android uniquement ; region europe-west9 ; tarifs du 2026-08-10.")
    print("Palier gratuit Firestore (1 seule base/projet) applique a eu_workers : %s"
          % ("OUI" if free_tier else "NON"))
    if p.tasks_per_child is not None:
        run_scenario(p, "PERSONNALISE", p.families, free_tier)
    else:
        for label, tpc in [("BAS", 2.0), ("CENTRAL", 3.0), ("HAUT", 5.0)]:
            p.tasks_per_child = tpc
            run_scenario(p, label, p.families, free_tier)

    print()
    print("Notes :")
    print(" - FCM, Firebase Auth (<50k MAU), Hosting et Cloud Scheduler (1 job) : 0 $.")
    print(" - budget-check (cron 5 min) et stockage des assets : couts fixes projet,")
    print("   inclus, couverts par les paliers gratuits Cloud Run.")
    print(" - Le journal (clans_logs) n'est jamais purge mais sa LECTURE est bornee")
    print("   aux %d evenements les plus recents ; seul le stockage croit encore." % JOURNAL_READ_CAP)
    print(" - Incertitude tarifaire regionale ~+/-15 % : surcharger --price-read etc.")


if __name__ == "__main__":
    main()
