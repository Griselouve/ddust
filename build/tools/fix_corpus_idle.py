#!/usr/bin/env python3
"""La dissolution d'un clan inactif entre au corpus légal. Édition EN PLACE.

Contexte : décision du 2026-09-16, dans la foulée de `fix_corpus_usage.py`. Un clan
qui n'avait jamais payé, ou qui avait résilié proprement, n'avait AUCUN calendrier
pour le regarder : le balayage d'impayé compte depuis le premier impayé, et un clan
sans achat n'a pas de document de facturation. Ses données restaient pour toujours.

Le comblement est au serveur (`pulse_sweeper`, piste SOMMEIL, puis `clan_purge`) :
un clan sans abonnement en cours dont aucun membre ne s'est connecté depuis deux ans
est dissous. Les adultes reçoivent un rappel tous les six mois (sauf s'ils ont coupé
les rappels), puis dans tous les cas un préavis un mois avant. Une connexion de
n'importe quel membre annule tout. Un clan abonné n'est jamais concerné.

Une règle qui efface les données d'une famille et qu'aucun document n'annonce est
une règle qu'on ne peut pas appliquer. D'où ce script, qui l'écrit à QUATRE endroits :

    *-a-*-cgu-v1.html      96  article 2, puce « absence d'abonnement actif » :
                               une phrase, la conservation n'y est plus inconditionnelle
                           96  article 11 : le paragraphe « Clan inactif », avec la
                               cascade (c'est la même que la suppression d'un chef)
    *-a-*-privacy-v1.html  96  la puce « Clan inactif », après celle du clan bloqué
    *-k-*-privacy-v1.html  96  un paragraphe dans « faire disparaître tes
                               informations », à hauteur d'enfant

⚠ PAS DE BUMP : l'application n'est pas publiée (cf. `fix_corpus_usage.py`). Les
  documents adultes portaient déjà la date du 16 septembre 2026 ; les politiques
  ENFANTS, touchées ici pour la première fois, ont été datées du même jour à la main
  juste après ce passage (la ligne d'en-tête enfant n'a pas la même forme que l'adulte,
  « 1 — 16 septembre 2026 » sans « en vigueur au »). Les CGU enfants, inchangées,
  gardent le 28 août.

Chaque insertion est vérifiée : une occurrence attendue, sinon le script échoue.

⚠ SCRIPT DÉJÀ JOUÉ. Il refuse de s'appliquer deux fois (il détecte ses propres
  insertions) et reste ici comme la trace de ce qui a changé.

    python tools/fix_corpus_idle.py            # écrit
    python tools/fix_corpus_idle.py --check    # vérifie sans écrire
"""

import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from fix_corpus_usage import NOSUB, PRIVACY_NEW  # noqa: E402  (les ancres exactes)

DOCS = Path(__file__).parent.parent / "legal" / "documents"
LANGS = ("fr", "en", "es", "de", "it", "pt", "br", "nl")

# --- CGU, article 2 : la phrase ajoutée à la fin de la puce d'absence d'abonnement --
CGU_ART2 = {
    "fr": " Un clan sans abonnement en cours qui reste deux ans sans aucune connexion est toutefois dissous (article 11).",
    "en": " A clan with no current subscription that goes two years without any sign-in is, however, dissolved (section 11).",
    "es": " No obstante, un clan sin suscripción en curso que pasa dos años sin ninguna conexión se disuelve (artículo 11).",
    "de": " Ein Clan ohne laufendes Abonnement, der zwei Jahre lang ohne jede Anmeldung bleibt, wird jedoch aufgelöst (Artikel 11).",
    "it": " Un clan senza abbonamento in corso che resta due anni senza alcun accesso viene tuttavia sciolto (articolo 11).",
    "pt": " Um clã sem subscrição em curso que fique dois anos sem qualquer ligação é, no entanto, dissolvido (artigo 11).",
    "br": " Um clã sem assinatura em andamento que fique dois anos sem nenhuma conexão é, no entanto, dissolvido (artigo 11).",
    "nl": " Een clan zonder lopend abonnement die twee jaar lang zonder enige login blijft, wordt echter ontbonden (artikel 11).",
}

# --- CGU, article 11 : le paragraphe « Clan inactif » ------------------------------
# Inséré juste avant le DERNIER paragraphe de l'article (la suspension par l'éditeur),
# c'est-à-dire après la cascade de suppression qu'il reprend.
CGU_ART11 = {
    "fr": "<p><strong>Clan inactif.</strong> Un clan sans abonnement en cours dont aucun membre ne s'est connecté depuis "
          "<strong>deux ans</strong> est dissous, selon le calendrier ci-dessus et avec les mêmes effets en cascade que la "
          "suppression du compte d'un chef. Les adultes du clan en sont avertis à l'avance : un rappel tous les six mois, "
          "sauf s'ils ont désactivé les rappels, puis un préavis <strong>un mois</strong> avant la dissolution, qui leur est "
          "adressé dans tous les cas. Une seule connexion d'un membre du clan, quel qu'il soit, suffit à l'éviter. Un clan "
          "dont l'abonnement est en cours n'est jamais dissous pour inactivité.</p>",
    "en": "<p><strong>Inactive clan.</strong> A clan with no current subscription none of whose members has signed in for "
          "<strong>two years</strong> is dissolved, following the timetable above and with the same cascading effects as "
          "the deletion of a chief's account. The adults of the clan are warned in advance: a reminder every six months, "
          "unless they have turned reminders off, then a notice <strong>one month</strong> before the dissolution, which "
          "is sent to them in every case. A single sign-in by any member of the clan is enough to prevent it. A clan whose "
          "subscription is current is never dissolved for inactivity.</p>",
    "es": "<p><strong>Clan inactivo.</strong> Un clan sin suscripción en curso del que ningún miembro se ha conectado desde "
          "hace <strong>dos años</strong> se disuelve, según el calendario anterior y con los mismos efectos en cascada que "
          "la supresión de la cuenta de un jefe. Los adultos del clan reciben aviso con antelación: un recordatorio cada "
          "seis meses, salvo si han desactivado los recordatorios, y después un preaviso <strong>un mes</strong> antes de la "
          "disolución, que se les envía en todos los casos. Basta con una sola conexión de cualquier miembro del clan para "
          "evitarlo. Un clan cuya suscripción está en curso nunca se disuelve por inactividad.</p>",
    "de": "<p><strong>Inaktiver Clan.</strong> Ein Clan ohne laufendes Abonnement, von dem sich seit <strong>zwei "
          "Jahren</strong> kein Mitglied angemeldet hat, wird aufgelöst, nach dem obigen Zeitplan und mit denselben "
          "Folgewirkungen wie die Löschung des Kontos eines Clanchefs. Die Erwachsenen des Clans werden vorab "
          "benachrichtigt: alle sechs Monate eine Erinnerung, sofern sie die Erinnerungen nicht deaktiviert haben, dann "
          "eine Vorankündigung <strong>einen Monat</strong> vor der Auflösung, die ihnen in jedem Fall zugesandt wird. Eine "
          "einzige Anmeldung eines beliebigen Clanmitglieds genügt, um sie zu verhindern. Ein Clan mit laufendem "
          "Abonnement wird nie wegen Inaktivität aufgelöst.</p>",
    "it": "<p><strong>Clan inattivo.</strong> Un clan senza abbonamento in corso di cui nessun membro si è connesso da "
          "<strong>due anni</strong> viene sciolto, secondo il calendario sopra indicato e con gli stessi effetti a cascata "
          "della cancellazione dell'account di un capo. Gli adulti del clan ne sono avvisati in anticipo: un promemoria "
          "ogni sei mesi, salvo che abbiano disattivato i promemoria, poi un preavviso <strong>un mese</strong> prima dello "
          "scioglimento, che viene loro inviato in ogni caso. Basta un solo accesso di un qualsiasi membro del clan per "
          "evitarlo. Un clan con abbonamento in corso non viene mai sciolto per inattività.</p>",
    "pt": "<p><strong>Clã inativo.</strong> Um clã sem subscrição em curso do qual nenhum membro se ligou há <strong>dois "
          "anos</strong> é dissolvido, segundo o calendário acima e com os mesmos efeitos em cascata da supressão da conta "
          "de um chefe. Os adultos do clã são avisados com antecedência: um lembrete a cada seis meses, salvo se tiverem "
          "desativado os lembretes, e depois um pré-aviso <strong>um mês</strong> antes da dissolução, que lhes é enviado "
          "em todos os casos. Basta uma única ligação de qualquer membro do clã para o evitar. Um clã cuja subscrição está "
          "em curso nunca é dissolvido por inatividade.</p>",
    "br": "<p><strong>Clã inativo.</strong> Um clã sem assinatura em andamento do qual nenhum membro se conectou há "
          "<strong>dois anos</strong> é dissolvido, segundo o calendário acima e com os mesmos efeitos em cascata da "
          "exclusão da conta de um chefe. Os adultos do clã são avisados com antecedência: um lembrete a cada seis meses, "
          "a menos que tenham desativado os lembretes, e depois um aviso prévio <strong>um mês</strong> antes da "
          "dissolução, que é enviado a eles em todos os casos. Basta uma única conexão de qualquer membro do clã para "
          "evitá-la. Um clã cuja assinatura está em andamento nunca é dissolvido por inatividade.</p>",
    "nl": "<p><strong>Inactieve clan.</strong> Een clan zonder lopend abonnement waarvan sinds <strong>twee jaar</strong> "
          "geen enkel lid meer heeft ingelogd, wordt ontbonden, volgens het bovenstaande tijdschema en met dezelfde "
          "doorwerkende gevolgen als de verwijdering van het account van een clanhoofd. De volwassenen van de clan worden "
          "vooraf gewaarschuwd: om de zes maanden een herinnering, tenzij zij de herinneringen hebben uitgeschakeld, en "
          "daarna een vooraankondiging <strong>één maand</strong> vóór de ontbinding, die hun in alle gevallen wordt "
          "toegestuurd. Eén enkele login van om het even welk lid van de clan volstaat om dat te voorkomen. Een clan met "
          "een lopend abonnement wordt nooit wegens inactiviteit ontbonden.</p>",
}

# --- Politique adulte : la puce « Clan inactif » -----------------------------------
PRIV_ADULT = {
    "fr": "<li><strong>Clan inactif</strong> : un clan sans abonnement en cours dont aucun membre ne s'est connecté depuis "
          "<strong>deux ans</strong> est dissous ; ses données suivent alors la règle du clan dissous ci-dessous. Les "
          "adultes du clan reçoivent un rappel tous les six mois, sauf s'ils ont désactivé les rappels, puis dans tous les "
          "cas un préavis un mois avant. Une seule connexion d'un membre suffit à l'annuler.</li>",
    "en": "<li><strong>Inactive clan</strong>: a clan with no current subscription none of whose members has signed in for "
          "<strong>two years</strong> is dissolved; its data then follows the rule for a dissolved clan below. The adults "
          "of the clan receive a reminder every six months, unless they have turned reminders off, then in every case a "
          "notice one month beforehand. A single sign-in by a member is enough to cancel it.</li>",
    "es": "<li><strong>Clan inactivo</strong>: un clan sin suscripción en curso del que ningún miembro se ha conectado desde "
          "hace <strong>dos años</strong> se disuelve; sus datos siguen entonces la regla del clan disuelto que figura más "
          "abajo. Los adultos del clan reciben un recordatorio cada seis meses, salvo si han desactivado los "
          "recordatorios, y en todos los casos un preaviso un mes antes. Basta una sola conexión de un miembro para "
          "anularlo.</li>",
    "de": "<li><strong>Inaktiver Clan</strong>: Ein Clan ohne laufendes Abonnement, von dem sich seit <strong>zwei "
          "Jahren</strong> kein Mitglied angemeldet hat, wird aufgelöst; seine Daten folgen dann der Regel für aufgelöste "
          "Clans weiter unten. Die Erwachsenen des Clans erhalten alle sechs Monate eine Erinnerung, sofern sie die "
          "Erinnerungen nicht deaktiviert haben, und in jedem Fall eine Vorankündigung einen Monat vorher. Eine einzige "
          "Anmeldung eines Mitglieds genügt, um sie aufzuheben.</li>",
    "it": "<li><strong>Clan inattivo</strong>: un clan senza abbonamento in corso di cui nessun membro si è connesso da "
          "<strong>due anni</strong> viene sciolto; i suoi dati seguono allora la regola del clan sciolto indicata sotto. "
          "Gli adulti del clan ricevono un promemoria ogni sei mesi, salvo che abbiano disattivato i promemoria, e in ogni "
          "caso un preavviso un mese prima. Basta un solo accesso di un membro per annullarlo.</li>",
    "pt": "<li><strong>Clã inativo</strong>: um clã sem subscrição em curso do qual nenhum membro se ligou há <strong>dois "
          "anos</strong> é dissolvido; os seus dados seguem então a regra do clã dissolvido indicada abaixo. Os adultos do "
          "clã recebem um lembrete a cada seis meses, salvo se tiverem desativado os lembretes, e em todos os casos um "
          "pré-aviso um mês antes. Basta uma única ligação de um membro para o anular.</li>",
    "br": "<li><strong>Clã inativo</strong>: um clã sem assinatura em andamento do qual nenhum membro se conectou há "
          "<strong>dois anos</strong> é dissolvido; seus dados seguem então a regra do clã dissolvido indicada abaixo. Os "
          "adultos do clã recebem um lembrete a cada seis meses, a menos que tenham desativado os lembretes, e em todos os "
          "casos um aviso prévio um mês antes. Basta uma única conexão de um membro para cancelá-lo.</li>",
    "nl": "<li><strong>Inactieve clan</strong>: een clan zonder lopend abonnement waarvan sinds <strong>twee jaar</strong> "
          "geen enkel lid meer heeft ingelogd, wordt ontbonden; zijn gegevens volgen dan de regel voor een ontbonden clan "
          "hieronder. De volwassenen van de clan krijgen om de zes maanden een herinnering, tenzij zij de herinneringen "
          "hebben uitgeschakeld, en in alle gevallen een vooraankondiging één maand vooraf. Eén enkele login van een lid "
          "volstaat om dat te annuleren.</li>",
}

# --- Politique enfant : le paragraphe, à hauteur d'enfant ---------------------------
# Deux interdits tenus : ne rien dire qui fasse peur (on dit que les adultes sont
# prévenus, et que l'enfant peut lui-même tout empêcher), et ne rien promettre de faux
# (« si personne ne paie l'abonnement » : un clan abonné n'est jamais effacé).
PRIV_KID = {
    "fr": "<p>Et si plus personne de ton clan n'ouvre le jeu pendant très, très longtemps ? Au bout de <strong>deux "
          "ans</strong> sans aucune visite, et si personne ne paie l'abonnement, le clan est effacé de la même façon. Mais "
          "les adultes sont prévenus plusieurs fois avant, et il suffit que quelqu'un du clan, toi compris, rouvre le jeu "
          "pour que rien ne se passe.</p>",
    "en": "<p>And what if nobody in your clan opens the game for a very, very long time? After <strong>two years</strong> "
          "without a single visit, and if nobody is paying for the subscription, the clan is erased in the same way. But "
          "the grown-ups are warned several times first, and all it takes is for someone in the clan, you included, to "
          "open the game again for nothing to happen.</p>",
    "es": "<p>¿Y si nadie de tu clan abre el juego durante muchísimo tiempo? Tras <strong>dos años</strong> sin ninguna "
          "visita, y si nadie paga la suscripción, el clan se borra de la misma manera. Pero los adultos reciben aviso "
          "varias veces antes, y basta con que alguien del clan, tú incluido, vuelva a abrir el juego para que no pase "
          "nada.</p>",
    "de": "<p>Und wenn niemand aus deinem Clan das Spiel sehr, sehr lange öffnet? Nach <strong>zwei Jahren</strong> ohne "
          "einen einzigen Besuch, und wenn niemand das Abonnement bezahlt, wird der Clan auf dieselbe Weise gelöscht. Aber "
          "die Erwachsenen werden vorher mehrmals gewarnt, und es reicht, wenn jemand aus dem Clan, du auch, das Spiel "
          "wieder öffnet, damit nichts passiert.</p>",
    "it": "<p>E se nessuno del tuo clan apre il gioco per tantissimo tempo? Dopo <strong>due anni</strong> senza nessuna "
          "visita, e se nessuno paga l'abbonamento, il clan viene cancellato allo stesso modo. Ma gli adulti vengono "
          "avvisati più volte prima, e basta che qualcuno del clan, anche tu, riapra il gioco perché non succeda "
          "niente.</p>",
    "pt": "<p>E se ninguém do teu clã abrir o jogo durante muito, muito tempo? Ao fim de <strong>dois anos</strong> sem "
          "nenhuma visita, e se ninguém pagar a subscrição, o clã é apagado da mesma maneira. Mas os adultos são avisados "
          "várias vezes antes, e basta que alguém do clã, tu incluído, volte a abrir o jogo para que nada aconteça.</p>",
    "br": "<p>E se ninguém do seu clã abrir o jogo por muito, muito tempo? Depois de <strong>dois anos</strong> sem nenhuma "
          "visita, e se ninguém pagar a assinatura, o clã é apagado do mesmo jeito. Mas os adultos são avisados várias "
          "vezes antes, e basta alguém do clã, você também, abrir o jogo de novo para que nada aconteça.</p>",
    "nl": "<p>En als niemand van je clan het spel heel, heel lang opent? Na <strong>twee jaar</strong> zonder één enkel "
          "bezoek, en als niemand het abonnement betaalt, wordt de clan op dezelfde manier gewist. Maar de volwassenen "
          "worden vooraf meerdere keren gewaarschuwd, en het is genoeg dat iemand van de clan, jij ook, het spel weer "
          "opent om ervoor te zorgen dat er niets gebeurt.</p>",
}


def _fail(msg):
    print("ECHEC : " + msg)
    sys.exit(1)


def _once(src, old, new, what, path):
    n = src.count(old)
    if n != 1:
        _fail(f"{path.name} : {what} — {n} occurrence(s) au lieu d'une.")
    return src.replace(old, new, 1)


def _section(src, num, path):
    """Bornes de la section `num` (du titre num au titre suivant)."""
    i = src.find(f"<h2>{num}.")
    j = src.find(f"<h2>{num + 1}.")
    if i < 0 or j <= i:
        _fail(f"{path.name} : section {num} introuvable.")
    return i, j


def do_cgu(src, lang, path):
    if "<strong>" + CGU_ART11[lang].split("<strong>")[1].split("</strong>")[0] + "</strong>" in src:
        _fail(f"{path.name} : déjà appliqué.")

    # Article 2 : la phrase, collée à la fin exacte de la puce réécrite la veille.
    tail = NOSUB[lang][-60:]
    src = _once(src, tail, tail[:-len("</li>")] + CGU_ART2[lang] + "</li>", "article 2", path)

    # Article 11 : avant son dernier paragraphe.
    i, j = _section(src, 11, path)
    last_p = src.rfind("<p>", i, j)
    if last_p < 0:
        _fail(f"{path.name} : article 11 sans paragraphe.")
    return src[:last_p] + CGU_ART11[lang] + "\n" + src[last_p:]


def do_priv_adult(src, lang, path):
    anchor = PRIVACY_NEW[lang]
    if src.count(anchor) != 1:
        _fail(f"{path.name} : puce du clan bloqué introuvable.")
    k = src.find("</li>", src.find(anchor))
    if PRIV_ADULT[lang][:40] in src:
        _fail(f"{path.name} : déjà appliqué.")
    return src[:k + 5] + "\n  " + PRIV_ADULT[lang] + src[k + 5:]


def do_priv_kid(src, lang, path):
    if PRIV_KID[lang][:40] in src:
        _fail(f"{path.name} : déjà appliqué.")
    # La section de suppression est celle qui renvoie à la page delete-account.
    k = src.find("donjons.grisloup.com/delete-account")
    if k < 0:
        _fail(f"{path.name} : section de suppression introuvable.")
    h_start = src.rfind("<h2>", 0, k)
    h_end = src.find("<h2>", k)
    ul_end = src.rfind("</ul>", h_start, h_end)
    if ul_end < 0:
        _fail(f"{path.name} : liste de la section de suppression introuvable.")
    return src[:ul_end + 5] + "\n" + PRIV_KID[lang] + src[ul_end + 5:]


def main():
    check = "--check" in sys.argv
    done = 0
    for path in sorted(DOCS.glob("*-v1.html")):
        parts = path.name.split("-")
        state, lang, kind = parts[1], parts[2], parts[3]
        if lang not in LANGS:
            continue
        if state == "a" and kind == "cgu":
            fn = do_cgu
        elif state == "a" and kind == "privacy":
            fn = do_priv_adult
        elif state == "k" and kind == "privacy":
            fn = do_priv_kid
        else:
            continue

        src = fn(path.read_text(encoding="utf-8"), lang, path)
        if check:
            print(f"  ok  {path.name}")
        else:
            for _ in range(6):
                try:
                    path.write_text(src, encoding="utf-8", newline="")
                    break
                except OSError:
                    time.sleep(0.3)
            else:
                _fail(f"{path.name} : écriture impossible.")
            print(f"  reecrit  {path.name}")
        done += 1

    print(f"\n{done} document(s) {'verifie(s)' if check else 'reecrit(s)'} en place.")


if __name__ == "__main__":
    main()
