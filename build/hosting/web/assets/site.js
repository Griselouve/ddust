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
      ["legal", "Légal"]
    ],
    en: [
      ["", "Home"],
      ["concept", "Concept"],
      ["roadmap", "Roadmap"],
      ["experience", "Experience"],
      ["press", "Press"],
      ["legal", "Legal"]
    ],
    es: [
      ["", "Inicio"],
      ["concept", "Concepto"],
      ["roadmap", "Hoja de ruta"],
      ["experience", "Experiencia"],
      ["press", "Prensa"],
      ["legal", "Legal"]
    ]
  };

  var FOOTER = {
    fr: { legal: "Mentions légales & confidentialité", del: "Supprimer mon compte", contact: "Contact", cookies: "Cookie-free" },
    en: { legal: "Legal & privacy", del: "Delete my account", contact: "Contact", cookies: "Cookie-free" },
    es: { legal: "Avisos legales y privacidad", del: "Eliminar mi cuenta", contact: "Contacto", cookies: "Cookie-free" }
  };

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

  // Vidéos : discrètes au repos (taille d'une capture), agrandies pendant la
  // lecture. On ne réduit pas sur pause — seulement à la fin — pour ne pas
  // faire sauter la page sous les yeux du spectateur.
  var boxes = document.querySelectorAll(".videobox video");
  Array.prototype.forEach.call(boxes, function (video) {
    var box = video.parentNode;
    while (box && (!box.classList || !box.classList.contains("videobox"))) box = box.parentNode;
    if (!box) return;
    video.addEventListener("play", function () { box.classList.add("playing"); });
    video.addEventListener("ended", function () { box.classList.remove("playing"); });
  });
})();
