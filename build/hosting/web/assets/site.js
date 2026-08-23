/* Donjons & Savons — navigation, sélecteur de langue et pied de page communs.
   Chaque page contient : <nav id="site-nav"></nav>, <div id="lang-switch"></div>,
   <footer id="site-footer"></footer>. La langue et la section courantes sont
   déduites du chemin : /{lang}/{section}/ (slugs identiques dans les 3 langues). */

(function () {
  var LANGS = ["fr", "en", "es"];

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
    ]
  };

  var FOOTER = {
    fr: { legal: "Mentions légales & confidentialité", del: "Supprimer mon compte", contact: "Contact", cookies: "Cookie-free" },
    en: { legal: "Legal & privacy", del: "Delete my account", contact: "Contact", cookies: "Cookie-free" },
    es: { legal: "Avisos legales y privacidad", del: "Eliminar mi cuenta", contact: "Contacto", cookies: "Cookie-free" }
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
    }
  };

  // Glob NU, sans suffixe de région : puhosting le route vers la première région (eu).
  // Une seule table d'inscrits, donc — ne pas imiter delete-account/, qui appelle
  // /api/delete/eu ET /api/delete/us parce qu'il cherche des données déjà réparties.
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
