#!/usr/bin/env python3
"""Génère la version suivante des CGU à partir de la version courante.

Contexte : décision du 2026-08-11 de lancer l'app payante d'emblée (voir strategie.md).
Les CGU en vigueur (EU v4, US v2) annoncent un essai de 15 jours alors que la grille
retenue le 2026-07-07 est de 14 jours, ne décrivent pas le cycle de défaut de paiement
que l'application applique réellement, ne portent pas les mentions de rétractation et de
renouvellement à 24 h exigées avant un achat, et présentent encore le service comme une
beta — intenable dès lors qu'on facture.

`pudocuments` retient la version `max` par tuple (région, état, langue, type) : on crée
donc de nouveaux fichiers sans jamais toucher aux précédents, qui restent la preuve de ce
qui a été accepté par les utilisateurs existants.

Chaque remplacement est vérifié : une occurrence attendue, sinon le script échoue. Un
document légal généré à moitié est pire que pas de document du tout.

    python tools/gen_cgu_next.py [--check]
"""

import re
import sys
from pathlib import Path

DOCS = Path(__file__).parent.parent / "legal" / "documents"

# (région, version source, version cible, date longue par langue)
BUMPS = [("eu", 4, 5), ("us", 2, 3)]
LANGS = ("fr", "en", "es")

DATE_ADULT = {
    "fr": "en vigueur au 11 août 2026",
    "en": "effective 11 August 2026",
    "es": "en vigor desde el 11 de agosto de 2026",
}
DATE_KID = {
    "fr": "11 août 2026",
    "en": "11 August 2026",
    "es": "11 de agosto de 2026",
}
VERSION_LABEL = {"fr": "Version :", "en": "Version:", "es": "Versión:"}


# ── blocs adultes ────────────────────────────────────────────────────────────

# 1. essai 15 → 14 jours (décision 2026-07-07, jamais répercutée dans les CGU)
TRIAL = {
    "fr": [
        ("un <strong>essai gratuit de\n15 jours</strong>", "un <strong>essai gratuit de\n14 jours</strong>"),
        ("<li><strong>Essai gratuit</strong> — 15 jours,", "<li><strong>Essai gratuit</strong> — 14 jours,"),
    ],
    "en": [
        ("a <strong>15-day free\ntrial</strong>", "a <strong>14-day free\ntrial</strong>"),
        ("<li><strong>Free trial</strong> — 15 days,", "<li><strong>Free trial</strong> — 14 days,"),
    ],
    "es": [
        ("una <strong>prueba\ngratuita de 15 días</strong>", "una <strong>prueba\ngratuita de 14 días</strong>"),
        ("<li><strong>Prueba gratuita</strong> — 15 días,", "<li><strong>Prueba gratuita</strong> — 14 días,"),
    ],
}

# 2. après la puce « Abonnement » : renouvellement 24 h + offre fondateurs
SUB_ANCHOR = {
    "fr": """  <li><strong>Abonnement</strong> — il est souscrit par le <strong>chef de clan</strong> et couvre l'ensemble des
  membres de son clan : un seul abonnement et un seul payeur par clan. Il se renouvelle automatiquement jusqu'à
  résiliation.</li>
""",
    "en": """  <li><strong>Subscription</strong> — it is taken out by the <strong>clan chief</strong> and covers every member
  of their clan: one subscription and one payer per clan. It renews automatically until cancelled.</li>
""",
    "es": """  <li><strong>Suscripción</strong> — la contrata el <strong>jefe de clan</strong> y cubre a todos los miembros de
  su clan: una sola suscripción y un solo pagador por clan. Se renueva automáticamente hasta su cancelación.</li>
""",
}

SUB_EXTRA = {
    "fr": """  <li><strong>Renouvellement automatique</strong> — le paiement est débité de votre compte Google Play lors de la
  confirmation de l'achat, puis à chaque échéance. L'abonnement se renouvelle automatiquement à moins que le
  renouvellement automatique ne soit désactivé <strong>au moins 24 heures avant la fin de la période en
  cours</strong>.</li>
  <li><strong>Offre fondateurs</strong> — les premiers clans inscrits peuvent bénéficier d'une offre de lancement
  (essai allongé et tarif réduit sur la première année). Elle est attribuée automatiquement aux clans créés avant
  une date d'éligibilité, ne se cumule pas avec une autre offre promotionnelle et ne se reconduit pas : au terme
  de la période remisée, l'abonnement se poursuit au tarif courant, annoncé à l'avance.</li>
""",
    "en": """  <li><strong>Automatic renewal</strong> — payment is charged to your Google Play account upon confirmation of
  purchase, and then on each renewal date. The subscription renews automatically unless auto-renewal is turned off
  <strong>at least 24 hours before the end of the current period</strong>.</li>
  <li><strong>Founders offer</strong> — the first clans to sign up may benefit from a launch offer (an extended
  trial and a reduced price for the first year). It is granted automatically to clans created before an
  eligibility date, cannot be combined with another promotional offer and does not renew: at the end of the
  discounted period, the subscription continues at the standard price, announced in advance.</li>
""",
    "es": """  <li><strong>Renovación automática</strong> — el pago se carga en su cuenta de Google Play al confirmar la
  compra y, después, en cada vencimiento. La suscripción se renueva automáticamente salvo que la renovación
  automática se desactive <strong>al menos 24 horas antes del final del periodo en curso</strong>.</li>
  <li><strong>Oferta fundadores</strong> — los primeros clanes registrados pueden beneficiarse de una oferta de
  lanzamiento (prueba ampliada y precio reducido el primer año). Se concede automáticamente a los clanes creados
  antes de una fecha de elegibilidad, no es acumulable con otra oferta promocional y no se prorroga: al término
  del periodo con descuento, la suscripción continúa al precio vigente, anunciado con antelación.</li>
""",
}

# 3. « absence d'abonnement actif » : la conservation n'est plus indéfinie
NO_SUB_OLD = {
    "fr": """  <li><strong>Absence d'abonnement actif</strong> — à l'issue de l'essai ou après résiliation, l'accès aux
  fonctionnalités du clan est suspendu. Vos données et celles de votre clan sont conservées et redeviennent
  accessibles si vous vous réabonnez ; elles ne sont supprimées que par une suppression de compte (article 11).</li>
""",
    "en": """  <li><strong>No active subscription</strong> — at the end of the trial or after cancellation, access to the
  clan's features is suspended. Your data and your clan's data are kept and become accessible again if you
  resubscribe; they are only deleted by deleting the account (section 11).</li>
""",
    "es": """  <li><strong>Sin suscripción activa</strong> — al terminar la prueba o tras la cancelación, el acceso a las
  funcionalidades del clan queda suspendido. Sus datos y los de su clan se conservan y vuelven a ser accesibles si
  se suscribe de nuevo; solo se suprimen mediante la supresión de la cuenta (artículo 11).</li>
""",
}

NO_SUB_NEW = {
    "fr": """  <li><strong>Absence d'abonnement actif</strong> — à l'issue de l'essai ou après résiliation, l'accès aux
  fonctionnalités du clan est suspendu. Vos données et celles de votre clan sont conservées et redeviennent
  accessibles si vous vous réabonnez ; elles ne sont supprimées que par une suppression de compte (article 11) ou
  au terme du calendrier de défaut de paiement ci-dessous.</li>
""",
    "en": """  <li><strong>No active subscription</strong> — at the end of the trial or after cancellation, access to the
  clan's features is suspended. Your data and your clan's data are kept and become accessible again if you
  resubscribe; they are only deleted by deleting the account (section 11) or at the end of the payment-failure
  schedule set out below.</li>
""",
    "es": """  <li><strong>Sin suscripción activa</strong> — al terminar la prueba o tras la cancelación, el acceso a las
  funcionalidades del clan queda suspendido. Sus datos y los de su clan se conservan y vuelven a ser accesibles si
  se suscribe de nuevo; solo se suprimen mediante la supresión de la cuenta (artículo 11) o al término del
  calendario de impago que figura a continuación.</li>
""",
}

# 4. rétractation : la mention lapidaire devient la clause exigible avant achat.
#    Clause distincte par région, et ce n'est pas une coquetterie : le droit de rétractation
#    de 14 jours sur le contenu numérique est une construction du droit européen de la
#    consommation. Les CGU US ne parlent donc que de remboursement, et il ne faut surtout pas
#    y importer une « renonciation au droit de rétractation » qui n'a pas d'objet.
WITHDRAW_OLD = {
    "eu": {
        "fr": """  <li><strong>Rétractation et remboursement</strong> — ils s'exercent auprès de la plateforme, selon ses
  conditions et sans préjudice de vos droits légaux.</li>
""",
        "en": """  <li><strong>Withdrawal and refunds</strong> — these are exercised with the platform, under its conditions and
  without prejudice to your statutory rights.</li>
""",
        "es": """  <li><strong>Desistimiento y reembolso</strong> — se ejercen ante la plataforma, según sus condiciones y sin
  perjuicio de sus derechos legales.</li>
""",
    },
    "us": {
        "fr": """  <li><strong>Remboursement</strong> — il s'exerce auprès de la plateforme, selon ses conditions et sans préjudice
  des droits que la loi de votre État vous reconnaît.</li>
""",
        "en": """  <li><strong>Refunds</strong> — these are handled by the platform, under its own conditions and without prejudice
  to any rights you may have under the law of your state.</li>
""",
        "es": """  <li><strong>Reembolso</strong> — se ejerce ante la plataforma, según sus condiciones y sin perjuicio de los
  derechos que le reconozca la ley de su estado.</li>
""",
    },
}

WITHDRAW_NEW = {
    "eu": {
        "fr": """  <li><strong>Rétractation et remboursement</strong> — tous les achats et abonnements sont traités par la
  plateforme de téléchargement. En achetant un contenu numérique dans l'Application, vous acceptez que sa
  fourniture commence immédiatement, ce qui entraîne <strong>la renonciation à votre droit de
  rétractation</strong> dans les conditions prévues par la plateforme. Pour toute demande de rétractation légale
  ou de remboursement dans les délais prévus par la loi, utilisez les outils de gestion d'abonnement et
  d'historique d'achat de votre compte Google. Ces stipulations sont sans préjudice de vos droits légaux
  impératifs.</li>
""",
        "en": """  <li><strong>Withdrawal and refunds</strong> — all purchases and subscriptions are processed by the download
  platform. By purchasing digital content in the Application, you agree that its supply begins immediately, which
  entails <strong>the waiver of your right of withdrawal</strong> under the conditions set by the platform. For
  any statutory withdrawal or refund request within the time limits provided by law, use the subscription
  management and purchase history tools of your Google account. These provisions are without prejudice to your
  mandatory statutory rights.</li>
""",
        "es": """  <li><strong>Desistimiento y reembolso</strong> — todas las compras y suscripciones las tramita la plataforma de
  descarga. Al comprar contenido digital en la Aplicación, usted acepta que su suministro comience de inmediato,
  lo que conlleva <strong>la renuncia a su derecho de desistimiento</strong> en las condiciones previstas por la
  plataforma. Para cualquier solicitud legal de desistimiento o de reembolso dentro de los plazos previstos por la
  ley, utilice las herramientas de gestión de suscripciones y de historial de compras de su cuenta de Google.
  Estas estipulaciones se entienden sin perjuicio de sus derechos legales imperativos.</li>
""",
    },
    "us": {
        "fr": """  <li><strong>Remboursement</strong> — tous les achats et abonnements sont traités par la plateforme de
  téléchargement. La fourniture du contenu numérique commence immédiatement après la confirmation de l'achat. Les
  demandes de remboursement s'exercent auprès de la plateforme, au moyen des outils de gestion d'abonnement et
  d'historique d'achat de votre compte Google, selon ses conditions et sans préjudice des droits que la loi de
  votre État vous reconnaît.</li>
""",
        "en": """  <li><strong>Refunds</strong> — all purchases and subscriptions are processed by the download platform. Supply of
  the digital content begins immediately upon confirmation of purchase. Refund requests are handled by the
  platform, through the subscription management and purchase history tools of your Google account, under its own
  conditions and without prejudice to any rights you may have under the law of your state.</li>
""",
        "es": """  <li><strong>Reembolso</strong> — todas las compras y suscripciones las tramita la plataforma de descarga. El
  suministro del contenido digital comienza inmediatamente tras la confirmación de la compra. Las solicitudes de
  reembolso se tramitan ante la plataforma, mediante las herramientas de gestión de suscripciones y de historial
  de compras de su cuenta de Google, según sus condiciones y sin perjuicio de los derechos que le reconozca la ley
  de su estado.</li>
""",
    },
}

# 5. le calendrier de défaut de paiement, inséré avant la clause d'évolution des offres
OFFER_CHANGE = {
    "fr": "<p>Toute évolution des offres fera l'objet d'une information préalable",
    "en": "<p>Any change to these offers will be subject to prior notice",
    "es": "<p>Toda evolución de las ofertas será objeto de una información previa",
}

DEFAULT_CYCLE = {
    "fr": """<p><strong>Défaut de paiement.</strong> Si un paiement ne peut pas être recouvré, un calendrier volontairement
long s'applique avant toute conséquence irréversible. Il court à compter du premier paiement non recouvré :</p>
<ul>
  <li><strong>Jours 1 à 10 — période de grâce.</strong> L'accès au clan reste entier. Des rappels sont adressés
  aux adultes du clan, jamais aux mineurs.</li>
  <li><strong>Jours 10 à 50 — facturation suspendue.</strong> L'accès au clan reste ouvert. Régulariser le
  paiement rétablit l'abonnement sans aucune perte.</li>
  <li><strong>Jour 50 — clan bloqué.</strong> L'accès aux fonctionnalités du clan est bloqué, mais les données
  sont intégralement conservées. Le chef de clan peut à tout moment réactiver l'abonnement et retrouver son clan
  intact, ou demander la suppression immédiate des données du clan.</li>
  <li><strong>Jour 90 — suppression.</strong> Les données du clan et de ses membres sont définitivement
  supprimées, selon les modalités de l'article 11. <strong>Cette suppression est irréversible.</strong></li>
</ul>
""",
    "en": """<p><strong>Payment failure.</strong> If a payment cannot be collected, a deliberately long schedule applies
before any irreversible consequence. It runs from the first uncollected payment:</p>
<ul>
  <li><strong>Days 1 to 10 — grace period.</strong> Access to the clan remains complete. Reminders are sent to the
  adults of the clan, never to minors.</li>
  <li><strong>Days 10 to 50 — billing on hold.</strong> Access to the clan remains open. Settling the payment
  restores the subscription with no loss whatsoever.</li>
  <li><strong>Day 50 — clan locked.</strong> Access to the clan's features is blocked, but all data is kept. The
  clan chief may at any time reactivate the subscription and find their clan intact, or request the immediate
  deletion of the clan's data.</li>
  <li><strong>Day 90 — deletion.</strong> The data of the clan and its members is permanently deleted, in
  accordance with section 11. <strong>This deletion is irreversible.</strong></li>
</ul>
""",
    "es": """<p><strong>Impago.</strong> Si un pago no puede cobrarse, se aplica un calendario deliberadamente largo antes de
cualquier consecuencia irreversible. Comienza a contar desde el primer pago no cobrado:</p>
<ul>
  <li><strong>Días 1 a 10 — periodo de gracia.</strong> El acceso al clan se mantiene íntegro. Se envían
  recordatorios a los adultos del clan, nunca a los menores.</li>
  <li><strong>Días 10 a 50 — facturación en suspenso.</strong> El acceso al clan sigue abierto. Regularizar el
  pago restablece la suscripción sin pérdida alguna.</li>
  <li><strong>Día 50 — clan bloqueado.</strong> El acceso a las funcionalidades del clan queda bloqueado, pero los
  datos se conservan íntegramente. El jefe de clan puede en cualquier momento reactivar la suscripción y recuperar
  su clan intacto, o solicitar la supresión inmediata de los datos del clan.</li>
  <li><strong>Día 90 — supresión.</strong> Los datos del clan y de sus miembros se suprimen definitivamente,
  conforme al artículo 11. <strong>Esta supresión es irreversible.</strong></li>
</ul>
""",
}

# 6. on ne facture pas un service qu'on présente comme une beta
BETA_HEADING = {
    "fr": "<h2>10. Disponibilité et limitation de responsabilité</h2>",
    "en": "<h2>10. Availability and limitation of liability</h2>",
    "es": "<h2>10. Disponibilidad y limitación de responsabilidad</h2>",
}

BETA_INTRO = {
    "fr": "L'Application évolue régulièrement : des fonctionnalités peuvent être ajoutées, modifiées ou\ninterrompues, et le service peut comporter des défauts. ",
    "en": "The Application evolves regularly: features may be added, changed or discontinued, and the service may\ncontain defects. ",
    "es": "La Aplicación evoluciona con regularidad: pueden añadirse, modificarse o interrumpirse funcionalidades, y\nel servicio puede presentar defectos. ",
}

BETA_TAIL = {
    "fr": "L'éditeur s'efforce",
    "en": "publisher strives",
    "es": "El editor se esfuerza",
}


# ── bloc mineurs ─────────────────────────────────────────────────────────────

# Un mineur dont le clan sera bloqué puis effacé doit l'apprendre ici, pas par surprise.
# Le ton suit la consigne produit : ne pas inquiéter l'enfant, et lui dire explicitement
# que ce n'est ni son problème ni sa faute.
KID_PAUSE = {
    "fr": """<p>Et si un jour l'adulte qui paie n'y arrive plus ? Pas de panique : le jeu ne s'arrête pas d'un coup. Ton clan
continue pendant plusieurs semaines, et ce n'est pas à toi de t'en occuper — c'est une affaire d'adultes. Si
personne ne reprend l'abonnement, ton clan finit par se mettre en pause, puis ses informations sont effacées au
bout de trois mois. Ce n'est jamais ta faute, et tu ne perds rien de ce que tu as fait pour de vrai.</p>

""",
    "en": """<p>And what if one day the adult who pays cannot manage it any more? Don't worry: the game does not stop all at
once. Your clan keeps going for several weeks, and it is not for you to sort out — that is a grown-up matter. If
nobody starts the subscription again, your clan eventually goes to sleep, and its information is erased after
three months. It is never your fault, and you lose nothing of what you really did.</p>

""",
    "es": """<p>¿Y si un día el adulto que paga ya no puede? No te preocupes: el juego no se detiene de golpe. Tu clan sigue
funcionando durante varias semanas, y no eres tú quien debe ocuparse de eso: es cosa de adultos. Si nadie reanuda
la suscripción, tu clan acaba poniéndose en pausa y su información se borra al cabo de tres meses. Nunca es culpa
tuya, y no pierdes nada de lo que has hecho de verdad.</p>

""",
}

KID_SECTION_7 = "\n<h2>7."


def _sub(text, old, new, label, path):
    """Remplacement à occurrence unique — échoue plutôt que de produire un document partiel."""
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"[{path.name}] « {label} » : {n} occurrence(s), 1 attendue.")
    return text.replace(old, new)


def build_adult(text, lang, src_v, dst_v, region, path):
    for old, new in TRIAL[lang]:
        text = _sub(text, old, new, "essai 15→14 jours", path)
    text = _sub(text, SUB_ANCHOR[lang], SUB_ANCHOR[lang] + SUB_EXTRA[lang],
                "renouvellement 24 h + offre fondateurs", path)
    text = _sub(text, NO_SUB_OLD[lang], NO_SUB_NEW[lang], "absence d'abonnement actif", path)
    text = _sub(text, WITHDRAW_OLD[region][lang], WITHDRAW_NEW[region][lang],
                "rétractation / remboursement", path)
    text = _sub(text, OFFER_CHANGE[lang], DEFAULT_CYCLE[lang] + "\n" + OFFER_CHANGE[lang],
                "calendrier de défaut de paiement", path)

    # heading + phrase d'ouverture de l'article 10 (formulations divergentes EU/US : regex)
    text, n = re.subn(r"<h2>10\.[^<]*</h2>", BETA_HEADING[lang], text)
    if n != 1:
        raise SystemExit(f"[{path.name}] titre article 10 : {n} occurrence(s), 1 attendue.")
    pattern = re.compile(r"(<h2>10\.[^<]*</h2>\n<p>).*?(" + re.escape(BETA_TAIL[lang]) + ")", re.S)
    text, n = pattern.subn(lambda m: m.group(1) + BETA_INTRO[lang] + m.group(2), text)
    if n != 1:
        raise SystemExit(f"[{path.name}] intro article 10 : {n} occurrence(s), 1 attendue.")
    return text


def build_kid(text, lang, src_v, dst_v, region, path):
    text = _sub(text, KID_SECTION_7, "\n" + KID_PAUSE[lang] + "<h2>7.",
                "que se passe-t-il si l'adulte ne paie plus", path)
    return text


def bump_common(text, lang, state, src_v, dst_v, region, path):
    """Numéro de version, date d'entrée en vigueur et URLs auto-référentes."""
    label = VERSION_LABEL[lang]
    date = DATE_ADULT[lang] if state == "a" else DATE_KID[lang]
    pattern = re.compile(re.escape(f"<strong>{label}</strong> {src_v} — ") + r"[^<]*")
    text, n = pattern.subn(f"<strong>{label}</strong> {dst_v} — {date}", text)
    if n != 1:
        raise SystemExit(f"[{path.name}] en-tête de version : {n} occurrence(s), 1 attendue.")

    # Les CGU mineurs renvoient aussi vers les CGU adultes de la même région/langue.
    for st in ("a", "k"):
        text = text.replace(
            f"{region}-{st}-{lang}-cgu-v{src_v}.html",
            f"{region}-{st}-{lang}-cgu-v{dst_v}.html",
        )
    if f"cgu-v{src_v}.html" in text:
        raise SystemExit(f"[{path.name}] une URL en v{src_v} subsiste.")
    return text


def main():
    check = "--check" in sys.argv
    written = []
    for region, src_v, dst_v in BUMPS:
        for state in ("a", "k"):
            for lang in LANGS:
                src = DOCS / f"{region}-{state}-{lang}-cgu-v{src_v}.html"
                dst = DOCS / f"{region}-{state}-{lang}-cgu-v{dst_v}.html"
                if not src.exists():
                    raise SystemExit(f"source absente : {src}")
                text = src.read_text(encoding="utf-8")
                builder = build_adult if state == "a" else build_kid
                text = builder(text, lang, src_v, dst_v, region, src)
                text = bump_common(text, lang, state, src_v, dst_v, region, src)
                if not check:
                    dst.write_text(text, encoding="utf-8")
                written.append(dst.name)
    verb = "vérifié" if check else "écrit"
    print(f"{len(written)} document(s) {verb} :")
    for name in written:
        print(f"  {name}")


if __name__ == "__main__":
    main()
