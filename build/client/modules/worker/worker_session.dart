// -----------------------------------------------------------------------------
// --- This file is part of the DEVA framework
// --- Copyright (C) 2026 Griselouve - deva@grisloup.com
//
// This file is part of DEVA.
//
// DEVA is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// DEVA is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Dependencies
// -----------------------------------------------------------------------------

part of 'worker.dart';

// -----------------------------------------------------------------------------
// --- Globals shortcuts and miscellaneous
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- worker extension — Session & compte
// -----------------------------------------------------------------------------
extension Worker_session on worker {

    void _register_session() {

                                ActionRegistry.register("worker.on_login",                   on_login);

                                ActionRegistry.register("worker.on_logout",                  on_logout);

                                ActionRegistry.register("worker.do_reset",                   do_reset);

                                ActionRegistry.register("worker.do_count_sessions",          do_count_sessions);

                                ActionRegistry.register("worker.do_test_messaging",          do_test_messaging);

                                ActionRegistry.register("worker.on_test_silent",             on_test_silent);

                                ActionRegistry.register("worker.on_documents_ready",         on_documents_ready);

                                ActionRegistry.register("worker.on_acceptance_complete",     on_acceptance_complete);

                                ActionRegistry.register("worker.do_toggle_theme",             do_toggle_theme);

                                ActionRegistry.register("worker.on_consent_required_clan",  (c, e) async { if (e is Map) await on_consent_required_clan(c, e); });

                                ActionRegistry.register("worker.on_region_screen_done",     on_region_screen_done);

                                ActionRegistry.register("worker.legalstate",                legalstate);

                                // Suppression de compte (option kebab Personnage) : selector conditionnel
                                // (masquée en impersonation) + overlay d'avertissements répétés → delete_user_data.
                                ActionRegistry.register("worker.perso_settings_selector",   perso_settings_selector);
                                ActionRegistry.register("worker.death_settings_selector",   death_settings_selector);
                                ActionRegistry.register("worker.death_open_delete",         death_open_delete);

                                // Changement de langue (option kebab Personnage) : ouvre le picker
                                // drapeau+nom du module dvlang, ancré sous le bouton kebab.
                                ActionRegistry.register("worker.open_lang_menu",            open_lang_menu);

                                // Documents légaux (options kebab Personnage et menu de mort, bouton du
                                // profil) : consultables À TOUT MOMENT, DANS l'application, en lecture
                                // seule. Les stores et le droit exigent que l'utilisateur retrouve ce qu'il
                                // a accepté sans chercher sur un site : documents.view_doc sert la version
                                // acceptée, dans la langue, la région et l'état légal de sa session.
                                ActionRegistry.register("worker.open_privacy",              open_privacy);
                                ActionRegistry.register("worker.open_cgu",                  open_cgu);

                                ActionRegistry.register("worker.open_delete_account",       open_delete_account);

                                ActionRegistry.register("worker.on_delete_account_next",    on_delete_account_next);

                                ActionRegistry.register("worker.on_delete_account_cancel",  on_delete_account_cancel);

                                //-- Onboarding anonyme et liaison de compte -----------------------------
                                // Source unique de vérité du mode « rien en base » : lue par dvdocuments
                                // (documents.deferred.when_action) comme par les gardes d'écriture du worker.
                                ActionRegistry.register("worker.is_anonymous",              is_anonymous);

                                // cloud.auth.existing.verify_action — « Retrouver mon héros ».
                                ActionRegistry.register("worker.verify_account",            verify_account);

                                ActionRegistry.register("worker.on_account_rejected",       on_account_rejected);

                                ActionRegistry.register("worker.on_login_failed",           on_login_failed);

                                ActionRegistry.register("worker.on_rejected_close",         on_rejected_close);

                                ActionRegistry.register("worker.on_account_linked",         on_account_linked);

                                ActionRegistry.register("worker.on_link_failed",            on_link_failed);

                                ActionRegistry.register("worker.on_link_conflict",          on_link_conflict);

                                ActionRegistry.register("worker.on_link_conflict_confirm",  on_link_conflict_confirm);

                                ActionRegistry.register("worker.on_link_conflict_cancel",   on_link_conflict_cancel);

                                ActionRegistry.register("worker.on_link_account_appear",    on_link_account_appear);

                                // dvautover : le rappel (état du clan) et la reprise du démarrage.
                                ActionRegistry.register("worker.autover_state",             autover_state);

                                ActionRegistry.register("worker.autover_resume",            autover_resume);

    }

    Future<void> on_login(DvShape? caller, dynamic event) async {

                                final user = event is DvCloudUser ? event : null;
                                if (user == null) return;

                                // CHANGEMENT DE VERSION (snapshot → release, ou l'inverse) : le compte est
                                // resté connecté, mais on ne l'emmène pas tout de suite dans le jeu. Il
                                // revoit l'intro depuis l'accueil ; sa fin (on_intro_reveal) rejoue ce
                                // login au lieu d'ouvrir les deux portes.
                                // ⚠ SEULEMENT DEPUIS L'ACCUEIL, c'est-à-dire la reprise silencieuse du
                                //   démarrage. Un joueur qui se connecte lui-même depuis les deux portes a
                                //   déjà vu l'intro : le renvoyer au début le coincerait sur place.
                                final switched = !user.isAnonymous
                                    && (await ActionRegistry.get("dvcloud.region_switched")?.call(caller, null))?.toString() == "true";
                                final page = DvOrb.get_current_page()?.dvid?.toString();
                                if (switched && (page == null || page == "awake")) {
                                    _introReplay = true;
                                    deva_log("info", "[worker] changement de version : l'intro est rejouée avant d'entrer");
                                    return;
                                }

                                _userId = await _resolveUserId();
                                if (_userId.isEmpty) return;
                                // ⚠ UNE INVITATION EN ATTENTE QUE CE PROCESSUS N'A PAS VUE NAÎTRE EST UN
                                //   RESTE, JAMAIS UNE INVITATION. Les clefs `worker.pending_*` passent par
                                //   le dictionnaire, donc par le disque du compte : celle d'une version
                                //   antérieure (le chef y rangeait sa PROPRE invitation) ou d'une session
                                //   tuée resurgissait ici, et on_login la « consommait », clan ou pas.
                                //   Une vraie invitation reçue (QR, lien, code) arme _pendingInviteFresh
                                //   dans ce même processus. Le jeton sortant d'avant le correctif
                                //   (`worker.pending_invite_token`) part avec.
                                if (!_pendingInviteFresh) {
                                    await _clearPendingInvite();
                                    await deva_set("worker.pending_invite_token", "");
                                }
                                // Reste d'avant le 2026-09-22 : la déclaration scellée du chef vivait dans
                                // cette clef, donc sur son disque. Elle voyage désormais dans l'invitation
                                // privée de chaque lobby (workers/clans_invites) ; la clef n'a plus d'usage.
                                await deva_set("worker.pending_ack", "");
                                // Ancre l'identité authentifiée (doc `users/`). Toute divergence ultérieure
                                // = impersonation explicite (take_place). Un vrai login repart toujours net :
                                // on force le bandeau d'impersonation masqué (au cas où un store() l'aurait
                                // persisté pendant une session d'impersonation avant un kill).
                                _authUserId    = _userId;
                                _impersonating = false;
                                // AMORCE du miroir store, et pas seulement du champ Dart : `worker.impersonating`
                                // sert de garde aux étapes de la leçon dvtuto `impersonation_back`, et une clé
                                // JAMAIS écrite se lit `null` — qui ne vaut ni "true" ni "false". La leçon rejouée
                                // depuis l'écran Tutoriels par quelqu'un qui n'a jamais prêté son compte voyait
                                // alors TOUTES ses étapes sautées, donc une leçon vide. take_place / _impRestore
                                // le repassent à "true" juste après, restore_self à "false".
                                await deva_set("worker.impersonating", "false");
                                await _applyImpersonation(false, "");

                                final best = await _findBestSession();
                                // Session anonyme : la base est vide, TOUJOURS. Rien ne s'y écrit avant
                                // le login, pas plus pour le mineur que pour l'adulte (le mineur se
                                // connecte désormais avant d'entrer dans un clan), et la session anonyme
                                // elle-même ne survit plus à un kill (dvcloud la garde en mémoire). Il n'y
                                // a donc jamais rien à reprendre : au pire, on repart du seuil.
                                if (best == null && _anon) {
                                    // La session vient de s'ouvrir, à la seconde, parce que le joueur a
                                    // confirmé son royaume (on_region_screen_done). Il n'y a évidemment
                                    // rien en base : c'est le début du parcours, pas ses décombres.
                                    // _restartAnonymousOnboarding effacerait ici le royaume qu'on vient
                                    // de choisir et renverrait à l'accueil — une boucle dont on ne
                                    // sortirait jamais. On enchaîne donc simplement l'étape suivante.
                                    if (_onboardingLive) {
                                        _onboardingLive = false;
                                        await ActionRegistry.get("steps.navigate")?.call(caller, event);
                                        return;
                                    }
                                    await _restartAnonymousOnboarding();
                                    return;
                                }
                                // COMPTE DÉMÉNAGÉ DANS UNE RÉGION QUE CETTE APPLICATION NE CONNAÎT PAS
                                // (son clan est passé en beta, EUT, et l'app est une release qui ne
                                // connaît que la production). Sans ce garde, on repartait en onboarding
                                // et un compte neuf écrasait la pierre tombale : le joueur perdait son
                                // clan. dvautover affiche la mise à jour vers la bonne version.
                                if (best == null && !_anon) {
                                    final moved = await _movedElsewhere();
                                    if (moved.isNotEmpty) {
                                        await ActionRegistry.get("autover.moved")?.call(caller, {"region": moved});
                                        return;
                                    }
                                }
                                if (best != null) {
                                    final (sessionRegion, session) = best;
                                    _cloud?.configure("region", sessionRegion);
                                    // La session légale suit le compte : si son clan a déménagé, le
                                    // datacenter mémorisé par dvdocuments est celui d'AVANT, et la plupart
                                    // des écritures le relisent. Réaligné ici, localement (rien en base).
                                    await ActionRegistry.get("documents.relocate")?.call(caller, {"region": sessionRegion});
                                    // MISE À JOUR FORCÉE (dvautover), au point « région connue, rien
                                    // d'écrit » : la région des données est connue, et la première
                                    // écriture (_touchLastSeen) n'a pas encore eu lieu. Une application
                                    // plus ancienne que le `min` de ce backend s'arrête ici, sur l'écran
                                    // de mise à jour, sans avoir rien écrit.
                                    final blocked = await ActionRegistry.get("autover.check")?.call(caller, {"region": sessionRegion});
                                    if (blocked == true) return;
                                    // dvsession s'est hydraté à l'init des modules AVANT que la région soit
                                    // connue (premier lancement sur un nouveau device : auth Google et région
                                    // pas encore disponibles) → session.user.name etc. restaient vides. Maintenant
                                    // que la région est configurée, on relance l'hydratation : ses cloud.read()
                                    // ciblent désormais la bonne base régionale (eu-workers).
                                    final _sess = Deva.instance.module("dvsession");
                                    if (_sess != null) try { await (_sess as dynamic).invoke(); } catch (_) {}
                                    // Filet anti-résidu d'impersonation (même intention que le
                                    // _applyImpersonation(false,"") forcé plus haut) : take_place pose
                                    // session.user.{id,name} de la CIBLE, et deva_set/Deva.set persistent
                                    // TOUJOURS dans le layer runtime-<ownerId> de l'admin (l'ownerId ne
                                    // bascule pas) — un store() ultérieur les fige sur disque, et le layer
                                    // est réappliqué au boot AVANT toute lecture Firestore. On réancre donc
                                    // explicitement l'identité authentifiée depuis SON doc users/ (déjà lu
                                    // par _findBestSession), avant que _writeClanPlayer plus bas ne recopie
                                    // le nom dans clans_players.
                                    await Deva.instance.set("session.user.id", _authUserId);
                                    final realName = session.get("internal.name")?.toString() ?? "";
                                    if (realName.isNotEmpty) {
                                        await Deva.instance.set("session.user.name", realName);
                                    }
                                    // Date d'activité (users.last_seen), pour TOUT compte connecté, clan ou
                                    // pas : c'est elle qui dit au balayage serveur qu'un compte jamais admis
                                    // dans un clan est encore vivant. Avant tout le reste de la reprise, et
                                    // attendue : les écritures qui suivent relisent le document.
                                    if (!_anon) await _touchLastSeen(session, sessionRegion);
                                    // Activate Vertex AI now — cloud.aimodel_regions is available at this point
                                    final _ai = Deva.instance.module("dvvertexai");
                                    if (_ai != null) try { await (_ai as dynamic).startVertexMotor(); } catch (_) {}
                                    // ⚠ UN ÉCHEC ICI NE DOIT PAS TUER LE DÉMARRAGE. Une écriture refusée de
                                    //   la session légale levait jusqu'ici, et on_login s'arrêtait sans
                                    //   naviguer : le joueur restait sur l'accueil, déjà connecté, sans
                                    //   pouvoir rien toucher (relevé le 2026-09-26, après une migration).
                                    //   La session se resynchronise à la connexion suivante.
                                    try {
                                        await ActionRegistry.get("documents._sync_session")?.call(null, null);
                                    } catch (e) {
                                        deva_log("warning", "[worker] session légale non synchronisée : $e");
                                    }
                                    final dvdocs = ModuleRegistry.create("documents");
                                    final hasNew = dvdocs != null ? await (dvdocs as dynamic).hasNewDocuments() as bool? ?? false : false;
                                    if (hasNew) {
                                        ActionRegistry.get("documents.show_acceptance")?.call(null, "cgu");
                                        return;
                                    }
                                    final cguDone  = session.get("steps.cgu")  != null;
                                    // Enrôlé ⟺ un clanId courant non-vide. (Pas juste « steps.clan présent » : au
                                    // départ d'un clan, _leaveClanLocal vide clanId → routage vers decisiontree.)
                                    final clanDone = (session.get("steps.clan.clanId")?.toString() ?? "").isNotEmpty;
                                    if (DvOrb.get_current_page()?.dvid == "dashboard") return;
                                    if (clanDone) {
                                        await _enterClan(caller, event, session, sessionRegion);
                                        return;
                                    }
                                    if (!cguDone) {
                                        ActionRegistry.get("documents.show_acceptance")?.call(null, "cgu");
                                        return;
                                    }
                                    // cgu OK, pas encore de clan
                                    final legalState = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "";
                                    await Deva.instance.set("worker.session.create_clan_disabled",
                                        _gameplayLegal(legalState) == "k" ? "true" : "");
                                    // Filet : une session anonyme n'a plus rien en base (rien ne s'écrit
                                    // avant le login), ce cas ne devrait donc jamais se présenter. S'il se
                                    // présente, la seule issue sûre est la liaison du compte.
                                    // ⚠ LA BRANCHE « MINEUR ANONYME DÉJÀ INSCRIT » A DISPARU (2026-09-22) :
                                    //   elle renvoyait vers la demande d'entrée un enfant dont l'onboarding
                                    //   avait été écrit en base avant la décision de son parent. Le mineur se
                                    //   connecte désormais AVANT d'entrer dans un clan.
                                    if (_anon) {
                                        await _requireAccountLink();
                                        return;
                                    }
                                    // ADHÉSION EN ATTENTE (users.pending_join) : invitation acceptée lors
                                    // d'un lancement précédent, le chef n'avait pas encore publié le secret
                                    // du clan. Encore valable : retour sur join_wait, où l'attente reprend.
                                    // Expirée : vidée, et le joueur repart de sa demande (enfant) ou du
                                    // choix du clan (adulte), avec le message join_expired.
                                    // Une invitation FRAÎCHE (reçue par ce processus) passe devant : elle
                                    // est plus récente, et son acceptation remplacera l'attente.
                                    final pendingJoin = _pendingJoinOf(session);
                                    final freshInvite = ((await deva_get("worker.pending_group_id"))?.toString() ?? "").isNotEmpty
                                        || ((await deva_get("worker.pending_invite_token_in"))?.toString() ?? "").isNotEmpty;
                                    if (pendingJoin != null && !freshInvite) {
                                        if (_pendingJoinExpired(pendingJoin)) {
                                            deva_log("info", "[worker] on_login: adhésion en attente expirée");
                                            await _leaveJoin(sessionRegion, notice: "join_expired");
                                            return;
                                        }
                                        deva_log("info", "[worker] on_login: adhésion en attente, retour sur join_wait");
                                        // Déjà dessus (login rejoué) : ne pas reconstruire l'écran.
                                        if (DvOrb.get_current_page()?.dvid != "join_wait") {
                                            await ActionRegistry.get("steps.navigate.join_wait")?.call(caller, event);
                                        }
                                        return;
                                    }
                                    // Invitation gardée en mémoire avant le login : l'enfant qui vient de
                                    // se connecter (QR du parent scanné, ou code saisi), l'adulte qui a
                                    // ouvert un lien d'invitation application fermée. Acceptée ICI, sous le
                                    // compte définitif, puis attente du chef sur join_wait (_acceptAndWait) :
                                    // l'admission arrive quand il publie le secret du clan, application
                                    // ouverte ou non. Une invitation refusée (faite pour un enfant, ouverte
                                    // par un adulte) laisse la suite ordinaire reprendre ci-dessous.
                                    if (await _consumePendingInvite(caller, event)) return;
                                    if (session.get("steps.name") == null) {
                                        await ActionRegistry.get("steps.navigate.player_name")?.call(caller, event);
                                        return;
                                    }
                                    await ActionRegistry.get("steps.navigate.clan")?.call(caller, event);
                                    return;
                                }

                                final partial = await _findPartialSession();
                                if (partial != null) {
                                    final (partialRegion, partialSession) = partial;
                                    _cloud?.configure("region", partialRegion);
                                    // `partialRegion` vient du balayage des DATACENTERS : c'est un `eu`,
                                    // pas un royaume. On ne peut donc plus s'en servir de repli pour
                                    // rejouer le choix — un datacenter passé à on_region_selected serait
                                    // refusé par le bouton (région absente des options) et laisserait
                                    // l'écran d'âge sans royaume. Sans royaume enregistré, on renvoie au
                                    // choix : c'est le cas d'une session ouverte avant que royaume et
                                    // datacenter ne soient distingués.
                                    final regionValue = partialSession.get("steps.region_intro.result")?.toString() ?? "";
                                    if (regionValue.isEmpty) {
                                        await _enterOnboarding(caller, event);
                                        return;
                                    }
                                    await ActionRegistry.get("documents.on_region_selected")?.call(null, regionValue);
                                    // Royaume choisi, âge pas encore déclaré. Le nom ne se juge plus ici :
                                    // il est demandé après la liaison du compte, bien plus loin. Ce cas ne
                                    // concerne d'ailleurs plus qu'un compte AUTHENTIFIÉ qui refait son
                                    // onboarding (suppression puis retour) — un anonyme n'écrit rien et
                                    // repart de zéro, traité plus haut.
                                    await ActionRegistry.get("steps.navigate.age")?.call(caller, event);
                                    return;
                                }

                                // Aucune session active : soit vrai premier lancement, soit compte supprimé qui
                                // se reconnecte. Dans ce 2e cas on remet le doc users à plat avant l'onboarding.
                                await _resetDisabledSession();
                                await _enterOnboarding(caller, event);
    }

    // L'ENTRÉE DANS LE CLAN COURANT (`users.steps.clan`) : tout ce que fait un démarrage pour un
    // joueur déjà membre. Appelée par on_login (branche « a un clan ») et par la bascule d'un clan
    // à l'autre (_switchToClan, [fromSwitch] vrai) : une bascule EST un démarrage dans un autre
    // clan, l'état mémoire du précédent ayant été vidé juste avant (_resetClanState).
    Future<void> _enterClan(DvShape? caller, dynamic event, Dvidle session, String region,
                            {bool fromSwitch = false}) async {

                                // Démarre la musique de thème pour tout utilisateur déjà enrôlé qui (re)lance
                                // l'app — dashboard ou reprise de tâche. Un joueur mort voit son crâne dès la
                                // 1re frame (mutation registry persistée) : sa musique doit l'être aussi, d'où
                                // l'état de vie mémorisé (worker.player_dead) plutôt que `ambiant` en dur.
                                await _setAmbiance((await deva_get("worker.player_dead")) == true);
                                await _loadClanTasks(session, region);
                                // Enregistre ce device dans le doc membre clans_players (cible
                                // FCM) — idempotent : couvre le démarrage de l'app sur un nouveau
                                // device pour un joueur déjà membre.
                                await _writeClanPlayer(
                                    session.get("steps.clan.clanId")?.toString()     ?? "",
                                    session.get("steps.clan.clanSecret")?.toString() ?? "",
                                    _userId,
                                    await _cloud?.deviceId() ?? "",
                                    region,
                                    // Rétro-remplit original_clan (init-si-null) pour les membres d'avant
                                    // cette feature : miroir de users.first_clan (déjà backfillé en base).
                                    firstClan: session.get("first_clan")?.toString() ?? "",
                                );
                                // PROFIL PARTAGÉ (multiclan) : nom, avatar et titres recopiés sur la fiche
                                // de ce clan (ou nés d'elle, au premier passage).
                                await _profileSyncOnEntry(
                                    session.get("steps.clan.clanId")?.toString()     ?? "",
                                    session.get("steps.clan.clanSecret")?.toString() ?? "",
                                    region);
                                // Un événement interrompu (app tuée entre l'inscription de ses
                                // effets et leur application) reprend ici, sans doublon.
                                await _evtReplayPending(
                                    session.get("steps.clan.clanId")?.toString()     ?? "",
                                    session.get("steps.clan.clanSecret")?.toString() ?? "",
                                    region);
                                // Rattrapage des identités de substitution d'avant le correctif
                                // (external y valait internal). Sans await : le démarrage ne doit
                                // rien à une écriture de confort, et un échec se retentera au
                                // prochain login.
                                _backfillExternalIdentity(session, region);
                                // ENFANT REPRÉSENTÉ (multiclan) : les gestes de ses représentants
                                // (retrait d'un clan, consentement, majorité) sont appliqués sur toutes
                                // ses fiches AVANT le reste : c'est eux que les deux gardes suivantes
                                // lisent. Rend true si le clan courant vient d'être quitté.
                                if (await _gshipOnEnter()) return;
                                // Bascule légale en cours (tuteur a déclaré le joueur majeur) : le doc porte
                                // legal_state="t" → on impose la CGU adulte et on saute le dashboard. C'est ce
                                // qui « relance sur l'étape CGU » après un kill (routage re-dérivé à chaque login).
                                if (await _checkAdultTransition()) return;
                                // Retrait du consentement parental en cours sur CE joueur : la porte est
                                // close et le démarrage s'arrête ici. Indispensable EN PLUS de la vigilance
                                // temps réel, qui ne réagit qu'aux CHANGEMENTS du document : un enfant qui
                                // relance l'application le lendemain du retrait n'en verrait aucun.
                                // Placé après la bascule légale (un joueur devenu majeur n'est plus visé)
                                // et avant tout le reste — il n'a plus rien à faire dans le jeu.
                                if (await _checkConsentClosed(ensureScreen: true)) return;
                                // Filet : un membre de clan encore anonyme ne peut plus exister (le
                                // mineur se connecte AVANT d'entrer, et rien ne s'écrit sous un
                                // identifiant anonyme). S'il se présentait quand même, la liaison
                                // passe avant tout le reste.
                                if (_anon) { await _requireAccountLink(); return; }
                                // EMPRUNT DE COMPTE, repris AVANT la vigilance : celle-ci est keyée sur
                                // _userId, et l'armer sur l'adulte pour la rebasculer ensuite ferait un
                                // watch de trop sur le mauvais joueur. Rend true si _userId n'est plus
                                // l'utilisateur authentifié — le reste du démarrage suit alors le point de
                                // vue de l'enfant, ce qui est exactement l'effet recherché.
                                // C'est aussi ici que le verrouillage échu rend la main : _impRestore
                                // refuse de reprendre et efface, l'adulte redémarre chez lui.
                                await _impRestore(
                                    session.get("steps.clan.clanId")?.toString()     ?? "",
                                    session.get("steps.clan.clanSecret")?.toString() ?? "",
                                    region,
                                );

                                // Arme la vigilance temps réel du doc joueur dès la reprise à froid (avant
                                // même le dashboard) : la montée de niveau sera détectée où que soit le joueur.
                                _startPlayerVigilance(
                                    session.get("steps.clan.clanId")?.toString()     ?? "",
                                    session.get("steps.clan.clanSecret")?.toString() ?? "",
                                    region,
                                );
                                // Et on regarde tout de suite si le clan attendait ce joueur : la cérémonie
                                // a pu être appelée pendant que l'app était fermée, et rien n'émet de
                                // changement pour ce qui était déjà là avant l'abonnement.
                                _checkPendingCeremony();   // fire-and-forget : le démarrage n'attend personne
                                // Invitations acceptées pendant que le jeu du chef était fermé : le
                                // secret du clan est publié maintenant (chef seulement, cf.
                                // _resumeInvites). Sans navigation : un clan plein ne détourne pas le
                                // démarrage, la page des paliers attendra l'écran du clan.
                                _resumeInvites(navigate: false);   // fire-and-forget
                                // REPRÉSENTANT : un retrait du consentement dont l'échéance est passée
                                // est exécuté par le serveur, que l'app de l'enfant ait tourné ou non.
                                _sweepGuardianConsents();          // fire-and-forget
                                // Restaure le contexte de la tâche en cours dans la session locale, sans
                                // rediriger vers combat : on démarre toujours sur le dashboard. L'écran
                                // combat (on_combat_appear) lira session.active_task quand l'utilisateur
                                // l'ouvrira via la taskbar.
                                // MULTICLAN : la tâche active (« <clanId>_<tâche> ») peut appartenir à un
                                // autre clan que le courant ; elle n'est alors pas restaurée ici.
                                final activeTask = session.get("active_task")?.toString() ?? "";
                                final activeClan = session.get("steps.clan.clanId")?.toString() ?? "";
                                if (activeTask.isNotEmpty && activeClan.isNotEmpty && activeTask.startsWith("${activeClan}_")) {
                                    final clanId = activeClan;
                                    if (clanId.isNotEmpty) await Deva.instance.set("session.clan.id", clanId);
                                    await Deva.instance.set("session.active_task", activeTask);
                                    // Tâche en attente de validation au redémarrage (preuve déposée) → on
                                    // relance la vigilance : le watch en mémoire a été perdu au kill.
                                    final activeProof = session.get("active_proof")?.toString() ?? "";
                                    final clanSecret  = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (activeProof.isNotEmpty && clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                        await Deva.instance.set("session.active_proof", activeProof);
                                        _startValidationPolling(clanId, clanSecret, region,
                                            _taskIdFromActive(activeTask, clanId));
                                    }
                                }
                                // Réconciliation des photos de preuve — HORS du bloc ci-dessus, et c'est
                                // tout l'intérêt : le cas à rattraper est justement celui où il n'y a plus
                                // de tâche active. La preuve vit sur l'appareil du joueur alors que le
                                // verdict est écrit par l'appareil qui tranche : un effacement « au
                                // verdict » ne l'atteint pas quand l'admin décide à distance. Ici, la
                                // session fait autorité — tout fichier qui n'est pas active_proof est un
                                // orphelin. Fire-and-forget : le démarrage n'attend pas des accès disque.
                                _reconcileProofs(session.get("active_proof")?.toString() ?? "");
                                // Lien d'invitation reçu avant l'authentification (cold start).
                                if (!fromSwitch && await _consumePendingInvite(caller, event, hasClan: true,
                                        ownClanId: session.get("steps.clan.clanId")?.toString() ?? "")) return;
                                // Nom pas encore choisi : il est demandé APRÈS la liaison du compte,
                                // pour tout le monde. Placé ici, tout en fin de branche, pour que la
                                // vigilance du joueur et les cérémonies en attente soient déjà armées
                                // quand on détourne vers l'écran de nom. C'est aussi ce passage qui
                                // libère l'annonce d'arrivée dans le clan (cf. _flushPendingMemberJoined).
                                if (session.get("steps.name") == null) {
                                    await ActionRegistry.get("steps.navigate.player_name")?.call(caller, event);
                                    return;
                                }
                                // ADHÉSION À UN AUTRE CLAN EN ATTENTE (multiclan) : le joueur a déjà un
                                // clan, et une invitation acceptée attend que son chef publie le secret.
                                // Même règle que la branche sans clan : retour sur join_wait.
                                final pendingJoin = _pendingJoinOf(session);
                                if (pendingJoin != null && !fromSwitch) {
                                    if (_pendingJoinExpired(pendingJoin)) {
                                        await _leaveJoin(region, notice: "join_expired");
                                    } else if (DvOrb.get_current_page()?.dvid != "join_wait") {
                                        DvOrb.navigate_reset("join_wait");
                                        return;
                                    }
                                }
                                if (fromSwitch) {
                                    DvOrb.navigate_reset("dashboard");
                                    return;
                                }
                                await ActionRegistry.get("steps.navigate.dashboard")?.call(caller, event);
                                // Accord d'enfant reçu par lien, application fermée (on_assent_link) :
                                // le chef est maintenant connecté, sa déclaration peut s'ouvrir.
                                await _openPendingAssent();
                                return;
    }

    // Entrée dans l'onboarding. Le premier écran est le ROYAUME — toujours, pour
    // ddust : depuis le 2026-09-12 dvdocuments ne déduit plus jamais la région, et
    // seule une application qui coupe la question (`region.enabled: false`, que
    // ddust n'utilise pas) obtiendrait autre chose. La branche « âge » ci-dessous
    // n'est donc plus empruntée ici, et c'est très bien qu'elle reste : le worker
    // ne doit pas présumer de la conf d'une app qui réutiliserait ce code.
    //
    // ⚠ LA DÉCISION APPARTIENT AU MODULE, pas au worker. Elle dépend de la conf
    //   des régions ouvertes et de leurs datacenters — la recopier ici la ferait
    //   diverger à la première ouverture de marché. Le worker se contente de
    //   traduire la réponse en navigation, ce que le module ne sait pas faire.
    Future<void> _enterOnboarding(DvShape? caller, dynamic event) async {

                                final verdict = await ActionRegistry
                                    .get("documents.needs_region_choice")?.call(null, null);
                                final step = (verdict?.toString() == "false")
                                    ? "steps.navigate.age"
                                    : "steps.navigate.region";
                                await ActionRegistry.get(step)?.call(caller, event);
    }

    Future<void> on_documents_ready(DvShape? caller, dynamic event) async {

                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                _cloud?.configure("region", region);
                                // ON N'ÉCRIT RIEN, ET PAS SEULEMENT QUAND LA SESSION EST ANONYME.
                                // L'index, les steps et l'enregistrement du device partent d'un seul
                                // bloc au flush (_flushOnboarding), une fois les conditions acceptées.
                                //
                                // ⚠ CETTE ÉTAPE ÉCRIVAIT, pour un compte déjà authentifié qui refaisait
                                //   son onboarding : `userindexes`, puis les steps `region` et
                                //   `legal_state`. Trois allers-retours réseau AVANT que quiconque ait
                                //   accepté quoi que ce soit, et autant d'occasions de laisser en base
                                //   un compte à moitié constitué. Or un compte à moitié constitué est
                                //   pire qu'un compte absent : absent, on recommence de zéro ; à
                                //   moitié là, la reprise le prend pour un parcours en cours et
                                //   aiguille sur un état qui n'existe pas vraiment.
                                //
                                // L'abonnement FCM global, lui, reste : ce n'est pas une donnée
                                // inscrite au nom de quelqu'un, c'est un canal, et il est refait à
                                // l'identique au flush.
                                if (!_anon && region.isNotEmpty) {
                                    await _messaging?.msgregister('global');
                                }
                                await ActionRegistry.get("steps.navigate")?.call(caller, event);
    }

    Future<void> on_acceptance_complete(DvShape? caller, dynamic event) async {

                                // Bascule légale (mineur → adulte) : la CGU ADULTE vient d'être acceptée par le
                                // joueur lui-même. On commit "a" partout (users + clans_players + session) puis on
                                // rejoint le dashboard. Traité en tête, avant les autres flux d'acceptation.
                                final pendingAdult = (await Deva.instance.get("worker.pending_adult_transition"))?.toString() ?? "";
                                if (pendingAdult == "true") {
                                    await Deva.instance.set("worker.pending_adult_transition", null);
                                    await Deva.instance.store();
                                    final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    if (region.isNotEmpty) {
                                        // users : steps.legal_state = "a" (+ date/status via _writeStep).
                                        await _writeStep(region, "legal_state", "a");
                                        // clans_players : legal_state = "a" (deep-merge) → stoppe la boucle CGU et
                                        // rend le joueur adulte en jeu (protection mineur levée, création de clan, …).
                                        final session    = await _readSession(region);
                                        final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                        final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                        if (clanId.isNotEmpty && clanSecret.isNotEmpty && _userId.isNotEmpty) {
                                            final pdoc = Dvidle({});
                                            pdoc.set("id", _userId);
                                            pdoc.set("legal_state", "a");
                                            await _cloud?.write("workers", "clans_players/$clanId/players", _userId, pdoc,
                                                region: region, ownerId: clanSecret);
                                            // Le cache de _ensureIsAdult vient d'être démenti par cette écriture :
                                            // il porte encore le "t" lu au login. Sans cette invalidation, un
                                            // nouvel adulte déjà chef resterait privé de la boutique jusqu'au
                                            // prochain démarrage — la garde ne doit pas survivre à sa raison d'être.
                                            _isAdultClanId = "";
                                        }
                                        // MULTICLAN : `a` sur TOUTES ses fiches et la représentation se
                                        // ferme, seulement si un représentant a déclaré la majorité.
                                        await _gshipMajorityDone(region);
                                    }
                                    // Commit définitif de l'état légal de session (mémoire + clé deva gameplay +
                                    // documents_sessions) → ré-hydraté "a" aux prochains logins.
                                    await ActionRegistry.get("documents.persist_session_legalstate")?.call(null, "a");
                                    // Le joueur redevient un joueur normal : on (ré)arme sa vigilance et on rejoint
                                    // le dashboard.
                                    await _ensurePlayerVigilance();
                                    // Nav directe : la page courante (documents_acceptance_screen) a un routeur
                                    // worker.legalstate qui ignorerait l'arg "dashboard" et routerait vers
                                    // new_or_pick_clan (état "a"). On contourne comme les autres flux (on_join_clan…).
                                    DvOrb.navigate_reset("dashboard");
                                    return;
                                }

                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                // LE PREMIER MOMENT OÙ L'ON ÉCRIT, et c'est le bon : les conditions
                                // viennent d'être acceptées. Tout ce qui précède — royaume, âge, état
                                // légal — n'a vécu jusqu'ici que dans la session locale.
                                //
                                // Anonyme : rien encore. Son flush viendra à la liaison du compte,
                                // pour l'adulte comme pour le mineur (qui ne se connecte qu'une fois
                                // l'invitation de son parent en main), parce qu'il n'a pas encore
                                // d'identité durable à qui rattacher tout cela.
                                //
                                // Déjà authentifié — un compte Google dont la session en base a
                                // disparu, et qui refait donc tout le parcours : le bloc part
                                // MAINTENANT et EN UNE FOIS, au lieu des trois écritures égrenées
                                // d'écran en écran qu'on faisait avant. `proofAlreadyWritten` parce
                                // que dvdocuments, hors mode différé, vient d'inscrire la preuve
                                // lui-même : le flush n'a donc rien à rejouer de ce côté.
                                // (La bascule légale mineur → adulte, elle, est sortie plus haut :
                                // elle ne passe jamais par ici.)
                                //
                                // Vertex attend aussi le compte lié : dvcloud refuse volontairement de
                                // charger les secrets pour une session anonyme.
                                if (!_anon) {
                                    if (region.isNotEmpty) await _flushOnboarding(proofAlreadyWritten: true);
                                    final _ai = Deva.instance.module("dvvertexai");
                                    if (_ai != null) try { await (_ai as dynamic).startVertexMotor(); } catch (_) {}
                                }
                                final legalState = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "";
                                await Deva.instance.set("worker.session.create_clan_disabled", _gameplayLegal(legalState) == "k" ? "true" : "");

                                // LE PACTE — quatre secondes de célébration avant la liaison du
                                // compte. C'est le seul endroit du tunnel où l'on célèbre, et il
                                // est choisi : on vient de faire lire des conditions générales, et
                                // ce qui suit est un bouton « se connecter ». Sans rien entre les
                                // deux, le jeu n'aurait été, depuis l'interlude, qu'une suite de
                                // formalités.
                                //
                                // ⚠ RÉSERVÉ À L'ADULTE ANONYME EN COURS D'INSCRIPTION, et les deux
                                //   conditions comptent. Cet écran n'est PAS réservé à l'onboarding :
                                //   toute nouvelle version de document le repose à un joueur de
                                //   longue date, à qui « c'est parti, connecte-toi » ne voudrait
                                //   rien dire — il est connecté depuis des mois. Et un mineur part
                                //   vers l'avis de l'enfant, pas vers une liaison de compte : la
                                //   même réplique l'enverrait appuyer sur un bouton qui n'existe
                                //   pas pour lui.
                                //
                                // ⚠ LA NAVIGATION PART DE `on_pacte_finished`, d'où le `return` : la
                                //   jouer ici ferait défiler l'écran suivant sous la scène.
                                if (_anon && _gameplayLegal(legalState) == "a") {
                                    final play = ActionRegistry.get("dvinterlude.play.pacte");
                                    if (play != null) {
                                        await play(null, null);
                                        return;
                                    }
                                    // dvinterlude absent du build : on n'ampute personne de son
                                    // inscription pour une animation.
                                    deva_log("warning", "[pacte] dvinterlude absent : célébration sautée");
                                }
                                await ActionRegistry.get("steps.navigate")?.call(caller, event);
    }

    Future<void> on_region_screen_done(DvShape? caller, dynamic event) async {

                                // L'event porte le ROYAUME que le joueur vient de choisir, pas le
                                // datacenter. Les deux se confondaient du temps où la « région »
                                // désignait le datacenter ; ils sont désormais tenus séparés — le
                                // premier s'enregistre, le second route — et un seul royaume ouvert
                                // aujourd'hui ne rend pas la distinction facultative demain.
                                // dvdocuments a déjà persisté les deux (persistRegionEarly) avant
                                // de déclencher cette action.
                                final market = (event?.toString()?.isNotEmpty == true)
                                    ? event.toString()
                                    : (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                if (market.isEmpty || region.isEmpty) return;

                                // PREMIER CONTACT RÉSEAU DE TOUT L'ONBOARDING. Jusqu'ici — accueil,
                                // interlude, catalogue des royaumes — l'application n'a parlé à
                                // personne : tout venait du paquet. La session anonyme s'ouvre donc
                                // ICI, au premier instant où elle sert réellement à quelque chose, et
                                // non au tap d'accueil comme avant. C'est ce qui rend l'arrivée jouable
                                // hors ligne, et c'est aussi ce qui fait qu'un échec de connexion est
                                // signalé APRÈS que le joueur a vu le jeu, et non à sa place.
                                //
                                // Le royaume, lui, est déjà persisté localement (persistRegionEarly) :
                                // s'il n'y a pas de réseau, on n'a rien perdu — le choix sera rejoué
                                // tel quel au retour.
                                if (_cloud?.currentUser() == null) {
                                    _onboardingLive = true;
                                    await ActionRegistry.get("dvcloud.do_start_anonymous")?.call(caller, null);
                                    return;   // la suite du parcours part de on_login
                                }
                                // RIEN N'EST ÉCRIT ICI, POUR PERSONNE. Le royaume vit dans
                                // documents.session.region et sera inscrit au flush, avec le reste.
                                // Il l'était autrefois pour un compte déjà authentifié — et c'est
                                // exactement ce qui rendait certains états irrattrapables : un
                                // incident réseau deux écrans plus loin laissait un `users` portant
                                // un royaume mais pas de conditions acceptées, que la reprise
                                // suivante relisait comme un onboarding légitimement commencé.
                                await ActionRegistry.get("steps.navigate")?.call(caller, event);
    }

    // Routeur de documents_acceptance_screen.
    //
    // Cet écran n'est PAS réservé à l'onboarding : toute nouvelle version de document le
    // repose à TOUT LE MONDE au lancement suivant (on_login → hasNewDocuments →
    // show_acceptance). Un joueur déjà enrôlé doit alors revenir à son dashboard — sans cette
    // première branche, un mineur repartait sur kid_wants_clan (route "k") et un adulte se
    // revoyait demander son nom (route "a_linked") à chaque révision des CGU.
    // Le critère est l'enrôlement PERSISTÉ (`steps.clan.clanId`), le même qu'on_login, et non
    // un drapeau de session. Lecture en échec → on retombe sur le routage d'onboarding, qui
    // reste correct pour qui n'a pas encore de clan.
    //
    // Ensuite seulement, le routage d'onboarding, à trois issues et non deux : un adulte
    // ENCORE ANONYME doit lier son compte Google avant d'aller plus loin (route "a"), tandis
    // qu'un adulte déjà authentifié — typiquement un compte supprimé qui refait son
    // onboarding — n'a rien à lier et enchaîne directement (route "a_linked").
    Future<String> legalstate(DvShape? caller, dynamic event) async {

                                try {
                                    final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    if (region.isNotEmpty) {
                                        final session = await _readSession(region);
                                        final clanId  = session?.get("steps.clan.clanId")?.toString() ?? "";
                                        if (clanId.isNotEmpty) {
                                            // Enrôlé mais sans nom : cas d'un mineur admis dont la saisie a été
                                            // interrompue. On le renvoie la finir plutôt qu'au dashboard.
                                            return session?.get("steps.name") == null ? "player_name" : "dashboard";
                                        }
                                        // Adhésion en attente (nouvelle version des conditions reposée pendant
                                        // l'attente) : retour sur join_wait, pas au début du parcours de jointure.
                                        final pj = _pendingJoinOf(session);
                                        if (pj != null && !_pendingJoinExpired(pj)) return "join_wait";
                                    }
                                } catch (e) {
                                    deva_log("error", "[worker] legalstate: lecture session FAILED: $e");
                                }

                                final raw = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "k";
                                final ls  = _gameplayLegal(raw);
                                if (ls == "a" && !_anon) return "a_linked";
                                return ls;
    }

    Future<void> on_consent_required_clan(DvShape? caller, Map event) async {

                                final groupId = event["group_id"]?.toString() ?? "";
                                final lobbyId = event["lobby_id"]?.toString() ?? "";
                                if (groupId.isEmpty || lobbyId.isEmpty) return;
                                // Plus de document consent_clan : le consentement (parental compris) est
                                // couvert par la CGU unique acceptée au signup. On reprend le workflow
                                // directement pour transmettre le clanSecret au candidat.
                                ActionRegistry.get("virtuallobby.continue_workflow")?.call(null, {
                                    "group_id": groupId,
                                    "lobby_id": lobbyId,
                                });
    }

    Future<void> on_logout(DvShape? caller, dynamic event) async {

                                deva_log("info","logged out");
                                // État du clan courant (partagé avec la bascule d'un clan à l'autre).
                                await _resetClanState();
                                _stopGshipVigilance();
                                _stopDropWatch();
                                // L'attente d'une adhésion (join_wait) appartient au compte qui s'en va :
                                // elle reste en base (pending_join) et reprendra à sa prochaine connexion.
                                _stopJoinWatch();
                                _joinPendingMem  = null;
                                _joinNotice      = "";
                                _lastSeenDay     = "";
                                _userId      = "";
                                _authUserId  = "";
                                _impersonating = false;
                                // (Rôles, mode chef, vocabulaire du tiroir, clan_done : _resetClanState, plus
                                // haut. Un compte réouvert sur le même appareil n'hérite de rien.)
                                // Copie locale de la représentation (filtre des notifications) : elle
                                // appartient au compte qui s'en va.
                                await deva_set("worker.gship_blocked", "");
                                await deva_set("worker.gship_withdrawn", "false");
                                // Demande d'enfant et invitations en cours, des deux côtés : le code de la
                                // demande, l'accord scanné par le chef, l'invitation mise de côté. Rien de
                                // cela n'appartient au compte suivant.
                                await _forgetKidAssent();
                                _pendingAssent    = null;
                                _pendingClaimId   = "";
                                _pendingClaimName = "";
                                _claimRows        = [];
                                _inviteAsChief    = false;
                                // Passage à l'âge adulte : la célébration appartient au compte qui la vivait.
                                _adulthoodPlaying    = false;
                                _adulthoodCelebrated = false;
                                _inviteAssent     = null;
                                _assentRejected   = false;
                                _inviteLinkParams = "";
                                _outgoingGroupId  = "";
                                _outgoingLobbyId  = "";
                                _outgoingRegion   = "";
                                _outgoingPinToken = "";

                                // ⚠ AU SEUIL, ET NON SUR `home`. Se deconnecter, c'est revenir au
                                //   tout debut : l'ecran noir qui demande « le donjon vous attend,
                                //   etes-vous pret ? ». `home` est l'ecran des deux portes, qui
                                //   vient APRES le seuil, le choix de la langue et l'interlude :
                                //   y atterrir directement donne l'impression d'une application
                                //   qui a perdu le fil.
                                //
                                //   C'etait un arbitrage du 2026-09-13, pris pour eviter de
                                //   reimposer trente secondes d'accueil a quelqu'un qui veut
                                //   seulement changer de compte. L'accueil ne se rejoue pas pour
                                //   autant : le seuil attend un tap, et la porte « retrouver mon
                                //   heros » est a deux ecrans.
                                //
                                // ⚠ ET IL FAUT REARMER LE SEUIL. Ses deux gardes sont des drapeaux
                                //   de session : `_awakeCycling` empeche deux boucles de phrases
                                //   de se superposer, `_seuilMusique` empeche deux musiques. Tous
                                //   deux restent leves apres un premier passage — sans cette
                                //   remise a zero, on revient sur un ecran noir, muet et sans
                                //   musique, exactement ce qui a ete observe.
                                _awakeCycling  = false;
                                _seuilMusique  = false;
                                if (DvOrb.get_current_page()?.dvid != "awake") {
                                    DvOrb.navigate_reset("awake");
                                }
    }

    //-----------------------------------------------------------------------
    //-- Onboarding anonyme et liaison du compte Google ---------------------
    //-----------------------------------------------------------------------
    //
    // Le joueur traverse tout l'onboarding — royaume, âge, vidéo, CGU — en session
    // Firebase ANONYME, sans qu'une seule ligne ne soit écrite en base. Firebase Auth
    // ne détient donc ni email, ni nom, ni photo avant que les conditions soient
    // acceptées et l'état légal connu. Le compte Google est lié en fin de parcours :
    // linkWithCredential conserve le même uid, il n'y a rien à migrer.
    //
    // Une session anonyme interrompue ne laisse RIEN — ni entrée Auth exploitable
    // (autodelete 30 jours), ni document Firestore. C'est le corollaire assumé :
    // aucune reprise avant le flush, on recommence l'onboarding depuis le début.

    bool get _anon => _cloud?.currentUser()?.isAnonymous == true;

    Future<String> is_anonymous(DvShape? caller, dynamic event) async => _anon ? "true" : "";

    // Révèle une forme d'overlay en lui posant un libellé traduit.
    Future<void> _revealLabel(String shapeId, String translationKey) async {

                                final s = DvOrb.get_shape_by_id(shapeId);
                                if (s == null) return;
                                s.set("shape.label", TranslationRegistry.processLabel("@@@T:$translationKey@@@"));
                                if (s is DvLabel) await s.computeDisplay();
                                s..set("shape.visible", true)..refreshUI();
    }

    void _hideShapes(List<String> ids) {

                                for (final id in ids) {
                                    DvOrb.get_shape_by_id(id)?..set("shape.visible", false)..refreshUI();
                                }
    }

    //-- « Retrouver mon héros » : vérification avant toute écriture ---------

    Future<String> verify_account(DvShape? caller, dynamic event) async => await _lookupUserIndex();

    // Rend 'ok' | 'not_found' | 'error'. Volontairement SÉPARÉE de _resolveUserId, dont
    // le catch(_) muet rend une région injoignable indiscernable d'un compte absent :
    // sans conséquence là-bas (au pire un uuid de trop), inacceptable ici où 'not_found'
    // déclenche la suppression de l'entrée Firebase Auth. Un seul échec de lecture suffit
    // donc à basculer en 'error', qui ne supprime jamais rien.
    //
    // userindexes est le seul critère praticable : `users` est en `allow list: if false`
    // et son docId est inconnu sans l'index. Conséquence assumée — un compte historique
    // interrompu avant la création de son index sera refusé et repartira par « Je pars à
    // l'aventure ». Un compte en suppression logique, lui, a bien son index : il est
    // accepté, et réactivé par la première écriture.
    Future<String> _lookupUserIndex() async {

                                final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                if (firebaseUid.isEmpty) return "error";
                                final regionsData = await deva_get("regions");
                                final regionKeys  = regionsData is Dvidle ? regionsData.keys : <String>[];
                                if (regionKeys.isEmpty) return "error";

                                bool unreachable = false;
                                for (final key in regionKeys) {
                                    final region = key.toLowerCase();
                                    try {
                                        final index    = await _cloud?.read("workers", "userindexes", firebaseUid, region: region);
                                        final existing = index?.get("userId")?.toString() ?? "";
                                        if (existing.isNotEmpty) {
                                            deva_log("info", "[worker] verify_account: compte reconnu en région '$region'");
                                            return "ok";
                                        }
                                    } catch (e) {
                                        deva_log("warning", "[worker] verify_account: région '$region' illisible ($e)");
                                        unreachable = true;
                                    }
                                }
                                return unreachable ? "error" : "not_found";
    }

    // Overlay d'explication de l'écran d'accueil. Ramène d'abord sur `home` : l'échec peut
    // survenir alors que l'app est déjà partie ailleurs, et un overlay révélé sur une page
    // qui n'est plus affichée ne serait jamais vu.
    Future<void> _showHomeOverlay(String translationKey) async {

                                if (DvOrb.get_current_page()?.dvid != "home") DvOrb.navigate_reset("home");
                                await DvOrb.wait_for_shape("home/rejected_text");
                                DvOrb.get_shape_by_id("home/rejected_scrim")?..set("shape.visible", true)..refreshUI();
                                await _revealLabel("home/rejected_text", translationKey);
                                DvOrb.get_shape_by_id("home/rejected_close")?..set("shape.visible", true)..refreshUI();
    }

    // Compte refusé : 'not_found' (l'entrée Auth vient d'être supprimée) ou 'error'
    // (rien n'a été touché, on peut réessayer). Overlay, jamais de popup modale.
    Future<void> on_account_rejected(DvShape? caller, dynamic event) async {

                                final reason = event?.toString() ?? "error";
                                await _showHomeOverlay(
                                    reason == "not_found" ? "link_no_account_found" : "link_check_failed");
    }

    // La connexion n'a pas abouti, sur l'une des deux portes de `home`. On arrive ici AVANT
    // toute vérification de compte : la seule chose qu'on sache, c'est qu'aucune session n'a
    // pu s'ouvrir.
    //
    // Un SEUL tri, et il porte sur la porte empruntée, pas sur la cause : « Je pars à
    // l'aventure » n'implique aucun compte Google, lui parler d'autorisation parentale serait
    // absurde. Au-delà, on ne trie plus — sur un compte supervisé Family Link, le refus du
    // parent et l'enfant qui referme la feuille remontent le même `canceled`, et prétendre les
    // distinguer produirait un message faux une fois sur deux. Un texte couvre les deux.
    Future<void> on_login_failed(DvShape? caller, dynamic event) async {

                                final reason = event?.toString() ?? "";
                                deva_log("warning", "[worker] connexion échouée: $reason");
                                // L'ouverture de session déclenchée par la confirmation du royaume a
                                // échoué (hors ligne, le plus souvent). Le parcours n'est plus vivant :
                                // le prochain on_login qui aboutira devra reprendre la règle normale,
                                // sans quoi il enchaînerait une étape depuis un écran qu'on a quitté.
                                _onboardingLive = false;
                                await _showHomeOverlay(
                                    reason == "anonymous_failed" ? "start_failed" : "signin_failed_parent");
    }

    Future<void> on_rejected_close(DvShape? caller, dynamic event) async {

                                _hideShapes(["home/rejected_scrim", "home/rejected_text", "home/rejected_close"]);
    }

    //-- Écran de liaison ----------------------------------------------------

    // Impose la liaison du compte. Bloquant : aucun bouton « plus tard ». Une seule page
    // sert l'adulte et le mineur.
    Future<void> _requireAccountLink() async {

                                DvOrb.navigate_reset("link_account_screen");
    }

    // ⚠ `dynamic caller` ET NON `DvShape?` : l'`appear` d'une PAGE passe la page
    //   elle-même, et une page est un DvView, pas un DvShape. Typer le paramètre
    //   `DvShape?` faisait lever un `type 'DvPage' is not a subtype of 'DvShape?'` que
    //   DvView attrape et journalise — l'écran naissait donc inerte, en silence.
    Future<void> on_link_account_appear(dynamic caller, dynamic event) async {

                                _hideShapes([
                                    "link_account/error",
                                    "link_account/conflict_scrim", "link_account/conflict_text",
                                    "link_account/conflict_confirm", "link_account/conflict_cancel",
                                ]);
    }

    // Compte lié : l'uid n'a pas bougé, mais le joueur a désormais une identité durable.
    // C'est ici, et pas avant, que tout ce qu'il a saisi part en base.
    Future<void> on_account_linked(DvShape? caller, dynamic event) async {

                                if (!await _flushOnboarding()) {
                                    await _revealLabel("link_account/error", "link_flush_failed");
                                    return;
                                }
                                // Reprise complète du parcours nominal : on_login rejoue toute la mise en
                                // place (région, dvsession, Vertex, musique, vigilances) et décide seul de
                                // l'écran suivant à partir de ce qui est maintenant en base. Réimplémenter
                                // ce routage ici en dupliquerait la moitié, et le ferait diverger.
                                await on_login(caller, _cloud?.currentUser());
    }

    // Même texte que on_login_failed, et pour la même raison : à ce stade l'échec vient
    // presque toujours du sign-in Google lui-même (_acquireGoogleCredential avale l'exception
    // et rend `transient`), refus parental Family Link compris. « Réessaie dans un instant »
    // était un mauvais conseil — réessayer ne changera rien tant qu'un parent n'a pas autorisé.
    Future<void> on_link_failed(DvShape? caller, dynamic event) async {

                                deva_log("warning", "[worker] link échoué: ${event?.toString() ?? ""}");
                                await _revealLabel("link_account/error", "signin_failed_parent");
    }

    // Conflit : le compte Google visé porte déjà un héros.
    //
    // Rien n'a été écrit sous l'uid anonyme (on est avant le flush), donc on peut proposer
    // d'adopter le compte existant : c'est sans perte et sans migration. Vrai pour l'adulte, et
    // désormais pour le mineur aussi, qui se connecte AVANT d'entrer dans un clan ; son
    // invitation en attente suit alors le compte adopté.
    // La branche « clan_done » (blocage pur) ne sert plus que de filet : elle protégeait un
    // mineur admis dans un clan sous son uid anonyme, cas qui ne peut plus se produire. Surtout
    // pas de suppression dans ce cas : la cascade toucherait des données de tiers.
    Future<void> on_link_conflict(DvShape? caller, dynamic event) async {

                                final clanDone = (await Deva.instance.get("worker.session.clan_done"))?.toString() ?? "";
                                DvOrb.get_shape_by_id("link_account/conflict_scrim")?..set("shape.visible", true)..refreshUI();
                                if (clanDone == "true") {
                                    await _revealLabel("link_account/conflict_text", "link_conflict_kid_blocked");
                                    await _revealLabel("link_account/conflict_cancel", "link_rejected_close");
                                    return;
                                }
                                await _revealLabel("link_account/conflict_text",    "link_conflict_text");
                                await _revealLabel("link_account/conflict_confirm", "link_conflict_confirm");
                                await _revealLabel("link_account/conflict_cancel",  "link_conflict_cancel");
    }

    // Adoption du compte existant. Le tampon local est JETÉ avant tout : le flusher sur le
    // compte adopté écraserait ses steps et, pire, empilerait une seconde acceptation de
    // CGU en clôturant à tort la période de validité de la légitime.
    Future<void> on_link_conflict_confirm(DvShape? caller, dynamic event) async {

                                await _restartAnonymousOnboarding(navigate: false);
                                await ActionRegistry.get("dvcloud.do_adopt_existing_account")?.call(caller, null);
    }

    Future<void> on_link_conflict_cancel(DvShape? caller, dynamic event) async {

                                _hideShapes([
                                    "link_account/conflict_scrim", "link_account/conflict_text",
                                    "link_account/conflict_confirm", "link_account/conflict_cancel",
                                ]);
    }

    //-- Le flush ------------------------------------------------------------

    // Première écriture réelle du joueur en base : index, doc `users` et preuve de
    // consentement, d'un seul tenant. Idempotente : rejouable telle quelle.
    //
    // DEUX appelants, un par façon d'arriver au bout du parcours :
    //   * la liaison du compte Google : l'adulte comme le mineur, qui vient d'acquérir une
    //     identité durable à qui rattacher tout cela. Le mineur n'a plus de flush à lui :
    //     il écrivait autrefois son onboarding en entrant dans le flux de clan, sous son
    //     identifiant anonyme et avant toute décision de son parent. Il se connecte
    //     désormais une fois l'invitation du parent en main, et passe par ici comme tout
    //     le monde ;
    //   * l'acceptation des conditions — le compte Google déjà authentifié dont la
    //     session en base a disparu, et qui refait donc tout le parcours
    //     (`proofAlreadyWritten`, dvdocuments n'étant pas différé pour lui).
    //
    // ⚠ C'EST LE SEUL POINT D'ÉCRITURE DE L'ONBOARDING, et ça doit le rester. Les
    //   étapes intermédiaires écrivaient autrefois au fil de l'eau pour les sessions
    //   authentifiées ; un incident réseau entre deux écrans laissait alors un compte à
    //   moitié constitué, que la reprise suivante prenait pour un parcours en cours.
    //   Un compte absent se refait de zéro ; un compte à moitié là ne se répare pas.
    //
    // Rend false sans avoir tout écrit dès qu'une étape échoue. L'appelant ne doit alors
    // PAS poursuivre : atteindre new_or_pick_clan sans userindexes ferait échouer la
    // création de clan au niveau des règles Firestore, panne bien plus tardive et bien
    // plus obscure que le message ré-essayable affiché à cet instant.
    // [proofAlreadyWritten] : la preuve de consentement a DÉJÀ été inscrite par
    // dvdocuments, qui n'était pas en mode différé (session non anonyme). Il n'y a
    // donc rien « en attente », et la garde d'intégrité ci-dessous — qui refuse
    // d'inscrire un compte accepté sans preuve à écrire — doit le savoir : son
    // intention est remplie autrement, pas contournée.
    Future<bool> _flushOnboarding({bool proofAlreadyWritten = false}) async {

                                // `region` route (datacenter), `market` s'enregistre (royaume choisi).
                                // Les deux sont exigés : sans le royaume, la reprise de session ne
                                // saurait plus lequel rejouer, et rien ne permettrait de le retrouver
                                // puisque plusieurs royaumes partagent un datacenter.
                                final region      = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                final market      = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final legalState  = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "";
                                final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                final docId       = _sessionDocId();
                                if (region.isEmpty || market.isEmpty || legalState.isEmpty || firebaseUid.isEmpty || docId.isEmpty) {
                                    deva_log("error", "[worker] _flushOnboarding: état incomplet "
                                        "(region='$region' market='$market' legal='$legalState' uid=${firebaseUid.isNotEmpty} docId=${docId.isNotEmpty}) → rien n'est écrit");
                                    return false;
                                }
                                _cloud?.configure("region", region);

                                // Garde d'intégrité : pas de compte « accepté » sans preuve à écrire. Le
                                // seul rejeu légitime est celui d'un flush déjà passé (mineur), reconnaissable
                                // à un doc users portant déjà steps.cgu.
                                final existing = await _readSession(region) ?? Dvidle({});
                                final dvdocs   = ModuleRegistry.create("documents");
                                final pending  = dvdocs != null && ((dvdocs as dynamic).hasPendingAcceptance as bool? ?? false);
                                if (!pending && !proofAlreadyWritten && existing.get("steps.cgu") == null) {
                                    deva_log("error", "[worker] _flushOnboarding: aucune acceptation à inscrire → rien n'est écrit");
                                    return false;
                                }

                                // 1. userindexes EN PREMIER, et ce n'est pas un détail de style : c'est le
                                //    document que TOUTES les règles Firestore déréférencent, et celui qui
                                //    rend le compte retrouvable au prochain lancement. Interrompu juste
                                //    après, on laisse un compte découvrable plutôt qu'un `users` orphelin —
                                //    or c'est précisément l'orphelin que verify_account refuse.
                                try {
                                    await _cloud?.write("workers", "userindexes", firebaseUid,
                                        Dvidle({"ownerId": firebaseUid, "userId": docId, "enabled": true}), region: region);
                                } catch (e) {
                                    deva_log("error", "[worker] _flushOnboarding: userindexes FAILED: $e");
                                    return false;
                                }

                                // 2. users : les quatre steps en UNE écriture fusionnée. dvcloud écrit en
                                //    deep merge, c'est donc strictement équivalent à quatre _writeStep —
                                //    en un aller-retour au lieu de huit, et sans risque d'écraser un
                                //    steps.clan concurrent (le chemin mineur en pose un juste après).
                                try {
                                    final device = await _cloud?.deviceId() ?? "";
                                    final now    = DateTime.now().toUtc().toIso8601String();
                                    existing.rem("docId");
                                    existing.set("ownerId", firebaseUid);
                                    existing.set("userId",  docId);
                                    existing.set("enabled", true);
                                    // `region_intro` et `region` enregistrent le ROYAUME choisi, pas
                                    // le datacenter qui route l'écriture : c'est cette valeur que
                                    // _findPartialSession relit pour rejouer le choix à la reprise.
                                    // Les deux se confondaient du temps où la « région » désignait
                                    // le datacenter.
                                    final steps = {
                                        "region_intro": market,
                                        "region":       market,
                                        "legal_state":  legalState,
                                        "cgu":          "accepted",
                                    };
                                    for (final step in steps.entries) {
                                        existing.set("steps.${step.key}.status", "done");
                                        existing.set("steps.${step.key}.date",   now);
                                        existing.set("steps.${step.key}.result", step.value);
                                        existing.set("steps.${step.key}.device", device);
                                    }
                                    existing.set("date", now);
                                    await _cloud?.write("workers", "users", docId, existing, region: region);
                                    _invalidateSessionCache();
                                } catch (e) {
                                    deva_log("error", "[worker] _flushOnboarding: users FAILED: $e");
                                    return false;
                                }

                                // 3. Session légale + preuve de consentement, rejouée par dvdocuments avec
                                //    l'horodatage RÉEL de l'acceptation.
                                bool docsOk = proofAlreadyWritten;
                                if (dvdocs != null && !proofAlreadyWritten) {
                                    try {
                                        docsOk = await (dvdocs as dynamic).flushPending() as bool? ?? false;
                                    } catch (e) {
                                        deva_log("error", "[worker] _flushOnboarding: documents.flushPending a levé: $e");
                                    }
                                }
                                if (!docsOk) {
                                    deva_log("error", "[worker] _flushOnboarding: preuve de consentement NON écrite");
                                    return false;
                                }

                                // 4. Device FCM — non critique : un échec ne prive que des notifications.
                                try { await _messaging?.msgregister('global'); }
                                catch (e) { deva_log("warning", "[worker] _flushOnboarding: msgregister: $e"); }

                                deva_log("info", "[worker] _flushOnboarding: onboarding inscrit en base (région $region)");
                                return true;
    }

    // Remise au premier écran d'un onboarding anonyme qui n'a pas abouti.
    //
    // ⚠ PLUS RIEN À RÉPARER, SEULEMENT DE LA MÉMOIRE À VIDER. Avant le login, rien ne touche
    //   ni le disque (couche `prelogin`, en mémoire) ni la base, et la session anonyme ne
    //   survit plus à un kill. Cette méthode effaçait autrefois un RÉSIDU persisté (royaume,
    //   acceptation en attente) puis l'enregistrait vide ; il n'y a plus de résidu, donc plus
    //   de store() non plus.
    //
    // [navigate] false quand l'appelant enchaîne sur sa propre destination (adoption d'un
    // compte existant, qui se termine par son on_login) : le tampon local doit être jeté pour
    // ne pas être versé sur le compte adopté, mais l'invitation éventuellement en attente, elle,
    // reste : c'est bien ce compte-là qui la recevra.
    Future<void> _restartAnonymousOnboarding({bool navigate = true}) async {

                                final dvdocs = ModuleRegistry.create("documents");
                                if (dvdocs != null) {
                                    try { await (dvdocs as dynamic).resetLocalSession(); } catch (_) {}
                                }
                                await Deva.instance.set("worker.session.clan_done",            "");
                                await Deva.instance.set("worker.session.create_clan_disabled", "");
                                await Deva.instance.set("worker.pending_member_joined",        null);
                                await Deva.instance.set("worker.pending_clan_welcome",         "");
                                await Deva.instance.set("worker.pending_review_task",          "");
                                await Deva.instance.set("session.user.name",                   "");
                                if (!navigate) return;

                                await _forgetKidAssent();
                                // ⚠ PAS DE `navigate_reset` SI L'ON Y EST DEJA : au démarrage l'orb
                                //   ouvre `awake` (home_page) et la boucle des sept langues tient
                                //   une référence sur `awake/question`. Reconstruire la page à
                                //   l'identique la lui arracherait, et le seuil deviendrait un écran
                                //   noir muet.
                                deva_log("info", "[worker] onboarding anonyme sans données → retour au seuil");
                                if (DvOrb.get_current_page()?.dvid != "awake") {
                                    DvOrb.navigate_reset("awake");
                                }
    }

    //-----------------------------------------------------------------------
    //-- Session Firestore helpers -----------------------------------------
    //-----------------------------------------------------------------------

    // Doc perso `users/` : TOUJOURS l'utilisateur authentifié (_authUserId), jamais l'id agissant
    // (_userId, qui peut pointer une cible en impersonation). Repli sur _userId tant que _authUserId
    // n'est pas résolu (avant le 1er on_login, où _userId == _authUserId de toute façon).
    String _sessionDocId() => _authUserId.isNotEmpty ? _authUserId : _userId;

    Future<String> _resolveUserId() async {

                                final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                if (firebaseUid.isEmpty) return "";
                                // userindexes vit dans la base régionale (eu-workers), pas dans une base
                                // globale. Sur un device frais _currentRegion est vide → une lecture sans
                                // region: ciblerait la base non-préfixée inexistante. On scanne donc les
                                // régions connues (comme _findBestSession) pour retrouver l'index.
                                final regionsData = await deva_get("regions");
                                final regionKeys  = regionsData is Dvidle ? regionsData.keys : <String>[];
                                for (final key in regionKeys) {
                                    final region = key.toLowerCase();
                                    try {
                                        final index = await _cloud?.read("workers", "userindexes", firebaseUid, region: region);
                                        final existing = index?.get("userId")?.toString() ?? "";
                                        if (existing.isNotEmpty) {
                                            deva_log("info", "[worker] userindexes trouvé en région '$region' → userId=$existing");
                                            return existing;
                                        }
                                    } catch (_) {}
                                }
                                return _generateUuid();
    }

    // Lecture du doc users, servie par un cache mémoire à TTL court : les handlers
    // l'appellent en rafale (appear combat → seldomain → seltask = 3 lectures du même
    // doc en quelques secondes). Copie défensive à CHAQUE service : les appelants
    // font du read-modify-write sur le doc rendu — muter l'objet du cache corromprait
    // les lectures suivantes. Toute écriture locale du doc DOIT passer par
    // _invalidateSessionCache() (sinon le read-modify-write suivant repartirait d'un
    // état périmé et son PATCH écraserait l'écriture précédente).
    Future<Dvidle?> _readSession(String region) async {

                                final docId = _sessionDocId();
                                if (docId.isEmpty) return null;
                                final key = "$region/$docId";
                                final at  = _sessionCacheAt;
                                if (_sessionCache != null && _sessionCacheKey == key && at != null &&
                                    DateTime.now().difference(at) < const Duration(seconds: 10)) {
                                    return Dvidle(_sessionCache!.toJson());
                                }
                                final doc = await _cloud?.read("workers", "users", docId, region: region);
                                _sessionCache    = doc == null ? null : Dvidle(doc.toJson());
                                _sessionCacheKey = key;
                                _sessionCacheAt  = DateTime.now();
                                return doc;
    }

    //-----------------------------------------------------------------------
    //-- dvautover : version des données du clan -----------------------------
    //-----------------------------------------------------------------------

    /// Le build de l'application (versionCode), 0 s'il est inconnu.
    Future<int> _appBuild() async =>
            int.tryParse((await deva_get("application.build"))?.toString() ?? "") ?? 0;

    /// Rappel de dvautover (conf `autover.provider`) : l'état de la PORTÉE du joueur,
    /// c'est-à-dire de son clan. `{}` pour un joueur sans clan : rien à contrôler.
    ///
    /// ⚠ LE STATUT DE CHEF N'EST ICI QU'UN AIGUILLAGE D'ÉCRAN. La fonction cloud le
    ///   revérifie côté serveur avant de toucher au clan : un client modifié qui se dirait
    ///   chef n'obtiendrait qu'un refus.
    ///
    /// ⚠ UN CLAN SANS `data_version` (né avant dvautover) RECOIT LE BUILD DE L'APPLICATION
    ///   QUI LE VOIT LA PREMIÈRE (design §3). Les règles Firestore n'autorisent ce geste
    ///   que tant que le champ est absent.
    Future<Map<String, dynamic>> autover_state(DvShape? caller, dynamic event) async {

                                final region = event is Map ? (event["region"]?.toString() ?? "") : "";
                                final build  = event is Map ? (int.tryParse(event["build"]?.toString() ?? "") ?? 0) : 0;
                                if (region.isEmpty || _cloud == null) return {};
                                final session    = await _readSession(region);
                                final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isEmpty || clanSecret.isEmpty) return {};

                                final clanDoc = await _cloud?.read("workers", "clans", clanId,
                                    ownerId: clanSecret, region: region);
                                if (clanDoc == null) return {};

                                var dataVersion = int.tryParse(clanDoc.get("data_version")?.toString() ?? "") ?? 0;
                                if (dataVersion <= 0 && build > 0) {
                                    try {
                                        await _cloud?.write("workers", "clans", clanId,
                                            Dvidle({"data_version": build}), region: region, ownerId: clanSecret);
                                        dataVersion = build;
                                        deva_log("info", "[worker] autover : data_version du clan posée à $build");
                                    } catch (e) {
                                        deva_log("warning", "[worker] autover : data_version non posée : $e");
                                    }
                                }
                                final admins = List<dynamic>.from(clanDoc.get("admins") as List? ?? []);
                                // La région de production du pays du joueur (retour de beta).
                                final home = (await ActionRegistry.get("documents.home_cloud")?.call(caller, null))
                                                 ?.toString() ?? "";
                                return {
                                    "scope":        clanId,
                                    "secret":       clanSecret,
                                    "data_version": dataVersion,
                                    "chief":        admins.contains(_userId),
                                    "locked_until": clanDoc.get("locked_until"),
                                    "home_region":  home,
                                };
    }

    /// Reprise du démarrage après un écran d'attente de dvautover (conf
    /// `autover.resume_action`) : on rejoue le login, qui refait le contrôle puis reprend
    /// exactement là où il s'était arrêté.
    Future<void> autover_resume(DvShape? caller, dynamic event) async {

                                _invalidateSessionCache();
                                await on_login(caller, _cloud?.currentUser());
    }

    // À appeler après CHAQUE écriture du doc users (read-modify-write oblige).
    void _invalidateSessionCache() {

                                _sessionCache    = null;
                                _sessionCacheKey = "";
                                _sessionCacheAt  = null;
    }

    Future<void> _writeStep(String region, String stepName, String result) async {

                                final docId      = _sessionDocId();
                                if (docId.isEmpty) return;
                                try {
                                    final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                    final device      = await _cloud?.deviceId() ?? "";
                                    final now         = DateTime.now().toUtc().toIso8601String();
                                    final existing    = await _readSession(region) ?? Dvidle({});
                                    existing.rem("docId");
                                    existing.set("ownerId",                firebaseUid);
                                    existing.set("userId",                 docId);
                                    // Marqueur d'activation du compte : posé à chaque écriture d'onboarding.
                                    // Une suppression logique (fonction cloud delete_user_data) pose enabled=false ;
                                    // le re-onboarding passe forcément par ici → réactive le compte sans code dédié.
                                    existing.set("enabled",                true);
                                    existing.set("steps.$stepName.status", "done");
                                    existing.set("steps.$stepName.date",   now);
                                    existing.set("steps.$stepName.result", result);
                                    existing.set("steps.$stepName.device", device);
                                    existing.set("date", now);
                                    await _cloud?.write("workers", "users", docId, existing, region: region);
                                    _invalidateSessionCache();
                                    deva_log("info", "[worker] session step '$stepName'=$result → firestore OK");
                                } catch (e) {
                                    deva_log("error", "[worker] session step '$stepName' FAILED: $e");
                                }
    }

    // Date d'activité du compte : `users.last_seen`, chaîne ISO-8601 UTC (comme `date`, et
    // JAMAIS un timestamp : la requête du balayage serveur compare des chaînes). Posée à la
    // reprise d'un compte connecté, clan ou pas, au plus une fois par jour : le document dit
    // lui-même si la date du jour y est déjà, et _lastSeenDay évite de le relire au login
    // suivant du même processus. Rien sur le disque : avant le login, on n'écrit nulle part.
    //
    // Sert au balayage des comptes jamais admis dans un clan (pulse_sweeper, piste orphans) :
    // 30 jours sans last_seen (repli users.date, puis steps.cgu.date) et un compte qui n'a
    // jamais eu de clan est effacé. Un échec d'écriture est sans conséquence immédiate : on
    // réessaiera au prochain login.
    Future<void> _touchLastSeen(Dvidle session, String region) async {

                                final docId = _sessionDocId();
                                if (docId.isEmpty || region.isEmpty) return;
                                final now   = DateTime.now().toUtc();
                                final today = now.toIso8601String().substring(0, 10);
                                if (_lastSeenDay == today) return;
                                if ((session.get("last_seen")?.toString() ?? "").startsWith(today)) {
                                    _lastSeenDay = today;
                                    return;
                                }
                                try {
                                    await _cloud?.write("workers", "users", docId,
                                        Dvidle({"last_seen": now.toIso8601String()}), region: region);
                                    _lastSeenDay = today;
                                } catch (e) {
                                    deva_log("warning", "[worker] last_seen non écrit: $e");
                                }
                                // La session lue par _findBestSession est en cache : la relire après
                                // l'écriture, sinon un read-modify-write qui suit réécrirait l'ancienne date.
                                _invalidateSessionCache();
    }

    //-----------------------------------------------------------------------
    //-- Journal d'audit du clan (clans_logs) -------------------------------
    //-----------------------------------------------------------------------

    // Fragment d'ID Firestore sûr : alphanumérique ASCII, tronqué. Le nom lisible
    // complet reste dans le champ data du log.
    String _slug(String s) {

                                final b = StringBuffer();
                                for (final c in s.split('')) {
                                    if (RegExp(r'[A-Za-z0-9]').hasMatch(c)) b.write(c);
                                }
                                final out = b.toString();
                                return out.isEmpty ? "na" : (out.length > 40 ? out.substring(0, 40) : out);
    }

    Future<void> _deleteSession(String region) async {

                                final docId     = _sessionDocId();
                                if (docId.isEmpty) return;
                                final session   = await _readSession(region);
                                final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                if (clanId.isNotEmpty) {
                                    try { await _cloud?.delete("workers", "clans",      clanId, region: region, ownerId: clanSecret); } catch (_) {}
                                    // clans_tasks : sous-collections → énumérer puis supprimer en batch (pas de delete récursif en REST).
                                    try {
                                        final dels = <DvCloudWrite>[];
                                        for (final d in await _cloud?.list("workers", "clans_tasks/$clanId/tasks", region: region) ?? []) {
                                            final id = d.get("docId")?.toString() ?? "";
                                            if (id.isNotEmpty) dels.add(DvCloudWrite.delete("clans_tasks/$clanId/tasks", id));
                                        }
                                        for (final d in await _cloud?.list("workers", "clans_tasks/$clanId/domains", region: region) ?? []) {
                                            final id = d.get("docId")?.toString() ?? "";
                                            if (id.isNotEmpty) dels.add(DvCloudWrite.delete("clans_tasks/$clanId/domains", id));
                                        }
                                        if (dels.isNotEmpty) await _cloud?.batchWrite("workers", dels, region: region);
                                    } catch (_) {}
                                }
                                await _cloud?.delete("workers", "users", docId, region: region);
                                _invalidateSessionCache();
    }

    Future<(String, Dvidle)?> _findBestSession() async {

                                final regionsData = await deva_get("regions");
                                final regionKeys  = regionsData is Dvidle ? regionsData.keys : <String>[];

                                Dvidle?  best       = null;
                                String?  bestRegion = null;
                                DateTime? bestDate  = null;

                                for (final key in regionKeys) {
                                    final region = key.toLowerCase();
                                    try {
                                        final session = await _readSession(region);
                                        // Compte supprimé (soft delete) : traité comme inexistant → onboarding complet.
                                        if (session?.get("enabled") == false) continue;
                                        if (session?.get("steps.region") == null) continue;
                                        final dateStr = session!.get("date")?.toString();
                                        final date    = dateStr != null ? DateTime.tryParse(dateStr) : null;
                                        if (best == null || (date != null && (bestDate == null || date.isAfter(bestDate!)))) {
                                            best       = session;
                                            bestRegion = region;
                                            bestDate   = date;
                                        }
                                    } catch (_) {}
                                }

                                return best != null && bestRegion != null ? (bestRegion!, best!) : null;
    }

    // Trouve une session où region_intro est écrite mais pas encore steps.region (age_screen non complété).
    Future<(String, Dvidle)?> _findPartialSession() async {

                                final regionsData = await deva_get("regions");
                                final regionKeys  = regionsData is Dvidle ? regionsData.keys : <String>[];

                                Dvidle?   best       = null;
                                String?   bestRegion = null;
                                DateTime? bestDate   = null;

                                for (final key in regionKeys) {
                                    final region = key.toLowerCase();
                                    try {
                                        final session = await _readSession(region);
                                        // Compte supprimé (soft delete) : traité comme inexistant → onboarding complet.
                                        if (session?.get("enabled") == false) continue;
                                        if (session?.get("steps.region_intro") == null) continue;
                                        if (session?.get("steps.region")       != null) continue;
                                        final dateStr = session!.get("date")?.toString();
                                        final date    = dateStr != null ? DateTime.tryParse(dateStr) : null;
                                        if (best == null || (date != null && (bestDate == null || date.isAfter(bestDate!)))) {
                                            best       = session;
                                            bestRegion = region;
                                            bestDate   = date;
                                        }
                                    } catch (_) {}
                                }

                                return best != null && bestRegion != null ? (bestRegion!, best!) : null;
    }

    // Compte supprimé (enabled=false via delete_user_data) qui se reconnecte : on efface les champs
    // de routage/état du doc users pour repartir de zéro. L'onboarding merge dans le doc existant :
    // sans ce reset, l'ancien steps.clan re-router le joueur vers son clan mort dès que _writeStep
    // remet enabled=true. On garde userindexes.clans (clanSecret) intact pour un futur clan recovery.
    /// La région vers laquelle le compte a déménagé, si ce n'est PAS une région que
    /// cette application connaît ; "" sinon. Lit la pierre tombale laissée au départ
    /// par la migration du clan (`users.moved_to`, ddust_autover).
    Future<String> _movedElsewhere() async {

                                final docId = _sessionDocId();
                                if (docId.isEmpty) return "";
                                final regionsData = await deva_get("regions");
                                final regionKeys  = (regionsData is Dvidle ? regionsData.keys : <String>[])
                                                    .map((k) => k.toLowerCase()).toList();
                                for (final region in regionKeys) {
                                    try {
                                        final session = await _readSession(region);
                                        final moved   = session?.get("moved_to")?.toString().toLowerCase() ?? "";
                                        if (moved.isNotEmpty && !regionKeys.contains(moved)) return moved;
                                    } catch (_) {}
                                }
                                return "";
    }

    Future<void> _resetDisabledSession() async {

                                final docId = _sessionDocId();
                                if (docId.isEmpty) return;
                                final regionsData = await deva_get("regions");
                                final regionKeys  = regionsData is Dvidle ? regionsData.keys : <String>[];
                                for (final key in regionKeys) {
                                    final region = key.toLowerCase();
                                    try {
                                        final session = await _readSession(region);
                                        if (session == null) continue;
                                        if (session.get("enabled") != false) continue;
                                        // Une pierre tombale de DÉMÉNAGEMENT n'est pas un compte supprimé : le
                                        // joueur vit dans une autre région. La réactiver ici créerait un
                                        // second compte, vide, qui masquerait le vrai.
                                        if ((session.get("moved_to")?.toString() ?? "").isNotEmpty) continue;
                                        // Effacement deep-merge : poser le champ à "" (convention dvcloud).
                                        final wipe = Dvidle({});
                                        wipe.set("steps",        "");
                                        wipe.set("clans",        "");
                                        wipe.set("first_clan",   "");
                                        wipe.set("last_clan",    "");
                                        wipe.set("active_task",  "");
                                        wipe.set("active_proof", "");
                                        // Une adhésion en attente d'avant la suppression ne doit pas ramener
                                        // le compte réactivé sur join_wait.
                                        wipe.set("pending_join", "");
                                        await _cloud?.write("workers", "users", docId, wipe, region: region);
                                        _invalidateSessionCache();
                                        deva_log("info", "[worker] compte réactivé : session '$region' remise à zéro");
                                    } catch (e) {
                                        deva_log("error", "[worker] _resetDisabledSession('$region') FAILED: $e");
                                    }
                                }
    }

    Future<void> do_reset(DvShape? caller, dynamic event) async {

                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                if (region.isNotEmpty) {
                                    try { await _deleteSession(region); } catch (_) {}
                                }
                                await Deva.instance.set("worker.session.clan_done", "");
                                await ActionRegistry.get("dvcloud.do_logout")?.call(null, null);
    }

    Future<void> do_toggle_theme(DvShape? caller, dynamic event) async {

                                final theme = dvtheme.instance;
                                if (theme == null) return;
                                final active = theme.get('active')?.toString();
                                if (active == 'theme-pirate') {
                                    await theme.switchTheme(null);
                                } else {
                                    await theme.switchTheme('theme-pirate');
                                }
    }

    Future<void> do_count_sessions(DvShape? caller, dynamic event) async {

                                final result = await _cloud!.call("count_sessions", Dvidle({}));
                                final count = result.get("count");
                                deva_log("info", "Sessions count: $count");
    }

    Future<void> on_test_silent(DvShape? caller, dynamic event) async {

                                deva_log("info", "[test] notification silencieuse reçue");
    }

    Future<void> do_test_messaging(DvShape? caller, dynamic event) async {

                                final messaging = _messaging;
                                if (messaging == null) {
                                    deva_log("error", "[test] module dvmessaging indisponible");
                                    return;
                                }

                                // Envois globaux adressés à CET appareil. Les destinataires étaient codés en
                                // dur (un poste Windows et `BP2A.250605.015`, un Build.ID Android que tous
                                // les téléphones à la même mise à jour partageaient).
                                // ⚠ recipes vide = TOUS les appareils du tenant : sans identifiant, on sort.
                                final selfDevice  = await _cloud?.deviceId() ?? "";
                                if (selfDevice.isEmpty) {
                                    deva_log("error", "[test] deviceId indisponible (compte non connecté ?)");
                                    return;
                                }
                                final selfRecipes = [selfDevice];

                                // 1. Notification silencieuse (local, sans label, 1 action)
                                deva_log("info", "[test] envoi notification silencieuse...");
                                try {
                                    await messaging.send(dvmsg(
                                        range: 'local',
                                        actions: {
                                            'test_silent': {
                                                'label':  'OK',
                                                'action': 'worker.on_test_silent',
                                                'wakeup': false,
                                            },
                                        },
                                    ));
                                } catch (e) {
                                    deva_log("error", "[test] silencieuse: ko ($e)");
                                }

                                // 2. Notification locale (local, avec label)
                                deva_log("info", "[test] envoi notification locale...");
                                try {
                                    await messaging.send(dvmsg(
                                        range: 'local',
                                        label: 'Test notification locale',
                                    ));
                                } catch (e) {
                                    deva_log("error", "[test] locale: ko ($e)");
                                }

                                // 3. Notification globale
                                deva_log("info", "[test] envoi notification globale...");
                                try {
                                    final result = await messaging.send(dvmsg(
                                        range:   'global',
                                        label:   'Test notification globale',
                                        recipes: selfRecipes,
                                    ));
                                    deva_log("info", "[test] globale: ${result.get('status')}");
                                } catch (e) {
                                    deva_log("error", "[test] globale: ko ($e)");
                                }

                                // 4. Notification broadcast
                                deva_log("info", "[test] envoi notification broadcast...");
                                try {
                                    final eventID = 'test-${DateTime.now().millisecondsSinceEpoch}';
                                    final result  = await messaging.send(dvmsg(
                                        range:   'broadcast',
                                        label:   'Test notification broadcast',
                                        eventID: eventID,
                                        mode:    'noorb',
                                        recipes: selfRecipes,
                                        actions: {
                                            'tap': {
                                                'action': 'worker.on_test_silent',
                                                'wakeup': false,
                                            },
                                        },
                                    ));
                                    deva_log("info", "[test] broadcast: ${result.get('status')}");
                                } catch (e) {
                                    deva_log("error", "[test] broadcast: ko ($e)");
                                }

                                // 5. Notification locale programmée (40 secondes)
                                deva_log("info", "[test] envoi notification locale schedulée (40s)...");
                                try {
                                    final result = await messaging.send(dvmsg(
                                        range:    'local',
                                        label:    'Test notification schedulée',
                                        schedule: 20,
                                    ));
                                    deva_log("info", "[test] schedulée: ${result.get('status')}");
                                } catch (e) {
                                    deva_log("error", "[test] schedulée: ko ($e)");
                                }
    }

    // Selector du kebab Personnage : masque l'option de suppression pendant l'impersonation
    // (providerUid = admin → on ne veut pas supprimer le compte admin depuis la fiche d'un autre).
    // Ouvre la politique de confidentialité DANS l'application, en lecture seule. Aucun suffixe
    // @<legalstate> : l'état légal de la session s'applique, un mineur reçoit donc la version
    // enfant et un adulte la version adulte, dans la région et la langue de sa session. La
    // politique ne s'accepte pas : c'est sa version courante qui s'applique, et qui s'affiche.
    Future<void> open_privacy(dynamic caller, dynamic event) async {

                                await ActionRegistry.get("documents.view_doc")?.call(null, "privacy");
    }

    // Ouvre les conditions d'utilisation DANS l'application, en lecture seule : la version que le
    // joueur a ACCEPTÉE (documents.acceptance.cgu.version), dans sa langue, sa région et son état
    // légal. Aucune ré-acceptation possible d'ici : une nouvelle version passe par le flux
    // d'acceptation du lancement (hasNewDocuments), jamais par cet écran.
    Future<void> open_cgu(dynamic caller, dynamic event) async {

                                await ActionRegistry.get("documents.view_doc")?.call(null, "cgu");
    }

    Future<List<String>> perso_settings_selector(dynamic caller, dynamic data) async {

                                final options = ["my_log", "tutorials", "change_lang", ...await _vitalSettingsOptions()];
                                // MULTICLAN : couper les notifications de ce téléphone, pour ce clan ou pour
                                // tous (silence à la source). Juste après les rappels ; une option de
                                // chaque paire, selon l'état relu sur la fiche de l'appareil.
                                final notif = await _notifMenuOptions();
                                final afterNudges = options.indexWhere((o) => o == "nudges_on" || o == "nudges_off");
                                options.insertAll(afterNudges < 0 ? 3 : afterNudges + 1, notif);
                                // « Noter et partager », adultes seulement, JUSTE AVANT la déconnexion :
                                // la suppression du compte reste la dernière ligne. Hors de
                                // _vitalSettingsOptions : le menu de mort n'a pas à le proposer.
                                final bool isAdult =
                                    (await Deva.instance.get("worker.player_is_adult"))?.toString() == "true";
                                if (isAdult) {
                                    final at = options.indexOf("logout");
                                    options.insert(at < 0 ? options.length : at, "rate_share");
                                }
                                return options;
    }

    // Menu du kebab posé au-dessus du voile de mort (commons/death_settings_menu) : les seules
    // fonctions VITALES, avec exactement les règles du menu Personnage (même helper).
    Future<List<String>> death_settings_selector(dynamic caller, dynamic data) async {

                                return _vitalSettingsOptions();
    }

    // Depuis le menu de mort : le panneau de suppression vit sur l'écran Personnage. On s'y rend
    // d'abord (même navigation que la taskbar), puis on l'ouvre. Mêmes gardes qu'open_delete_account.
    Future<void> death_open_delete(dynamic caller, dynamic event) async {

                                if (_impersonating) return;
                                if (DvOrb.get_current_page()?.dvid != "personnage") {
                                    DvOrb.navigate_new("personnage");
                                    if (await DvOrb.wait_for_shape("personnage/delete_panel") == null) return;
                                }
                                await open_delete_account(caller, event);
    }

    // Les options VITALES, communes au menu Personnage et au menu de mort : le guide, les
    // rappels, la politique de confidentialité, la déconnexion et la suppression du compte. Ce
    // sont les droits que le dossier « intérêt supérieur de l'enfant » présente comme toujours
    // accessibles : une seule liste, pour que les deux menus ne divergent jamais.
    Future<List<String>> _vitalSettingsOptions() async {

                                final options = <String>[];

                                // LE GUIDE, dans la version qui s'adresse à celui qui ouvre le menu.
                                // Le partage se fait sur l'âge et NON sur le rôle de chef : le guide
                                // parent parle de parentalité, pas de droits d'administration — un
                                // adulte non chef y a droit, un aîné promu chef n'y a rien à lire.
                                // `player_is_adult` est le miroir de `legal_state` posé par
                                // _ensureIsAdult ; son repli est "false", donc l'inconnu reçoit le
                                // guide de l'aventurier, qui ne peut jamais nuire à un adulte.
                                final bool isAdult =
                                    (await Deva.instance.get("worker.player_is_adult"))?.toString() == "true";
                                options.add(isAdult ? "guide_parent" : "guide_enfant");

                                // Rappels de relance : une seule des deux options, selon l'état courant.
                                // Lecture directe plutôt que cache : un menu s'ouvre rarement, et un
                                // réglage qui affiche l'inverse de ce qu'il vaut est pire que tout —
                                // l'utilisateur croirait avoir coupé ce qu'il vient de rallumer.
                                // Illisible (hors clan, réseau) : on n'affiche NI l'une NI l'autre plutôt
                                // que de deviner.
                                try {
                                    final region     = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                    final session    = await _readSession(region);
                                    final clanId     = session?.get("steps.clan.clanId")?.toString()     ?? "";
                                    final clanSecret = session?.get("steps.clan.clanSecret")?.toString() ?? "";
                                    if (clanId.isNotEmpty && clanSecret.isNotEmpty && _userId.isNotEmpty) {
                                        final pdoc = await _cloud?.read(
                                            "workers", "clans_players/$clanId/players", _userId,
                                            ownerId: clanSecret, region: region);
                                        if (pdoc != null) {
                                            options.add(pdoc.get("nudges") == false ? "nudges_on" : "nudges_off");
                                        }
                                    }
                                } catch (e) {
                                    deva_log("warning", "[pulse] perso_settings_selector : rappels illisibles ($e)");
                                }

                                // Les deux documents légaux, côte à côte : ce qu'on a accepté, puis ce
                                // que le jeu fait de nos données.
                                options.add("cgu");
                                options.add("privacy");
                                // ⚠ LA SUPPRESSION DU COMPTE EN DERNIER, APRES la deconnexion. Elle
                                //   etait avant-derniere, donc collee au-dessus d'une option
                                //   voisine par le libelle et anodine par l'effet : se deconnecter
                                //   se defait, supprimer son compte non. Une action irreversible se
                                //   met au bout de la liste, ou l'on n'arrive pas par inadvertance.
                                options.add("logout");
                                if (!_impersonating) options.add("delete_account");
                                return options;
    }

    // Ouvre le picker de langue (drapeau + nom, langue active en surbrillance), à la même
    // position écran que le menu settings qui vient de se fermer (`personnage/settings_menu`
    // garde la position RÉELLE — espace Overlay/Navigator — à laquelle il a été ouvert par le
    // kebab). `shape.x`/`shape.y` ne conviennent pas ici : ils sont en espace local au Stack
    // de la page, pas en espace écran.
    Future<void> open_lang_menu(dynamic caller, dynamic event) async {

                                final menu = DvOrb.get_shape_by_id("personnage/settings_menu");
                                final anchor = (menu is DvMenu && menu.lastShowPosition != null)
                                    ? menu.lastShowPosition!
                                    : const Offset(100, 100);
                                await DvLangButton.showPickerAt(anchor);
    }

    void _setDeleteVisible(bool v) {

                                for (final id in const [
                                    "personnage/delete_scrim",
                                    "personnage/delete_panel",
                                    "personnage/delete_yes",
                                    "personnage/delete_no",
                                ]) {
                                    final s = DvOrb.get_shape_by_id(id);
                                    s?.set("shape.visible", v);
                                    s?.refreshUI();
                                }
                                // personnage/coming_soon occupe 30→80 % — pile derrière le panneau, et le
                                // scrim n'est qu'à 0.9 d'opacité : son « Bientôt » transparaît en plein
                                // milieu de l'avertissement. On le retire le temps de la confirmation.
                                final cs = DvOrb.get_shape_by_id("personnage/coming_soon");
                                cs?.set("shape.visible", !v);
                                cs?.refreshUI();
    }

    // DvLabel ne peint que shape.display, recalculé par computeDisplay() (cf. dvlabel_motor) :
    // écrire shape.label seul laisse le texte figé sur celui du YAML — ici le " " de l'overlay.
    Future<void> _setDeleteLabel(String id, String key) async {

                                final s = DvOrb.get_shape_by_id(id);
                                if (s is! DvLabel) return;
                                s.set("shape.label", TranslationRegistry.translate(key));
                                await s.computeDisplay();
                                s.refreshUI();
    }

    Future<void> _applyDeleteStep() async {

                                final last  = _deleteStep >= _deleteWarnKeys.length - 1;
                                final yes   = DvOrb.get_shape_by_id("personnage/delete_yes");
                                final no    = DvOrb.get_shape_by_id("personnage/delete_no");
                                await _setDeleteLabel("personnage/delete_panel", _deleteWarnKeys[_deleteStep]);
                                await _setDeleteLabel("personnage/delete_yes",
                                    last ? "delete_account_confirm" : "delete_account_continue");
                                yes?.set("shape.visible", true);
                                yes?.set("shape.events.tap", true);
                                yes?.refreshUI();
                                await _setDeleteLabel("personnage/delete_no", "delete_account_cancel");
                                no?.set("shape.visible", true);
                                no?.set("shape.events.tap", true);
                                no?.refreshUI();
    }

    Future<void> open_delete_account(dynamic caller, dynamic event) async {

                                // Jamais depuis une impersonation (supprimerait le compte de l'admin).
                                if (_impersonating) return;
                                _deleteStep = 0;
                                _setDeleteVisible(true);
                                await _applyDeleteStep();
    }

    Future<void> on_delete_account_cancel(dynamic caller, dynamic event) async {

                                _deleteStep = 0;
                                _setDeleteVisible(false);
    }

    Future<void> on_delete_account_next(dynamic caller, dynamic event) async {

                                if (_deleteStep < _deleteWarnKeys.length - 1) {
                                    _deleteStep++;
                                    await _applyDeleteStep();
                                    return;
                                }
                                await _executeAccountDeletion();
    }

    Future<void> _executeAccountDeletion() async {

                                final yes   = DvOrb.get_shape_by_id("personnage/delete_yes");
                                final no    = DvOrb.get_shape_by_id("personnage/delete_no");
                                // État « en cours » : masque les boutons (anti double-tap) + message d'attente.
                                yes?.set("shape.visible", false); yes?.set("shape.events.tap", false); yes?.refreshUI();
                                no?.set("shape.visible", false);  no?.set("shape.events.tap", false);  no?.refreshUI();
                                await _setDeleteLabel("personnage/delete_panel", "delete_account_working");

                                // ownerId = UID Firebase (garde self-delete côté fonction) ; la fonction le
                                // traduit ensuite en userId métier via userindexes.
                                final ownerId = _cloud?.currentUser()?.providerUid ?? "";
                                if (ownerId.isEmpty) { await _deleteAccountError(); return; }
                                try {
                                    await _cloud?.call("delete_user_data", Dvidle({"ownerId": ownerId}));
                                } catch (e) {
                                    deva_log("error", "[delete_account] appel cloud échoué: $e");
                                    // SEUL REPRÉSENTANT D'UN ENFANT : refus du serveur, et un message qui dit
                                    // quoi faire (ajouter un co-représentant, ou supprimer le compte de l'enfant).
                                    final names = await _soleGuardianNames(e);
                                    if (names.isNotEmpty) {
                                        await _deleteAccountError(key: "delete_account_sole_guardian", name: names);
                                        return;
                                    }
                                    await _deleteAccountError();
                                    return;
                                }

                                deva_log("info", "[delete_account] compte supprimé → déconnexion");
                                // Règle du payeur : l'abonnement payé par ce compte est résilié (son
                                // index vient de passer à enabled=false). ATTENDU, et avant le logout :
                                // la déconnexion retire le jeton dont l'appel a besoin. Ne lève jamais ;
                                // le balayage quotidien rattrape un appel perdu.
                                await _storePayerCheck();
                                // Photos de preuve : delete_user_data ne peut rien sur le disque de l'appareil.
                                // C'est ici, et seulement ici, qu'on a la main dessus — d'où la purge totale
                                // AVANT le logout, pendant que l'app tourne encore. Une suppression demandée
                                // depuis le site laisse la photo jusqu'à la prochaine ouverture de l'app
                                // (_reconcileProofs), ou jusqu'à la désinstallation : cas résiduel assumé.
                                await _reconcileProofs("");
                                // Même chemin que do_reset : nettoyage de la session locale puis logout
                                // (-> on_logout -> reset memoire complet -> navigate_reset("awake")).
                                final region = (await Deva.instance.get("documents.session.cloud_region"))?.toString() ?? "";
                                if (region.isNotEmpty) { try { await _deleteSession(region); } catch (_) {} }
                                await Deva.instance.set("worker.session.clan_done", "");
                                _setDeleteVisible(false);
                                await ActionRegistry.get("dvcloud.do_logout")?.call(null, null);
    }

    Future<void> _deleteAccountError({String key = "delete_account_error", String name = ""}) async {

                                final no    = DvOrb.get_shape_by_id("personnage/delete_no");
                                await _setDeleteLabel("personnage/delete_panel", key);
                                if (name.isNotEmpty) {
                                    final panel = DvOrb.get_shape_by_id("personnage/delete_panel");
                                    if (panel is DvLabel) {
                                        panel.set("shape.label", TranslationRegistry.translate(key).replaceAll("{name}", name));
                                        await panel.computeDisplay();
                                        panel.refreshUI();
                                    }
                                }
                                await _setDeleteLabel("personnage/delete_no", "delete_account_cancel");
                                no?.set("shape.visible", true); no?.set("shape.events.tap", true); no?.refreshUI();
                                _deleteStep = 0;   // "Annuler" referme proprement l'overlay
    }

}

// -----------------------------------------------------------------------------
// --- Let's go
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- To be continued...
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- That's all folks
// -----------------------------------------------------------------------------
