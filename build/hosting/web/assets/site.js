/* Donjons & Savons — navigation, sélecteur de langue et pied de page communs.
   Chaque page contient : <nav id="site-nav"></nav>, <div id="lang-switch"></div>,
   <footer id="site-footer"></footer>. La langue et la section courantes sont
   déduites du chemin : /{lang}/{section}/ (slugs identiques dans les 3 langues). */

(function () {
  // ⚠ SEPT LOCALES DEPUIS LE 2026-09-08. L'ordre est celui de `langues` du
  //   build.yml : priorite, pas alphabet. Le selecteur de langue et le
  //   parcours d'URL lisent cette seule liste — ajouter un repertoire
  //   /xx/ sans l'ajouter ici le rend inatteignable.
  var LANGS = ["fr", "en", "es", "it", "de", "pt", "nl"];

  var NAV = {
    fr: [
      ["", "Accueil"],
      ["concept", "Concept"],
      ["roadmap", "Roadmap"],
      ["experience", "Expérience"],
      ["press", "Presse"],
      ["legal", "Légal"],
      ["betas", "Betas"]
    ],
    en: [
      ["", "Home"],
      ["concept", "Concept"],
      ["roadmap", "Roadmap"],
      ["experience", "Experience"],
      ["press", "Press"],
      ["legal", "Legal"],
      ["betas", "Betas"]
    ],
    es: [
      ["", "Inicio"],
      ["concept", "Concepto"],
      ["roadmap", "Hoja de ruta"],
      ["experience", "Experiencia"],
      ["press", "Prensa"],
      ["legal", "Legal"],
      ["betas", "Betas"]
    ],
    it: [
      ["", "Home"],
      ["concept", "Concetto"],
      ["roadmap", "Roadmap"],
      ["experience", "Esperienza"],
      ["press", "Stampa"],
      ["legal", "Legale"],
      ["betas", "Beta"]
    ],
    de: [
      ["", "Start"],
      ["concept", "Konzept"],
      ["roadmap", "Roadmap"],
      ["experience", "Erlebnis"],
      ["press", "Presse"],
      ["legal", "Rechtliches"],
      ["betas", "Betas"]
    ],
    pt: [
      ["", "Início"],
      ["concept", "Conceito"],
      ["roadmap", "Roteiro"],
      ["experience", "Experiência"],
      ["press", "Imprensa"],
      ["legal", "Legal"],
      ["betas", "Betas"]
    ],
    nl: [
      ["", "Home"],
      ["concept", "Concept"],
      ["roadmap", "Roadmap"],
      ["experience", "Ervaring"],
      ["press", "Pers"],
      ["legal", "Juridisch"],
      ["betas", "Beta's"]
    ]
  };

  var FOOTER = {
    fr: { legal: "Mentions légales & confidentialité", del: "Supprimer mon compte", contact: "Contact", cookies: "Cookie-free" },
    en: { legal: "Legal & privacy", del: "Delete my account", contact: "Contact", cookies: "Cookie-free" },
    es: { legal: "Avisos legales y privacidad", del: "Eliminar mi cuenta", contact: "Contacto", cookies: "Cookie-free" },
    it: { legal: "Note legali e privacy", del: "Elimina il mio account", contact: "Contatti", cookies: "Cookie-free" },
    de: { legal: "Rechtliches & Datenschutz", del: "Mein Konto löschen", contact: "Kontakt", cookies: "Cookie-free" },
    pt: { legal: "Avisos legais e privacidade", del: "Eliminar a minha conta", contact: "Contacto", cookies: "Cookie-free" },
    nl: { legal: "Juridisch & privacy", del: "Mijn account verwijderen", contact: "Contact", cookies: "Cookie-free" }
  };

  // Inscription à la liste d'attente des betas. Le bloc est injecté dans toute page
  // portant <div id="beta-signup"></div> (accueil, concept, roadmap des 3 langues).
  var BETA = {
    fr: {
      title: "Rejoindre les betas",
      lead: "Laissez votre adresse email : vous serez prévenu dès l'ouverture des prochaines betas.",
      ph: "votre@email.com",
      cta: "S'inscrire aux betas",
      ok: "Grisloup vous remercie de votre participation, vous serez informés très bientôt des prochaines dates des betas et l'avancement du projet. A très bientôt !",
      bad: "Cette adresse email ne semble pas valide.",
      err: "L'inscription n'a pas pu aboutir. Merci de réessayer dans un instant.",
      note: "Formulaire réservé aux adultes. Votre adresse ne sert qu'à vous informer des betas, et la liste est supprimée à la fin de celles-ci. Retrait sur simple demande à donjons@grisloup.com."
    },
    en: {
      title: "Join the betas",
      lead: "Leave your email address: you will be notified as soon as the next betas open.",
      ph: "your@email.com",
      cta: "Sign up for the betas",
      ok: "Grisloup thanks you for taking part. You will hear very soon about the next beta dates and the project's progress. See you very soon!",
      bad: "This email address does not look valid.",
      err: "The sign-up could not go through. Please try again in a moment.",
      note: "For adults only. Your address is only used to tell you about the betas, and the list is deleted once they are over. Removal on request at donjons@grisloup.com."
    },
    es: {
      title: "Únete a las betas",
      lead: "Deja tu dirección de correo: te avisaremos en cuanto se abran las próximas betas.",
      ph: "tu@email.com",
      cta: "Apuntarse a las betas",
      ok: "Grisloup le agradece su participación. Muy pronto recibirá noticias sobre las próximas fechas de las betas y el avance del proyecto. ¡Hasta muy pronto!",
      bad: "Esta dirección de correo no parece válida.",
      err: "No se ha podido completar la inscripción. Vuelve a intentarlo en un momento.",
      note: "Formulario reservado a adultos. Tu dirección solo sirve para informarte de las betas, y la lista se borra cuando estas terminan. Baja a petición en donjons@grisloup.com."
    },
    it: {
      title: "Unisciti alle beta",
      lead: "Lascia il tuo indirizzo email: sarai avvisato appena si apriranno le prossime beta.",
      ph: "tuo@email.com",
      cta: "Iscriviti alle beta",
      ok: "Grisloup ti ringrazia per la partecipazione. Riceverai molto presto notizie sulle prossime date delle beta e sull'avanzamento del progetto. A prestissimo!",
      bad: "Questo indirizzo email non sembra valido.",
      err: "L'iscrizione non è andata a buon fine. Riprova tra un istante.",
      note: "Modulo riservato agli adulti. Il tuo indirizzo serve solo a informarti delle beta, e l'elenco viene cancellato al termine di queste. Cancellazione su semplice richiesta a donjons@grisloup.com."
    },
    de: {
      title: "An den Betas teilnehmen",
      lead: "Hinterlassen Sie Ihre E-Mail-Adresse: Sie werden benachrichtigt, sobald die nächsten Betas öffnen.",
      ph: "ihre@email.com",
      cta: "Für die Betas anmelden",
      ok: "Grisloup dankt Ihnen für Ihre Teilnahme. Sie hören sehr bald von den nächsten Beta-Terminen und vom Fortschritt des Projekts. Bis ganz bald!",
      bad: "Diese E-Mail-Adresse sieht nicht gültig aus.",
      err: "Die Anmeldung konnte nicht abgeschlossen werden. Bitte versuchen Sie es gleich noch einmal.",
      note: "Formular nur für Erwachsene. Ihre Adresse dient ausschließlich dazu, Sie über die Betas zu informieren, und die Liste wird nach deren Ende gelöscht. Austragung auf einfache Anfrage an donjons@grisloup.com."
    },
    pt: {
      title: "Participar nas betas",
      lead: "Deixe o seu endereço de correio eletrónico: será avisado assim que abrirem as próximas betas.",
      ph: "o.seu@email.com",
      cta: "Inscrever-me nas betas",
      ok: "A Grisloup agradece a sua participação. Muito em breve receberá notícias sobre as próximas datas das betas e o avanço do projeto. Até muito breve!",
      bad: "Este endereço de correio eletrónico não parece válido.",
      err: "Não foi possível concluir a inscrição. Tente novamente dentro de instantes.",
      note: "Formulário reservado a adultos. O seu endereço serve apenas para o informar das betas, e a lista é apagada quando estas terminam. Remoção mediante simples pedido para donjons@grisloup.com."
    },
    nl: {
      title: "Meedoen aan de beta's",
      lead: "Laat uw e-mailadres achter: u wordt verwittigd zodra de volgende beta's opengaan.",
      ph: "uw@email.com",
      cta: "Inschrijven voor de beta's",
      ok: "Grisloup dankt u voor uw deelname. U hoort zeer binnenkort over de volgende betadata en de voortgang van het project. Tot heel binnenkort!",
      bad: "Dit e-mailadres lijkt niet geldig.",
      err: "De inschrijving kon niet worden voltooid. Probeer het zo dadelijk opnieuw.",
      note: "Formulier voorbehouden aan volwassenen. Uw adres dient alleen om u over de beta's te informeren, en de lijst wordt gewist zodra die voorbij zijn. Uitschrijven op eenvoudig verzoek via donjons@grisloup.com."
    }
  };

  // Variante « prochaines betas », posée par data-variant="next" : sur la page
  // /{lang}/betas/ la beta en cours est déjà lancée et pourvue, le formulaire n'y
  // recrute que pour les suivantes. Seuls titre, accroche et bouton changent —
  // la note garde l'engagement de suppression de la liste pris dans la privacy.
  var BETA_NEXT = {
    fr: {
      title: "Participer aux prochaines betas",
      lead: "Inscrivez-vous pour pouvoir participer aux prochaines betas !",
      cta: "M'inscrire"
    },
    en: {
      title: "Take part in the next betas",
      lead: "Sign up to take part in the next betas!",
      cta: "Sign me up"
    },
    es: {
      title: "Participar en las próximas betas",
      lead: "¡Apúntate para poder participar en las próximas betas!",
      cta: "Apuntarme"
    },
    it: {
      title: "Partecipa alle prossime beta",
      lead: "Iscriviti per poter partecipare alle prossime beta!",
      cta: "Iscrivimi"
    },
    de: {
      title: "An den nächsten Betas teilnehmen",
      lead: "Melden Sie sich an, um an den nächsten Betas teilnehmen zu können!",
      cta: "Anmelden"
    },
    pt: {
      title: "Participar nas próximas betas",
      lead: "Inscreva-se para poder participar nas próximas betas!",
      cta: "Inscrever-me"
    },
    nl: {
      title: "Deelnemen aan de volgende beta's",
      lead: "Schrijf u in om aan de volgende beta's te kunnen deelnemen!",
      cta: "Schrijf me in"
    }
  };

  // Glob NU, sans suffixe de région : puhosting le route vers la première région (eu).
  // Une seule table d'inscrits, donc. delete-account/ suffixe la sienne parce qu'il
  // cherche des données réparties par région — une seule aujourd'hui, mais il n'a pas
  // à le savoir : il lit @@@hosting_regions@@@ et interroge ce qu'on lui donne.
  var BETA_ENDPOINT = "/api/beta";
  var EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

  var segs = location.pathname.split("/").filter(Boolean);
  var lang = LANGS.indexOf(segs[0]) >= 0 ? segs[0] : "en";
  var section = segs.length > 1 ? segs[1] : "";

  // Navigation principale
  var nav = document.getElementById("site-nav");
  if (nav) {
    NAV[lang].forEach(function (item) {
      var a = document.createElement("a");
      a.href = "/" + lang + "/" + (item[0] ? item[0] + "/" : "");
      a.textContent = item[1];
      if (item[0] === section) a.className = "current";
      nav.appendChild(a);
    });
  }

  // Sélecteur de langue : même page dans l'autre langue (slugs identiques)
  var ls = document.getElementById("lang-switch");
  if (ls) {
    LANGS.forEach(function (l) {
      var el;
      if (l === lang) {
        el = document.createElement("span");
        el.className = "current";
      } else {
        el = document.createElement("a");
        var rest = segs.slice(1).join("/");
        el.href = "/" + l + "/" + (rest ? rest + "/" : "");
      }
      el.textContent = l.toUpperCase();
      ls.appendChild(el);
    });
  }

  // Pied de page
  var foot = document.getElementById("site-footer");
  if (foot) {
    var t = FOOTER[lang];
    foot.innerHTML =
      '<div class="wrap">' +
      '<span>© grisloup.com — Donjons &amp; Savons</span>' +
      '<a class="badge" href="/' + lang + '/legal/#cookies">' + t.cookies + "</a>" +
      '<a href="/' + lang + '/legal/">' + t.legal + "</a>" +
      '<a href="/delete-account/">' + t.del + "</a>" +
      '<a href="mailto:donjons@grisloup.com">' + t.contact + "</a>" +
      "</div>";
  }

  // Formulaire d'inscription aux betas
  var beta = document.getElementById("beta-signup");
  if (beta) {
    var b = BETA[lang];
    if (beta.getAttribute("data-variant") === "next") {
      var over = BETA_NEXT[lang], merged = {}, k;
      for (k in b) merged[k] = b[k];
      for (k in over) merged[k] = over[k];
      b = merged;
    }
    beta.className = "card beta";
    beta.innerHTML =
      "<h3>" + b.title + "</h3>" +
      "<p>" + b.lead + "</p>" +
      '<form novalidate>' +
      '<input type="email" name="email" required autocomplete="email" placeholder="' + b.ph + '">' +
      '<input class="hp" type="text" name="website" tabindex="-1" autocomplete="off" aria-hidden="true">' +
      '<button type="submit" class="btn">' + b.cta + "</button>" +
      "</form>" +
      '<p class="msg" hidden></p>' +
      '<p class="note muted">' + b.note + "</p>";

    var form = beta.querySelector("form");
    var msg = beta.querySelector(".msg");
    var note = beta.querySelector(".note");
    var input = form.querySelector('input[type="email"]');
    var hp = form.querySelector(".hp");
    var submit = form.querySelector("button");

    var fail = function (text) {
      msg.textContent = text;
      msg.className = "msg err";
      msg.hidden = false;
      submit.disabled = false;
    };

    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var email = input.value.trim();
      if (!EMAIL_RE.test(email)) { fail(b.bad); return; }

      submit.disabled = true;
      msg.hidden = true;

      // Enveloppe { data: ... } : format callable Firebase, comme /api/delete.
      fetch(BETA_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          data: { email: email, website: hp.value, lang: lang, source: section || "home" }
        })
      }).then(function (r) {
        return r.json().then(
          function (body) { return { ok: r.ok, body: body }; },
          function () { return { ok: r.ok, body: null }; }
        );
      }).then(function (res) {
        var status = res.body && res.body.error && res.body.error.status;
        if (!res.ok || status) {
          fail(status === "INVALID_ARGUMENT" ? b.bad : b.err);
          return;
        }
        // Succès : le formulaire laisse la place au remerciement, au même endroit.
        form.remove();
        note.remove();
        msg.textContent = b.ok;
        msg.className = "msg";
        msg.hidden = false;
      }).catch(function () { fail(b.err); });
    });
  }

  // Vidéos : discrètes au repos (taille d'une capture), agrandies pendant la
  // lecture. On ne réduit pas sur pause — seulement à la fin — pour ne pas
  // faire sauter la page sous les yeux du spectateur.
  var boxes = document.querySelectorAll(".videobox video");
  Array.prototype.forEach.call(boxes, function (video) {
    var box = video.parentNode;
    while (box && (!box.classList || !box.classList.contains("videobox"))) box = box.parentNode;
    if (!box) return;
    video.addEventListener("play", function () {
      box.classList.add("playing");
      // L'agrandissement pousse le bas de la vidéo vers le bas de la page : sur un
      // écran de portable, la fin de l'image passe sous la ligne de flottaison.
      // On la ramène au centre une fois la transition (.35s) terminée.
      if (box.scrollIntoView) {
        setTimeout(function () {
          box.scrollIntoView({ block: "center", behavior: "smooth" });
        }, 380);
      }
    });
    video.addEventListener("ended", function () { box.classList.remove("playing"); });
  });
})();
