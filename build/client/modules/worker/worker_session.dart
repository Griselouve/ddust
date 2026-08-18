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

                                // Changement de langue (option kebab Personnage) : ouvre le picker
                                // drapeau+nom du module dvlang, ancré sous le bouton kebab.
                                ActionRegistry.register("worker.open_lang_menu",            open_lang_menu);

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

                                ActionRegistry.register("worker.on_rejected_close",         on_rejected_close);

                                ActionRegistry.register("worker.on_account_linked",         on_account_linked);

                                ActionRegistry.register("worker.on_link_failed",            on_link_failed);

                                ActionRegistry.register("worker.on_link_conflict",          on_link_conflict);

                                ActionRegistry.register("worker.on_link_conflict_confirm",  on_link_conflict_confirm);

                                ActionRegistry.register("worker.on_link_conflict_cancel",   on_link_conflict_cancel);

                                ActionRegistry.register("worker.on_link_account_appear",    on_link_account_appear);

    }

    Future<void> on_login(DvShape? caller, dynamic event) async {

                                final user = event is DvCloudUser ? event : null;
                                if (user == null) return;

                                _userId = await _resolveUserId();
                                if (_userId.isEmpty) return;
                                // Ancre l'identité authentifiée (doc `users/`). Toute divergence ultérieure
                                // = impersonation explicite (take_place). Un vrai login repart toujours net :
                                // on force le bandeau d'impersonation masqué (au cas où un store() l'aurait
                                // persisté pendant une session d'impersonation avant un kill).
                                _authUserId    = _userId;
                                _impersonating = false;
                                await _applyImpersonation(false, "");

                                final best = await _findBestSession();
                                // Onboarding anonyme pas encore flushé : la base est vide, il n'y a donc
                                // RIEN à reprendre. Le tampon d'acceptation ne survit pas à un kill, par
                                // choix — une preuve de consentement à demi-écrite n'en est pas une. On
                                // efface l'état local résiduel et on renvoie sur home, seul endroit d'où
                                // l'on peut aussi choisir « Retrouver mon héros ». Une fois le flush passé
                                // (mineur admis dans son clan avant d'avoir lié son compte), la session
                                // existe et le routage nominal ci-dessous reprend la main.
                                if (best == null && _anon) {
                                    await _restartAnonymousOnboarding();
                                    return;
                                }
                                if (best != null) {
                                    final (sessionRegion, session) = best;
                                    _cloud?.configure("region", sessionRegion);
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
                                    // Activate Vertex AI now — cloud.aimodel_regions is available at this point
                                    final _ai = Deva.instance.module("dvvertexai");
                                    if (_ai != null) try { await (_ai as dynamic).startVertexMotor(); } catch (_) {}
                                    await ActionRegistry.get("documents._sync_session")?.call(null, null);
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
                                        // Démarre la musique de thème pour tout utilisateur déjà enrôlé qui (re)lance
                                        // l'app — dashboard ou reprise de tâche. Un joueur mort voit son crâne dès la
                                        // 1re frame (mutation registry persistée) : sa musique doit l'être aussi, d'où
                                        // l'état de vie mémorisé (worker.player_dead) plutôt que `ambiant` en dur.
                                        await _setAmbiance((await deva_get("worker.player_dead")) == true);
                                        await _loadClanTasks(session, sessionRegion);
                                        // Enregistre ce device dans le doc membre clans_players (cible
                                        // FCM) — idempotent : couvre le démarrage de l'app sur un nouveau
                                        // device pour un joueur déjà membre.
                                        await _writeClanPlayer(
                                            session.get("steps.clan.clanId")?.toString()     ?? "",
                                            session.get("steps.clan.clanSecret")?.toString() ?? "",
                                            _userId,
                                            await _cloud?.deviceId() ?? "",
                                            sessionRegion,
                                            // Rétro-remplit original_clan (init-si-null) pour les membres d'avant
                                            // cette feature : miroir de users.first_clan (déjà backfillé en base).
                                            firstClan: session.get("first_clan")?.toString() ?? "",
                                        );
                                        // Bascule légale en cours (tuteur a déclaré le joueur majeur) : le doc porte
                                        // legal_state="t" → on impose la CGU adulte et on saute le dashboard. C'est ce
                                        // qui « relance sur l'étape CGU » après un kill (routage re-dérivé à chaque login).
                                        if (await _checkAdultTransition()) return;
                                        // Compte pas encore lié : mineur admis dans son clan avant la liaison,
                                        // ou reprise après un kill sur l'écran de liaison. Bloquant, sans
                                        // « plus tard » — c'est ce qui rend l'étape reprise-après-kill.
                                        if (_anon) { await _requireAccountLink(); return; }
                                        // Arme la vigilance temps réel du doc joueur dès la reprise à froid (avant
                                        // même le dashboard) : la montée de niveau sera détectée où que soit le joueur.
                                        _startPlayerVigilance(
                                            session.get("steps.clan.clanId")?.toString()     ?? "",
                                            session.get("steps.clan.clanSecret")?.toString() ?? "",
                                            sessionRegion,
                                        );
                                        // Et on regarde tout de suite si le clan attendait ce joueur : la cérémonie
                                        // a pu être appelée pendant que l'app était fermée, et rien n'émet de
                                        // changement pour ce qui était déjà là avant l'abonnement.
                                        _checkPendingCeremony();   // fire-and-forget : le démarrage n'attend personne
                                        // Restaure le contexte de la tâche en cours dans la session locale, sans
                                        // rediriger vers combat : on démarre toujours sur le dashboard. L'écran
                                        // combat (on_combat_appear) lira session.active_task quand l'utilisateur
                                        // l'ouvrira via la taskbar.
                                        final activeTask = session.get("active_task")?.toString() ?? "";
                                        if (activeTask.isNotEmpty) {
                                            final clanId = session.get("steps.clan.clanId")?.toString() ?? "";
                                            if (clanId.isNotEmpty) await Deva.instance.set("session.clan.id", clanId);
                                            await Deva.instance.set("session.active_task", activeTask);
                                            // Tâche en attente de validation au redémarrage (preuve déposée) → on
                                            // relance la vigilance : le watch en mémoire a été perdu au kill.
                                            final activeProof = session.get("active_proof")?.toString() ?? "";
                                            final clanSecret  = session.get("steps.clan.clanSecret")?.toString() ?? "";
                                            if (activeProof.isNotEmpty && clanId.isNotEmpty && clanSecret.isNotEmpty) {
                                                await Deva.instance.set("session.active_proof", activeProof);
                                                _startValidationPolling(clanId, clanSecret, sessionRegion,
                                                    _taskIdFromActive(activeTask, clanId));
                                            }
                                        }
                                        // Lien d'invitation reçu avant l'authentification (cold start).
                                        final pendingGroup = (await deva_get("worker.pending_group_id"))?.toString() ?? "";
                                        if (pendingGroup.isNotEmpty) {
                                            final pendingLobby = (await deva_get("worker.pending_lobby_id"))?.toString() ?? "";
                                            // Consommé : sans ce reset, une adhésion déjà acceptée est rejouée à
                                            // chaque démarrage à froid (la submission n'accepte plus l'écriture).
                                            await deva_set("worker.pending_group_id", "");
                                            await deva_set("worker.pending_lobby_id", "");
                                            ActionRegistry.get("virtuallobby.accept_invitation")?.call(null, {
                                                "group_id": pendingGroup,
                                                "lobby_id": pendingLobby,
                                            });
                                        } else {
                                            // Lien PIN reçu avant l'auth (cold start) : écran de saisie, token pré-rempli.
                                            final pendingToken = (await deva_get("worker.pending_invite_token_in"))?.toString() ?? "";
                                            if (pendingToken.isNotEmpty) {
                                                DvOrb.navigate_new("enter_invite_pin");
                                                final tokenShape = await DvOrb.wait_for_shape("enter_invite_pin/token");
                                                tokenShape
                                                    ?..set("shape.value", pendingToken)
                                                    ..refreshUI();
                                                return;
                                            }
                                        }
                                        // Nom pas encore choisi : il est demandé APRÈS la liaison du compte,
                                        // pour tout le monde. Placé ici, tout en fin de branche, pour que la
                                        // vigilance du joueur et les cérémonies en attente soient déjà armées
                                        // quand on détourne vers l'écran de nom. C'est aussi ce passage qui
                                        // libère l'annonce d'arrivée dans le clan (cf. _flushPendingMemberJoined).
                                        if (session.get("steps.name") == null) {
                                            await ActionRegistry.get("steps.navigate.player_name")?.call(caller, event);
                                            return;
                                        }
                                        await ActionRegistry.get("steps.navigate.dashboard")?.call(caller, event);
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
                                    if (_anon) {
                                        // Mineur déjà flushé mais pas encore admis (il a quitté l'app en
                                        // attendant que le chef accepte) : il reprend sa demande d'entrée.
                                        // Le link ne lui est réclamé qu'APRÈS l'admission — avant, il n'a
                                        // rien à protéger et l'écran de liaison le bloquerait pour rien.
                                        if (_gameplayLegal(legalState) == "k") {
                                            await ActionRegistry.get("steps.navigate.join")?.call(caller, event);
                                            return;
                                        }
                                        await _requireAccountLink();
                                        return;
                                    }
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
                                    final regionValue = partialSession.get("steps.region_intro.result")?.toString() ?? partialRegion;
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
                                await ActionRegistry.get("steps.navigate.region")?.call(caller, event);
    }

    Future<void> on_documents_ready(DvShape? caller, dynamic event) async {

                                final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                _cloud?.configure("region", region);
                                // Session anonyme : on n'écrit RIEN. L'index, les steps et l'enregistrement
                                // du device partent d'un bloc au flush (_flushOnboarding), une fois le
                                // compte Google lié — ou, pour un mineur, à l'entrée dans le flux de
                                // jointure de clan, premier moment où une écriture devient nécessaire.
                                if (!_anon && region.isNotEmpty) {
                                    await _messaging?.msgregister('global');
                                    final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                    if (firebaseUid.isNotEmpty && _userId.isNotEmpty) {
                                        try {
                                            await _cloud?.write("workers", "userindexes", firebaseUid,
                                                Dvidle({"ownerId": firebaseUid, "userId": _userId, "enabled": true}), region: region);
                                        } catch (e) {
                                            deva_log("error", "[worker] on_documents_ready: userindexes write FAILED: $e");
                                        }
                                    }
                                    final legalState = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "a";
                                    await _writeStep(region, "region",      region);
                                    await _writeStep(region, "legal_state", legalState);
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
                                    final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
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
                                        }
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

                                final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                // Anonyme : ni le step cgu, ni Vertex. Le step part au flush ; Vertex a
                                // besoin des secrets, que dvcloud refuse volontairement de charger pour une
                                // session anonyme — il démarrera au prochain on_login, une fois le compte lié.
                                if (!_anon) {
                                    if (region.isNotEmpty) await _writeStep(region, "cgu", "accepted");
                                    final _ai = Deva.instance.module("dvvertexai");
                                    if (_ai != null) try { await (_ai as dynamic).startVertexMotor(); } catch (_) {}
                                }
                                final legalState = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "";
                                await Deva.instance.set("worker.session.create_clan_disabled", _gameplayLegal(legalState) == "k" ? "true" : "");
                                await ActionRegistry.get("steps.navigate")?.call(caller, event);
    }

    Future<void> on_region_screen_done(DvShape? caller, dynamic event) async {

                                final region = (event?.toString()?.isNotEmpty == true)
                                    ? event.toString()
                                    : (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                if (region.isEmpty) return;
                                // Anonyme : le choix du royaume ne crée plus le doc `users`. Il vit dans
                                // documents.session.region et sera inscrit au flush avec le reste.
                                if (!_anon) await _writeStep(region, "region_intro", region);
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
                                    final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                    if (region.isNotEmpty) {
                                        final session = await _readSession(region);
                                        final clanId  = session?.get("steps.clan.clanId")?.toString() ?? "";
                                        if (clanId.isNotEmpty) {
                                            // Enrôlé mais sans nom : cas d'un mineur admis dont la saisie a été
                                            // interrompue. On le renvoie la finir plutôt qu'au dashboard.
                                            return session?.get("steps.name") == null ? "player_name" : "dashboard";
                                        }
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
                                _stopValidationPolling();
                                _stopPlayerVigilance();
                                _resetOpening();
                                _userId      = "";
                                _authUserId  = "";
                                _impersonating = false;
                                // Repli sûr : purge le cache admin (sinon un compte réouvert sur le même appareil
                                // hériterait du statut admin du précédent utilisateur).
                                _isAdmin = false; _adminCount = 0; _isAdminClanId = ""; _isAdminUserId = "";
                                // Même repli pour le mode chef. Le vocabulaire du tiroir est STATIQUE au framework :
                                // sans cette remise à zéro, le joueur suivant sur l'appareil hériterait du
                                // vocabulaire admin (ni assigned ni dead ne griseraient, tout serait cliquable).
                                _adminMode = false;
                                _gameDomains.clear();   // l'arbre de décision du compte suivant n'est pas le nôtre
                                _declareTiroirVocabulary();
                                await _syncChiefUi();
                                await Deva.instance.set("worker.session.clan_done", "");
                                if (DvOrb.get_current_page()?.dvid != "home") {
                                    DvOrb.navigate_reset("home");
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

    // Compte refusé : 'not_found' (l'entrée Auth vient d'être supprimée) ou 'error'
    // (rien n'a été touché, on peut réessayer). Overlay, jamais de popup modale.
    Future<void> on_account_rejected(DvShape? caller, dynamic event) async {

                                final reason = event?.toString() ?? "error";
                                if (DvOrb.get_current_page()?.dvid != "home") DvOrb.navigate_reset("home");
                                await DvOrb.wait_for_shape("home/rejected_text");
                                DvOrb.get_shape_by_id("home/rejected_scrim")?..set("shape.visible", true)..refreshUI();
                                await _revealLabel("home/rejected_text",
                                    reason == "not_found" ? "link_no_account_found" : "link_check_failed");
                                DvOrb.get_shape_by_id("home/rejected_close")?..set("shape.visible", true)..refreshUI();
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

    Future<void> on_link_account_appear(DvShape? caller, dynamic event) async {

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

    Future<void> on_link_failed(DvShape? caller, dynamic event) async {

                                deva_log("warning", "[worker] link échoué: ${event?.toString() ?? ""}");
                                await _revealLabel("link_account/error", "link_failed");
    }

    // Conflit : le compte Google visé porte déjà un héros.
    //
    // ADULTE — rien n'a été écrit sous l'uid anonyme (on est avant le flush), donc on peut
    // proposer d'adopter le compte existant : c'est sans perte et sans migration.
    // MINEUR — il est déjà dans un clan, des documents existent sous son uid anonyme. On
    // BLOQUE. Surtout pas de suppression : s'il était seul chef de son clan, la cascade
    // dissoudrait le clan et mettrait tous ses membres en tombstone — des données de tiers.
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
    // consentement, d'un seul tenant. Deux appelants — la liaison du compte Google
    // (adulte) et l'entrée dans le flux de jointure de clan (mineur, qui a besoin d'un
    // uid pour dialoguer avec le lobby). Idempotente : rejouable telle quelle.
    //
    // Rend false sans avoir tout écrit dès qu'une étape échoue. L'appelant ne doit alors
    // PAS poursuivre : atteindre new_or_pick_clan sans userindexes ferait échouer la
    // création de clan au niveau des règles Firestore, panne bien plus tardive et bien
    // plus obscure que le message ré-essayable affiché à cet instant.
    Future<bool> _flushOnboarding() async {

                                final region      = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                final legalState  = (await Deva.instance.get("documents.session.legalstate"))?.toString() ?? "";
                                final firebaseUid = _cloud?.currentUser()?.providerUid ?? "";
                                final docId       = _sessionDocId();
                                if (region.isEmpty || legalState.isEmpty || firebaseUid.isEmpty || docId.isEmpty) {
                                    deva_log("error", "[worker] _flushOnboarding: état incomplet "
                                        "(region='$region' legal='$legalState' uid=${firebaseUid.isNotEmpty} docId=${docId.isNotEmpty}) → rien n'est écrit");
                                    return false;
                                }
                                _cloud?.configure("region", region);

                                // Garde d'intégrité : pas de compte « accepté » sans preuve à écrire. Le
                                // seul rejeu légitime est celui d'un flush déjà passé (mineur), reconnaissable
                                // à un doc users portant déjà steps.cgu.
                                final existing = await _readSession(region) ?? Dvidle({});
                                final dvdocs   = ModuleRegistry.create("documents");
                                final pending  = dvdocs != null && ((dvdocs as dynamic).hasPendingAcceptance as bool? ?? false);
                                if (!pending && existing.get("steps.cgu") == null) {
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
                                    final steps = {
                                        "region_intro": region,
                                        "region":       region,
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
                                bool docsOk = false;
                                if (dvdocs != null) {
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

    // Efface tout l'état local d'un onboarding anonyme qui n'a pas abouti.
    //
    // La destination dépend de ce qu'on trouve : un RÉSIDU (un royaume déjà choisi) signe
    // une session interrompue puis restaurée — on renvoie à l'accueil, d'où le joueur peut
    // aussi bien recommencer que se raviser et revendiquer un compte existant. Rien du
    // tout, c'est le tap qui vient d'ouvrir la session : on entre directement dans
    // l'onboarding, sans renvoyer l'utilisateur sur le bouton qu'il vient de presser.
    //
    // [navigate] false quand l'appelant enchaîne sur sa propre destination (adoption d'un
    // compte existant, qui se termine par son on_login).
    Future<void> _restartAnonymousOnboarding({bool navigate = true}) async {

                                final residue = ((await Deva.instance.get("documents.session.region"))?.toString() ?? "").isNotEmpty;

                                final dvdocs = ModuleRegistry.create("documents");
                                if (dvdocs != null) {
                                    try { await (dvdocs as dynamic).resetLocalSession(); } catch (_) {}
                                }
                                await Deva.instance.set("worker.session.clan_done",            "");
                                await Deva.instance.set("worker.session.create_clan_disabled", "");
                                await Deva.instance.set("worker.pending_member_joined",        null);
                                await Deva.instance.set("worker.pending_clan_welcome",         "");
                                await Deva.instance.set("session.user.name",                   "");
                                await Deva.instance.store();
                                if (!navigate) return;
                                if (residue) {
                                    deva_log("info", "[worker] onboarding anonyme interrompu → retour à l'accueil");
                                    DvOrb.navigate_reset("home");
                                } else {
                                    deva_log("info", "[worker] session anonyme ouverte → entrée dans l'onboarding");
                                    await ActionRegistry.get("steps.navigate.region")?.call(null, null);
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
                                        // Effacement deep-merge : poser le champ à "" (convention dvcloud).
                                        final wipe = Dvidle({});
                                        wipe.set("steps",        "");
                                        wipe.set("clans",        "");
                                        wipe.set("first_clan",   "");
                                        wipe.set("last_clan",    "");
                                        wipe.set("active_task",  "");
                                        wipe.set("active_proof", "");
                                        await _cloud?.write("workers", "users", docId, wipe, region: region);
                                        _invalidateSessionCache();
                                        deva_log("info", "[worker] compte réactivé : session '$region' remise à zéro");
                                    } catch (e) {
                                        deva_log("error", "[worker] _resetDisabledSession('$region') FAILED: $e");
                                    }
                                }
    }

    Future<void> do_reset(DvShape? caller, dynamic event) async {

                                final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
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
                                        recipes: ['{19943852-4271-468B-8781-77B0B3087774}', 'BP2A.250605.015'],
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
                                        recipes: ['{19943852-4271-468B-8781-77B0B3087774}', 'BP2A.250605.015'],
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
    Future<List<String>> perso_settings_selector(dynamic caller, dynamic data) async {

                                final options = <String>["my_log", "tutorials", "change_lang"];
                                if (!_impersonating) options.add("delete_account");
                                options.add("logout");
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
                                    await _deleteAccountError();
                                    return;
                                }

                                deva_log("info", "[delete_account] compte supprimé → déconnexion");
                                // Même chemin que do_reset : nettoyage de la session locale puis logout
                                // (→ on_logout → reset mémoire complet → navigate_reset("home")).
                                final region = (await Deva.instance.get("documents.session.region"))?.toString() ?? "";
                                if (region.isNotEmpty) { try { await _deleteSession(region); } catch (_) {} }
                                await Deva.instance.set("worker.session.clan_done", "");
                                _setDeleteVisible(false);
                                await ActionRegistry.get("dvcloud.do_logout")?.call(null, null);
    }

    Future<void> _deleteAccountError() async {

                                final no    = DvOrb.get_shape_by_id("personnage/delete_no");
                                await _setDeleteLabel("personnage/delete_panel", "delete_account_error");
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
