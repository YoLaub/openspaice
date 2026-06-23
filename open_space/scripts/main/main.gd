extends Node
## Scène racine. Démarre l'open space et, sur demande en ligne de commande,
## échantillonne la perf (--measure-fps, AC#3 / NFR1), valide la simulation
## d'agents de bout en bout (--sim-smoke), ou valide le contrôle du temps
## (--time-smoke, Story 1.3 : pause gèle la journée, x3 l'accélère ~3x) puis quitte.

const _FPS_SAMPLE_DELAY: float = 3.0  # laisse le rendu se stabiliser avant mesure

# --- Harnais de fumée de la simulation (--sim-smoke) ---
const _SMOKE_DAY_DURATION: float = 30.0  # journée accélérée mais réaliste (marge de départ)
const _SMOKE_RUN_SECONDS: float = 36.0   # > 1 journée complète (spawn → travail → départ)
const _SMOKE_SAMPLE_INTERVAL: float = 0.1
const _SMOKE_MIN_DISPLACEMENT: float = 2.0  # un agent doit s'éloigner de l'entrée

# --- Harnais de fumée du contrôle du temps (--time-smoke, Story 1.3) ---
const _TIME_SMOKE_DAY_DURATION: float = 60.0  # assez long pour mesurer sans wrap
const _TIME_SMOKE_WINDOW: float = 1.2         # fenêtre de mesure (s RÉELLES) — large pour
                                              # lisser la quantification des ticks (~3 Hz)

var _spawned: int = 0
var _departed: int = 0
var _max_displacement: float = 0.0

# --- Compteurs du harnais de sollicitations (--solicitation-smoke, Story 1.4) ---
# MEMBRES (pas locaux) : les lambdas GDScript capturent les locaux par VALEUR ;
# seuls les membres (via self) s'incrémentent réellement depuis un signal.
var _sol_raised_desk: int = 0
var _sol_raised_mail: int = 0
var _sol_opened: int = 0

# --- Compteur du harnais de décisions (--decision-smoke, Story 1.5) ---
# MEMBRE (pas local) : capturé par self → réellement incrémenté depuis le signal.
var _decisions_chosen: int = 0

# --- Compteurs du harnais de résolution (--resolution-smoke, Story 1.6) ---
# MEMBRES (capture par self) : un local serait capturé par valeur → jamais mis à jour.
var _resolved_count: int = 0
var _last_resolved_outcome: int = -999
var _committed_outcome: int = -999

func _ready() -> void:
	Log.info("OpenSpAIce — démarrage")
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	if args.has("--measure-fps"):
		_measure_fps_and_quit()
	elif args.has("--sim-smoke"):
		_run_sim_smoke_and_quit()
	elif args.has("--time-smoke"):
		_run_time_smoke_and_quit()
	elif args.has("--solicitation-smoke"):
		_run_solicitation_smoke_and_quit()
	elif args.has("--decision-smoke"):
		_run_decision_smoke_and_quit()
	elif args.has("--resolution-smoke"):
		_run_resolution_smoke_and_quit()
	elif args.has("--queue-smoke"):
		_run_queue_smoke_and_quit()
	elif args.has("--hud-smoke"):
		_run_hud_smoke_and_quit()
	elif args.has("--card-smoke"):
		_run_card_smoke_and_quit()
	elif args.has("--report-smoke"):
		_run_report_smoke_and_quit()
	elif args.has("--fatigue-smoke"):
		_run_fatigue_smoke_and_quit()

func _measure_fps_and_quit() -> void:
	# Mesure de capacité brute : vsync OFF + FPS décapé, fenêtre au premier plan.
	# (En jeu réel, le vsync reste actif ; ici on veut le débit max réel du GPU.)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DisplayServer.window_move_to_foreground()
	Log.info("Rendu via : %s (%s)" % [
		RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_type()
	])
	await get_tree().create_timer(_FPS_SAMPLE_DELAY).timeout
	var fps: int = roundi(Engine.get_frames_per_second())
	Log.info("Mesure FPS (open space peuplé, vsync off) : %d" % fps)
	print("FPS_MEASUREMENT=%d" % fps)
	get_tree().quit(0 if fps >= 60 else 1)

## Test d'intégration headless : laisse tourner la vraie simulation (journée
## accélérée), et vérifie que des agents apparaissent (spawn), se déplacent
## (pathfinding) et repartent (cycle de journée).
func _run_sim_smoke_and_quit() -> void:
	# Accélère la journée (GameManager possède la durée active du jour).
	GameManager.day_duration_seconds = _SMOKE_DAY_DURATION

	EventBus.agent_spawned.connect(func(_id: int) -> void: _spawned += 1)
	EventBus.agent_departed.connect(func(_id: int) -> void: _departed += 1)

	var open_space: Node3D = $OpenSpace
	var entrance: Vector3 = open_space.entrance_world()
	var agents_root: Node3D = open_space.get_node("Agents")

	var elapsed: float = 0.0
	while elapsed < _SMOKE_RUN_SECONDS:
		await get_tree().create_timer(_SMOKE_SAMPLE_INTERVAL).timeout
		elapsed += _SMOKE_SAMPLE_INTERVAL
		for agent: Node in agents_root.get_children():
			if agent is Node3D:
				var flat: Vector3 = (agent as Node3D).global_position - entrance
				flat.y = 0.0
				_max_displacement = maxf(_max_displacement, flat.length())

	var moved_ok: bool = _max_displacement >= _SMOKE_MIN_DISPLACEMENT
	Log.info("Sim smoke — spawn:%d depart:%d déplacement_max:%.2f m" % [
		_spawned, _departed, _max_displacement])
	print("SIM_SMOKE spawned=%d departed=%d max_disp=%.2f" % [
		_spawned, _departed, _max_displacement])
	var ok: bool = _spawned >= 5 and _departed >= 5 and moved_ok
	print("SIM_SMOKE_RESULT=%s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Test d'intégration headless du contrôle du temps (Story 1.3) :
##  (a) en PAUSE, la phase de journée ne doit PAS avancer ;
##  (b) à x3, la phase doit avancer nettement plus vite qu'à x1.
## L'input clavier est peu fiable en headless → on pilote via l'API GameManager
## (toggle_pause/set_speed), qui est exactement ce que l'input déclenche en jeu.
func _run_time_smoke_and_quit() -> void:
	GameManager.day_duration_seconds = _TIME_SMOKE_DAY_DURATION
	# Laisse la 1re journée s'amorcer (1er simulation_tick → day_started).
	GameManager.set_speed(1)
	await _real_wait(0.3)

	# (b) Avance à x1.
	var p0: float = GameManager.day_phase
	await _real_wait(_TIME_SMOKE_WINDOW)
	var adv_x1: float = GameManager.day_phase - p0

	# (b) Avance à x3 (même fenêtre réelle).
	GameManager.set_speed(3)
	var p1: float = GameManager.day_phase
	await _real_wait(_TIME_SMOKE_WINDOW)
	var adv_x3: float = GameManager.day_phase - p1

	# (a) En pause : la phase doit rester figée.
	GameManager.set_speed(1)
	GameManager.set_paused(true)
	var p2: float = GameManager.day_phase
	await _real_wait(_TIME_SMOKE_WINDOW)
	var adv_paused: float = GameManager.day_phase - p2
	GameManager.set_paused(false)

	# (c) AC#3 + Story 1.10 (flux GATÉ) : une journée qui se termine émet day_ended et
	# GÈLE la sim (SimClock.stop) — la journée suivante NE démarre PLUS automatiquement.
	# Elle ne démarre que sur validation du bilan (GameManager.start_next_day()).
	var ended_days: Array[int] = []
	EventBus.day_ended.connect(func(d: int) -> void: ended_days.append(d))
	var day_before: int = GameManager.day_count
	GameManager.day_duration_seconds = 1.0  # journée ultra-courte → wrap garanti
	GameManager.set_speed(3)
	await _real_wait(2.0)  # couvre ≥ 1 bouclage de journée → day_ended + gel

	# Après le wrap : la sim est gelée, le jour suivant N'a PAS démarré tout seul,
	# et il n'y a eu qu'UN seul wrap (SimClock arrêté → plus de bouclage).
	var gated_ok: bool = GameManager.is_awaiting_day_review() \
		and GameManager.day_count == day_before and ended_days.size() == 1
	# Validation du bilan → la journée suivante démarre (day_count avance).
	GameManager.start_next_day()
	var advanced_ok: bool = GameManager.day_count == day_before + 1 \
		and not GameManager.is_awaiting_day_review()

	# Restaure un état neutre AVANT de laisser respirer (sinon, à x3 + journée de 1 s,
	# un 2e wrap surviendrait pendant l'attente). Journée longue → pas de re-bouclage.
	GameManager.day_duration_seconds = _TIME_SMOKE_DAY_DURATION
	GameManager.set_speed(1)
	Engine.time_scale = 1.0
	# Laisse les agents fraîchement spawnés s'initialiser avant de quitter (sinon des
	# nœuds créés au dernier instant sont signalés "non libérés" au shutdown headless).
	await _real_wait(0.5)

	var paused_ok: bool = absf(adv_paused) < 0.0001
	# Tolérance large (≥1.5x) : x3 fait avancer ~3x plus de ticks que x1 sur la même
	# fenêtre réelle ; on garde une marge confortable contre la quantification (±1 tick).
	var speed_ok: bool = adv_x1 > 0.0 and adv_x3 > adv_x1 * 1.5
	var cycle_ok: bool = ended_days.size() == 1 and gated_ok and advanced_ok
	Log.info("Time smoke — adv_x1:%.5f adv_x3:%.5f adv_pause:%.5f day_ended:%d gated:%s advanced:%s" % [
		adv_x1, adv_x3, adv_paused, ended_days.size(), gated_ok, advanced_ok])
	print("TIME_SMOKE adv_x1=%.5f adv_x3=%.5f adv_pause=%.5f day_ended=%d gated=%s advanced=%s day_count=%d" % [
		adv_x1, adv_x3, adv_paused, ended_days.size(), gated_ok, advanced_ok, GameManager.day_count])
	var ok: bool = paused_ok and speed_ok and cycle_ok
	print("TIME_SMOKE_RESULT=%s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Test d'intégration headless des sollicitations (Story 1.4) :
##  (a) canal DESK → au moins une sollicitation bureau émise + l'agent se RAPPROCHE
##      du bureau du joueur (déplacement mesuré) ;
##  (b) canal MAIL → au moins une sollicitation mail émise SANS déplacer l'agent ;
##  (c) open_solicitation() émet solicitation_opened et VIDE l'état actif.
## On force le canal via desk_channel_probability (1.0 puis 0.0) pour exercer les deux
## chemins de façon déterministe, et un taux élevé pour déclencher vite. L'injection
## souris étant peu fiable en headless, on appelle open_solicitation() directement
## (exactement ce que le clic déclenche en jeu — cf. SelectionController).
func _run_solicitation_smoke_and_quit() -> void:
	GameManager.day_duration_seconds = 600.0  # journée longue → pas de wrap pendant le test

	var open_space: Node3D = $OpenSpace
	var desk: Vector3 = open_space.desk_world()
	var agents_root: Node3D = open_space.get_node("Agents")
	var solicitations: Node = open_space.get_node("SolicitationSystem")

	# Compteurs via MEMBRES (capture par self → réellement incrémentés depuis le signal).
	EventBus.solicitation_raised.connect(func(_id: int, channel: int) -> void:
		if channel == 0: _sol_raised_desk += 1
		else: _sol_raised_mail += 1)
	EventBus.solicitation_opened.connect(func(_id: int, _channel: int) -> void: _sol_opened += 1)

	# Pas de sollicitation pendant l'arrivée des agents (sinon non éligibles).
	solicitations.rate_override = 0.0
	GameManager.set_speed(3)
	await _real_wait(4.0)

	# (a) Canal BUREAU forcé : distance min agent↔bureau AVANT, puis on déclenche.
	var dist_before: float = _min_agent_distance_to(agents_root, desk)
	solicitations.desk_prob_override = 1.0
	solicitations.rate_override = 1.0  # tout agent éligible sollicite dès le 1er tick
	await _real_wait(1.0)
	solicitations.rate_override = 0.0  # stoppe de nouvelles sollicitations
	await _real_wait(3.0)               # laisse l'agent marcher vers le bureau
	var dist_after_desk: float = _min_agent_distance_to(agents_root, desk)
	var moved_to_desk: bool = dist_after_desk < dist_before - 1.0

	# (c) Ouvre une sollicitation bureau active → doit émettre opened + vider l'état.
	var opened_ok: bool = false
	for node: Node in agents_root.get_children():
		if node is Agent and solicitations.has_active_solicitation((node as Agent).agent_id):
			var before: int = _sol_opened
			var ok: bool = solicitations.open_solicitation((node as Agent).agent_id)
			opened_ok = ok and _sol_opened == before + 1 \
				and not solicitations.has_active_solicitation((node as Agent).agent_id) \
				and not (node as Agent).has_open_solicitation()
			break

	# (b) Canal MAIL forcé : un agent redevenu éligible lève un mail, sans bouger.
	await _real_wait(2.0)  # laisse les agents bureau revenir à leur poste / retravailler
	solicitations.desk_prob_override = 0.0
	solicitations.rate_override = 1.0
	await _real_wait(1.5)

	# Restaure les overrides (→ valeurs .tres) et un état temporel neutre.
	solicitations.rate_override = -1.0
	solicitations.desk_prob_override = -1.0
	GameManager.set_speed(1)
	Engine.time_scale = 1.0

	var ok_all: bool = _sol_raised_desk >= 1 and _sol_raised_mail >= 1 and moved_to_desk and opened_ok
	Log.info("Solicitation smoke — desk:%d mail:%d moved:%s opened_ok:%s (d_before:%.2f d_after:%.2f)" % [
		_sol_raised_desk, _sol_raised_mail, moved_to_desk, opened_ok, dist_before, dist_after_desk])
	print("SOLICITATION_SMOKE raised_desk=%d raised_mail=%d moved_to_desk=%s opened=%d opened_ok=%s" % [
		_sol_raised_desk, _sol_raised_mail, moved_to_desk, _sol_opened, opened_ok])
	print("SOLICITATION_SMOKE_RESULT=%s" % ("PASS" if ok_all else "FAIL"))
	get_tree().quit(0 if ok_all else 1)

## Test d'intégration headless de la pop-up de décision (Story 1.5) :
##  (a) ouvrir une sollicitation (→ EventBus.solicitation_opened) AFFICHE la pop-up
##      avec 2-3 boutons d'options ;
##  (b) la pop-up ouverte ne fige PAS le temps (la phase de journée avance, jeu non en pause) ;
##  (c) choose_option(0) émet decision_chosen ET referme la pop-up ;
##  (d) interactivité en PAUSE : la racine est PROCESS_MODE_ALWAYS et le choix
##      fonctionne le jeu gelé (choose_option = point d'entrée commun clic/test, l'injection
##      de clic GUI étant peu fiable en headless — cf. SelectionController / 1.4).
func _run_decision_smoke_and_quit() -> void:
	GameManager.day_duration_seconds = 600.0  # journée longue → pas de wrap pendant le test

	var open_space: Node3D = $OpenSpace
	var agents_root: Node3D = open_space.get_node("Agents")
	var solicitations: Node = open_space.get_node("SolicitationSystem")
	var popup: CanvasLayer = open_space.get_node("DecisionPopup")

	# Compteur via MEMBRE (capture par self → réellement incrémenté depuis le signal).
	EventBus.decision_chosen.connect(func(_did: int, _idx: int) -> void: _decisions_chosen += 1)

	# Laisser les agents arriver à leur poste, sans sollicitation.
	solicitations.rate_override = 0.0
	GameManager.set_speed(3)
	await _real_wait(4.0)

	# (a) Forcer une sollicitation BUREAU puis l'OUVRIR → solicitation_opened → pop-up.
	await _force_desk_solicitation(solicitations)
	_open_first_active(agents_root, solicitations)
	var shown_ok: bool = popup.is_showing()
	var options_n: int = popup.option_button_count()
	var options_ok: bool = options_n >= 2 and options_n <= 3

	# (b) Le temps continue de tourner pendant que la pop-up est ouverte (jeu non en pause).
	var phase_before: float = GameManager.day_phase
	await _real_wait(1.0)
	var advanced: float = GameManager.day_phase - phase_before
	var time_running_ok: bool = advanced > 0.0

	# (c)+(e) Choix + FIFO : ouvrir une 2e sollicitation pendant l'affichage → mise en file
	# (anti-perte, Story 1.5 Task 5) ; choisir referme la 1re ET dépile la 2e ; un 2e choix vide.
	_open_first_active(agents_root, solicitations)  # 2e sollicitation → enfilée (pop-up déjà ouverte)
	var queued_kept_showing: bool = popup.is_showing()  # toujours la 1re (pas remplacée)
	var chosen_before: int = _decisions_chosen
	popup.choose_option(0)                              # ferme la 1re → dépile la 2e
	var fifo_advanced: bool = popup.is_showing()        # la 2e s'affiche
	popup.choose_option(0)                              # ferme la 2e
	var chosen_ok: bool = _decisions_chosen == chosen_before + 2 and not popup.is_showing()

	# (d) Interactivité en PAUSE : process_mode ALWAYS + le choix fonctionne le jeu gelé.
	var always_ok: bool = popup.process_mode == Node.PROCESS_MODE_ALWAYS
	await _force_desk_solicitation(solicitations)
	_open_first_active(agents_root, solicitations)
	var shown2: bool = popup.is_showing()
	GameManager.set_paused(true)
	popup.choose_option(0)
	var pause_ok: bool = shown2 and not popup.is_showing()
	GameManager.set_paused(false)

	# Restaure les overrides (→ valeurs .tres) et un état temporel neutre.
	solicitations.rate_override = -1.0
	solicitations.desk_prob_override = -1.0
	GameManager.set_speed(1)
	Engine.time_scale = 1.0

	var ok_all: bool = shown_ok and options_ok and time_running_ok and chosen_ok \
		and queued_kept_showing and fifo_advanced and always_ok and pause_ok
	Log.info("Decision smoke — shown:%s options:%d advanced:%.5f chosen:%d fifo:%s pause_ok:%s" % [
		shown_ok, options_n, advanced, _decisions_chosen, fifo_advanced, pause_ok])
	print("DECISION_SMOKE shown=%s options=%d advanced=%.5f chosen=%d closed=%s fifo=%s pause_ok=%s" % [
		shown_ok, options_n, advanced, _decisions_chosen, chosen_ok, fifo_advanced, pause_ok])
	print("DECISION_SMOKE_RESULT=%s" % ("PASS" if ok_all else "FAIL"))
	get_tree().quit(0 if ok_all else 1)

## Test d'intégration headless de la résolution immédiate/différée (Story 1.6) :
##  (a) IMMÉDIAT (override prob = 1.0) : choisir une option résout TOUT DE SUITE
##      (decision_resolved émis dans le même tour), avec l'outcome de l'option choisie ;
##  (b) DIFFÉRÉ (override prob = 0.0) + ANTI SAVE-SCUM (NFR9) : choisir NE résout PAS
##      tout de suite (rien d'émis, 1 décision en attente) ; après franchissement de
##      l'échéance (1-2 jours, journée accélérée), decision_resolved est émis avec le bon
##      outcome, et la file des différés se vide.
## On force le classement via DecisionResolver.immediate_prob_override (déterministe) et on
## passe par choose_option() (point d'entrée commun clic/test, cf. 1.5). Les compteurs sont
## des MEMBRES (piège des lambdas : capture par valeur sur des locaux).
func _run_resolution_smoke_and_quit() -> void:
	GameManager.day_duration_seconds = 600.0  # stable (pas de wrap) pendant (a) et le choix (b)

	var open_space: Node3D = $OpenSpace
	var agents_root: Node3D = open_space.get_node("Agents")
	var solicitations: Node = open_space.get_node("SolicitationSystem")
	var popup: CanvasLayer = open_space.get_node("DecisionPopup")
	var resolver: Node = open_space.get_node("DecisionResolver")

	# Capture via MEMBRES (self). decision_committed porte l'outcome publié par la pop-up ;
	# decision_resolved est émis par le résolveur (immédiat ou à l'échéance).
	EventBus.decision_committed.connect(func(_did: int, outcome: int) -> void:
		_committed_outcome = outcome)
	EventBus.decision_resolved.connect(func(_did: int, outcome: int) -> void:
		_resolved_count += 1
		_last_resolved_outcome = outcome)

	# Laisser les agents arriver à leur poste, sans sollicitation.
	solicitations.rate_override = 0.0
	GameManager.set_speed(3)
	await _real_wait(4.0)

	# (a) IMMÉDIAT : forcer prob = 1.0 → résolution dans le même tour que le choix.
	resolver.immediate_prob_override = 1.0
	await _force_desk_solicitation(solicitations)
	_open_first_active(agents_root, solicitations)
	var shown_a: bool = popup.is_showing()
	var resolved_before_a: int = _resolved_count
	popup.choose_option(0)
	var immediate_ok: bool = _resolved_count == resolved_before_a + 1 \
		and _committed_outcome != 0 and _last_resolved_outcome == _committed_outcome

	# (b) DIFFÉRÉ : forcer prob = 0.0 → mise en attente, rien de résolu tout de suite.
	resolver.immediate_prob_override = 0.0
	await _force_desk_solicitation(solicitations)
	_open_first_active(agents_root, solicitations)
	var resolved_before_b: int = _resolved_count
	popup.choose_option(0)
	var committed_b: int = _committed_outcome
	# Anti save-scum : aucune émission immédiate + exactement une décision en attente.
	var deferred_held: bool = _resolved_count == resolved_before_b \
		and resolver.pending_count() >= 1

	# Franchir l'échéance (delay 1-2 j) : journée ultra-courte + x3. Story 1.10 : la
	# journée suivante ne démarre PLUS toute seule (gel au day_ended) ; on ENCHAÎNE les
	# jours via GameManager.start_next_day() — exactement ce que valide le bilan en jeu.
	# (DecisionResolver résout les différés sur day_started, échéance comptée en day_count.)
	GameManager.day_duration_seconds = 1.0
	GameManager.set_speed(3)
	var guard: int = 0
	while _resolved_count == resolved_before_b and guard < 10:
		await _real_wait(1.0)  # laisse la journée (1.0 s à x3) reboucler → day_ended + gel
		if GameManager.is_awaiting_day_review():
			GameManager.start_next_day()  # valide → day_started → le résolveur vérifie l'échéance
		guard += 1
	var deferred_resolved: bool = _resolved_count == resolved_before_b + 1 \
		and committed_b != 0 and _last_resolved_outcome == committed_b
	var drained: bool = resolver.pending_count() == 0
	# Laisse les agents du dernier matin déclenché s'initialiser avant de quitter
	# (évite un faux "resources still in use" au shutdown headless).
	await _real_wait(0.5)

	# Restaurer les overrides (→ valeurs .tres) et un état temporel neutre.
	resolver.immediate_prob_override = -1.0
	solicitations.rate_override = -1.0
	solicitations.desk_prob_override = -1.0
	GameManager.set_speed(1)
	Engine.time_scale = 1.0

	var ok_all: bool = shown_a and immediate_ok and deferred_held and deferred_resolved and drained
	Log.info("Resolution smoke — immediate:%s deferred_held:%s deferred_resolved:%s drained:%s" % [
		immediate_ok, deferred_held, deferred_resolved, drained])
	print("RESOLUTION_SMOKE immediate_ok=%s deferred_held=%s deferred_resolved=%s drained=%s outcome=%d" % [
		immediate_ok, deferred_held, deferred_resolved, drained, _last_resolved_outcome])
	print("RESOLUTION_SMOKE_RESULT=%s" % ("PASS" if ok_all else "FAIL"))
	get_tree().quit(0 if ok_all else 1)

## Test d'intégration headless de la file d'attente, patience & moral (Story 1.7) :
##  (AC1) plusieurs sollicitations BUREAU → file >= 2 agents, créneaux DISTINCTS ;
##  (AC2) patience dépassée (override = 0) → le moral d'un agent en file BAISSE (< 100) ;
##  (AC3) traiter le front (open_solicitation) → il QUITTE la file (taille -1) et la
##        patience des suivants CONTINUE de courir (le moral d'un agent restant rebaisse).
## On force le canal/cadence via les overrides 1.4 (déterministe) et la patience via
## DeskQueue.patience_override. Compteurs non nécessaires : on lit get_morale() directement.
func _run_queue_smoke_and_quit() -> void:
	GameManager.day_duration_seconds = 600.0  # journée longue → pas de wrap pendant le test

	var open_space: Node3D = $OpenSpace
	var agents_root: Node3D = open_space.get_node("Agents")
	var solicitations: Node = open_space.get_node("SolicitationSystem")
	var desk_queue: Node = open_space.get_node("DeskQueue")

	# Laisser les agents arriver à leur poste, sans sollicitation.
	solicitations.rate_override = 0.0
	GameManager.set_speed(3)
	await _real_wait(4.0)

	# (AC1) Forcer plusieurs sollicitations BUREAU → file + créneaux distincts.
	await _force_desk_solicitation(solicitations)
	var queue_n: int = desk_queue.queue_size()
	var slots_distinct: bool = open_space.desk_queue_slot_world(0) != open_space.desk_queue_slot_world(1)
	var queue_ok: bool = queue_n >= 2 and slots_distinct

	# (AC2) Patience dépassée → le moral d'un agent en file baisse.
	var sample_id: int = desk_queue.front_agent_id()
	var sample: Agent = _find_agent_by_id(agents_root, sample_id)
	var morale_before: int = sample.get_morale() if sample != null else -1
	desk_queue.patience_override = 0.0  # patience nulle → décroissance dès le 1er tick d'attente
	await _real_wait(3.0)               # ≈ 9 s-jeu à x3 ≥ 1 palier de 5 s
	var morale_after: int = sample.get_morale() if sample != null else -1
	var morale_ok: bool = sample != null and morale_before == 100 and morale_after < morale_before

	# (AC3) Traiter le front → il quitte la file ; la patience des suivants continue.
	var size_before: int = desk_queue.queue_size()
	var front: int = desk_queue.front_agent_id()
	var survivor_id: int = -1
	for node: Node in agents_root.get_children():
		if node is Agent and desk_queue.is_queued((node as Agent).agent_id) and (node as Agent).agent_id != front:
			survivor_id = (node as Agent).agent_id
			break
	var survivor: Agent = _find_agent_by_id(agents_root, survivor_id)
	var survivor_before: int = survivor.get_morale() if survivor != null else -1
	solicitations.open_solicitation(front)
	var size_after: int = desk_queue.queue_size()
	var left_ok: bool = size_after == size_before - 1 and not desk_queue.is_queued(front)
	await _real_wait(2.0)  # la patience des suivants continue de courir
	var survivor_after: int = survivor.get_morale() if survivor != null else -1
	var patience_continues: bool = survivor != null and survivor_after < survivor_before

	# Restaurer les overrides (→ valeurs .tres) et un état temporel neutre.
	desk_queue.patience_override = -1.0
	solicitations.rate_override = -1.0
	solicitations.desk_prob_override = -1.0
	GameManager.set_speed(1)
	Engine.time_scale = 1.0

	var ok_all: bool = queue_ok and morale_ok and left_ok and patience_continues
	Log.info("Queue smoke — file:%d distinct:%s moral:%d→%d left:%s surv:%d→%d" % [
		queue_n, slots_distinct, morale_before, morale_after, left_ok, survivor_before, survivor_after])
	print("QUEUE_SMOKE queue=%d slots_distinct=%s morale_before=%d morale_after=%d left_ok=%s surv_before=%d surv_after=%d" % [
		queue_n, slots_distinct, morale_before, morale_after, left_ok, survivor_before, survivor_after])
	print("QUEUE_SMOKE_RESULT=%s" % ("PASS" if ok_all else "FAIL"))
	get_tree().quit(0 if ok_all else 1)

## Test d'intégration headless du HUD persistant & ressource Attention (Story 1.8) :
##  (AC1) le HUD affiche le JOUR courant (= GameManager.day_count) et le MORAL MOYEN
##        (= 100 quand tous les agents sont frais) ;
##  (AC2) la PRESSION D'ATTENTION est matérialisée : un mail forcé → compteur Mails >= 1 ;
##        des sollicitations BUREAU → compteur File >= 1, et OUVRIR le front décrémente la File ;
##  (AC3) quand le MORAL MOYEN franchit un seuil (via le VRAI signal agent_morale_changed),
##        la SÉVÉRITÉ affichée passe NORMAL → WARNING (< warn) → CRITICAL (< critical).
## Le HUD est un consommateur EventBus pur : on exerce les vrais chemins (sollicitations
## 1.4, moral 1.7 via Agent.adjust_morale) et on lit les getters d'affichage du HUD.
func _run_hud_smoke_and_quit() -> void:
	GameManager.day_duration_seconds = 600.0  # journée longue → pas de wrap pendant le test

	var open_space: Node3D = $OpenSpace
	var agents_root: Node3D = open_space.get_node("Agents")
	var solicitations: Node = open_space.get_node("SolicitationSystem")
	var hud: CanvasLayer = open_space.get_node("Hud")

	# Laisser les agents arriver à leur poste, sans sollicitation.
	solicitations.rate_override = 0.0
	GameManager.set_speed(3)
	await _real_wait(4.0)

	# (AC1) Jour courant + moral moyen initial (tous les agents à 100).
	var day_ok: bool = hud.displayed_day() == GameManager.day_count and GameManager.day_count >= 1
	var morale_initial_ok: bool = hud.displayed_average_morale() == 100

	# (AC2 mail) Forcer le canal MAIL → compteur Mails du HUD >= 1.
	solicitations.desk_prob_override = 0.0
	solicitations.rate_override = 1.0
	await _real_wait(1.0)
	solicitations.rate_override = 0.0
	var mail_ok: bool = hud.displayed_mail_count() >= 1

	# Purger les mails (ouvre toutes les sollicitations actives → agents de nouveau éligibles).
	for node: Node in agents_root.get_children():
		if node is Agent and solicitations.has_active_solicitation((node as Agent).agent_id):
			solicitations.open_solicitation((node as Agent).agent_id)
	await _real_wait(2.0)
	var mail_cleared_ok: bool = hud.displayed_mail_count() == 0

	# (AC2 file) Forcer le canal BUREAU → compteur File >= 1, puis ouvrir le front → File -1.
	await _force_desk_solicitation(solicitations)
	var file_before: int = hud.displayed_file_count()
	var file_raised_ok: bool = file_before >= 1
	# Ouvre la 1re sollicitation bureau active (exactement ce que le clic déclenche).
	_open_first_active(agents_root, solicitations)
	var file_after: int = hud.displayed_file_count()
	var file_decrement_ok: bool = file_after == file_before - 1

	# (AC3) Franchissement de seuil du moral moyen via le VRAI signal agent_morale_changed.
	var sev_initial_ok: bool = hud.displayed_morale_severity() == HudMath.Severity.NORMAL
	# Baisse contrôlée : ~ -55 sur chaque agent → moyenne ~45 (< warn 50) → WARNING.
	for node: Node in agents_root.get_children():
		if node is Agent:
			(node as Agent).adjust_morale(-55.0)
	var warn_ok: bool = hud.displayed_morale_severity() == HudMath.Severity.WARNING
	# Baisse supplémentaire : ~ -25 de plus → moyenne ~20 (< critical 25) → CRITICAL.
	for node: Node in agents_root.get_children():
		if node is Agent:
			(node as Agent).adjust_morale(-25.0)
	var crit_ok: bool = hud.displayed_morale_severity() == HudMath.Severity.CRITICAL

	# Restaurer les overrides (→ valeurs .tres) et un état temporel neutre.
	solicitations.rate_override = -1.0
	solicitations.desk_prob_override = -1.0
	GameManager.set_speed(1)
	Engine.time_scale = 1.0

	var ok_all: bool = day_ok and morale_initial_ok and mail_ok and mail_cleared_ok \
		and file_raised_ok and file_decrement_ok and sev_initial_ok and warn_ok and crit_ok
	Log.info("HUD smoke — jour:%s moral0:%s mail:%s mailclr:%s file:%d→%d sev:N=%s W=%s C=%s" % [
		day_ok, morale_initial_ok, mail_ok, mail_cleared_ok, file_before, file_after,
		sev_initial_ok, warn_ok, crit_ok])
	print("HUD_SMOKE day=%d morale0=%d mail_ok=%s file_before=%d file_after=%d warn_ok=%s crit_ok=%s" % [
		hud.displayed_day(), 100 if morale_initial_ok else hud.displayed_average_morale(),
		mail_ok, file_before, file_after, warn_ok, crit_ok])
	print("HUD_SMOKE_RESULT=%s" % ("PASS" if ok_all else "FAIL"))
	get_tree().quit(0 if ok_all else 1)

## Test d'intégration de la FICHE AGENT (Story 1.9) : ouverture au clic (identité + moral),
## mise à jour live du moral, bascule sur un autre agent, fermeture au clic ailleurs,
## priorité sollicitation (non-régression 1.4) et auto-fermeture au départ de l'agent affiché.
## Pilote via les POINTS D'ENTRÉE COMMUNS du SelectionController (handle_agent_click /
## handle_empty_click) — exactement ce que déclenche le clic réel.
func _run_card_smoke_and_quit() -> void:
	GameManager.day_duration_seconds = 600.0  # journée longue → pas de wrap pendant le test

	var open_space: Node3D = $OpenSpace
	var agents_root: Node3D = open_space.get_node("Agents")
	var solicitations: Node = open_space.get_node("SolicitationSystem")
	var selection: Node = open_space.get_node("SelectionController")
	var card: CanvasLayer = open_space.get_node("AgentCard")

	# Laisser les agents arriver à leur poste, sans sollicitation.
	solicitations.rate_override = 0.0
	GameManager.set_speed(3)
	await _real_wait(4.0)

	# Deux agents distincts pour les tests d'ouverture / bascule.
	var first: Agent = null
	var second: Agent = null
	for node: Node in agents_root.get_children():
		if node is Agent:
			if first == null:
				first = node
			elif second == null:
				second = node
				break

	# (AC1) Ouverture : la fiche montre l'agent cliqué + son moral initial (100).
	selection.handle_agent_click(first)
	var open_ok: bool = card.is_showing() and card.displayed_agent_id() == first.agent_id
	var morale_initial_ok: bool = card.displayed_morale() == 100

	# (AC1 live) Baisse via le VRAI signal agent_morale_changed → fiche mise à jour en direct.
	first.adjust_morale(-60.0)
	var live_ok: bool = card.displayed_morale() == 40

	# (AC3 bascule) Clic sur un AUTRE agent → la fiche change d'agent et reste ouverte.
	selection.handle_agent_click(second)
	var switch_ok: bool = card.is_showing() and card.displayed_agent_id() == second.agent_id

	# (AC3 clic ailleurs) → fermeture propre.
	selection.handle_empty_click()
	var empty_close_ok: bool = not card.is_showing()

	# (Non-régression 1.4) Agent AVEC sollicitation active → le clic ouvre la SOLLICITATION,
	# PAS la fiche (priorité à l'agent qui réclame l'attention).
	await _force_desk_solicitation(solicitations)
	var solicited: Agent = null
	for node: Node in agents_root.get_children():
		if node is Agent and solicitations.has_active_solicitation((node as Agent).agent_id):
			solicited = node
			break
	card.hide_card()
	var solicitation_priority_ok: bool = false
	if solicited != null:
		selection.handle_agent_click(solicited)
		solicitation_priority_ok = not solicitations.has_active_solicitation(solicited.agent_id) \
			and not card.is_showing()

	# (AC3 auto-fermeture au départ) 'solicited' n'a plus de sollicitation après ouverture
	# → un clic ouvre sa FICHE ; son départ (agent_departed) la referme automatiquement.
	var depart_close_ok: bool = false
	if solicited != null:
		selection.handle_agent_click(solicited)
		var reopened: bool = card.is_showing() and card.displayed_agent_id() == solicited.agent_id
		EventBus.agent_departed.emit(solicited.agent_id)
		depart_close_ok = reopened and not card.is_showing()

	# Restaurer les overrides (→ valeurs .tres) et un état temporel neutre.
	solicitations.rate_override = -1.0
	solicitations.desk_prob_override = -1.0
	GameManager.set_speed(1)
	Engine.time_scale = 1.0

	var ok_all: bool = open_ok and morale_initial_ok and live_ok and switch_ok \
		and empty_close_ok and solicitation_priority_ok and depart_close_ok
	Log.info("Card smoke — open:%s moral0:%s live:%s switch:%s emptyclose:%s solprio:%s departclose:%s" % [
		open_ok, morale_initial_ok, live_ok, switch_ok, empty_close_ok,
		solicitation_priority_ok, depart_close_ok])
	print("CARD_SMOKE open=%s morale0=%s live40=%s switch=%s empty_close=%s sol_priority=%s depart_close=%s" % [
		open_ok, morale_initial_ok, live_ok, switch_ok, empty_close_ok,
		solicitation_priority_ok, depart_close_ok])
	print("CARD_SMOKE_RESULT=%s" % ("PASS" if ok_all else "FAIL"))
	get_tree().quit(0 if ok_all else 1)

## Test d'intégration du BILAN DE FIN DE JOURNÉE (Story 1.10) :
##  (AC1) l'instantané du moral suit la cohorte présente (baisse réelle via adjust_morale),
##        et reste valable au day_ended MÊME si les agents sont partis le soir (robustesse
##        de l'instantané) ; le bilan s'affiche au rebouclage avec le bon moral + seuil ;
##  (AC2) GATE : juste après le wrap, la journée suivante N'a PAS démarré (sim gelée) ;
##        confirm() relance le jour suivant (day_count +1, agents respawnés, HUD à jour).
## On pilote via le POINT D'ENTRÉE COMMUN report.confirm() — ce que déclenche le bouton.
func _run_report_smoke_and_quit() -> void:
	var open_space: Node3D = $OpenSpace
	var agents_root: Node3D = open_space.get_node("Agents")
	var solicitations: Node = open_space.get_node("SolicitationSystem")
	var report: CanvasLayer = open_space.get_node("DayReport")
	var hud: CanvasLayer = open_space.get_node("Hud")

	# Laisser les agents arriver à leur poste, sans sollicitation parasite.
	GameManager.day_duration_seconds = 600.0  # journée longue → pas de wrap pendant la prépa
	solicitations.rate_override = 0.0
	GameManager.set_speed(3)
	await _real_wait(4.0)
	var day_before: int = GameManager.day_count

	# (AC1 instantané) Baisse réelle du moral d'au moins un agent → l'instantané du bilan
	# (mis à jour sur agent_morale_changed) reflète la baisse de la cohorte présente.
	var lowered: bool = false
	for node: Node in agents_root.get_children():
		if node is Agent:
			(node as Agent).adjust_morale(-40.0)
			lowered = true
			break
	var snapshot_during_day: int = report.displayed_day_avg_morale()
	var snapshot_ok: bool = lowered and snapshot_during_day >= 0 and snapshot_during_day < 100

	# (AC1 affichage à day_ended) Provoquer le rebouclage : journée ultra-courte + x3.
	# Les agents partent le soir AVANT le wrap → le bilan doit tout de même afficher
	# l'instantané d'avant les départs (PAS « — »).
	GameManager.day_duration_seconds = 1.0
	GameManager.set_speed(3)
	await _real_wait(2.0)
	var shown_ok: bool = report.is_showing()
	var report_morale: int = report.displayed_day_avg_morale()
	var morale_display_ok: bool = report_morale == snapshot_during_day and report_morale >= 0

	# (AC2 gate) Juste après le wrap : la journée suivante N'a PAS démarré (sim gelée).
	var awaiting_ok: bool = GameManager.is_awaiting_day_review() \
		and GameManager.day_count == day_before
	await _real_wait(1.0)  # confirme que rien n'avance tant qu'on ne valide pas
	var still_gated_ok: bool = GameManager.day_count == day_before and report.is_showing()

	# (AC2 validation) confirm() → la journée suivante démarre.
	report.confirm()
	var closed_ok: bool = not report.is_showing()
	var advanced_ok: bool = GameManager.day_count == day_before + 1 \
		and not GameManager.is_awaiting_day_review()
	await _real_wait(2.0)  # laisse le matin suivant peupler l'open space
	var respawned: bool = false
	for node: Node in agents_root.get_children():
		if node is Agent:
			respawned = true
			break
	var hud_followed_ok: bool = hud.displayed_day() == day_before + 1
	var next_day_ok: bool = advanced_ok and respawned and hud_followed_ok

	# Restaurer les overrides (→ valeurs .tres) et un état temporel neutre.
	solicitations.rate_override = -1.0
	solicitations.desk_prob_override = -1.0
	GameManager.set_speed(1)
	Engine.time_scale = 1.0

	var ok_all: bool = snapshot_ok and shown_ok and morale_display_ok and awaiting_ok \
		and still_gated_ok and closed_ok and next_day_ok
	Log.info("Report smoke — snap:%s shown:%s moraldisp:%d awaiting:%s stillgated:%s closed:%s nextday:%s" % [
		snapshot_ok, shown_ok, report_morale, awaiting_ok, still_gated_ok, closed_ok, next_day_ok])
	print("REPORT_SMOKE snapshot=%d shown=%s morale_display=%d awaiting=%s gated=%s closed=%s next_day=%s" % [
		snapshot_during_day, shown_ok, report_morale, awaiting_ok, still_gated_ok, closed_ok, next_day_ok])
	print("REPORT_SMOKE_RESULT=%s" % ("PASS" if ok_all else "FAIL"))
	get_tree().quit(0 if ok_all else 1)

## Test d'intégration de la JAUGE FATIGUE + ROSTER PERSISTANT (Story 2.1) :
##  (AC1) la fatigue MONTE au travail (accumulation sur SimClock) ;
##  (AC1) la fiche affiche la fatigue et la suit en direct (agent_fatigue_changed filtré) ;
##  (AC4) après une journée (bilan 1.10 validé), les MÊMES agents (mêmes ids) reviennent ;
##  (AC2) un agent « Heures sup » porte +15 fatigue de nuit relatif à un agent « Stable »
##        (report inter-jour : repos -25 + heures sup' +15) — preuve que la fatigue est
##        bien REPORTÉE (≠ reset à 0) et que la formule overnight s'applique différemment.
## On booste fatigue_work_per_day pour que le différentiel de nuit dépasse le plancher 0.
func _run_fatigue_smoke_and_quit() -> void:
	var open_space: Node3D = $OpenSpace
	var agents_root: Node3D = open_space.get_node("Agents")
	var solicitations: Node = open_space.get_node("SolicitationSystem")
	var selection: Node = open_space.get_node("SelectionController")
	var card: CanvasLayer = open_space.get_node("AgentCard")
	var report: CanvasLayer = open_space.get_node("DayReport")
	var balance: SimBalance = preload("res://data/balance/sim_balance.tres")

	# Booste l'accumulation pour que le report -25/+15 reste bien au-dessus du plancher 0.
	var saved_work: float = balance.fatigue_work_per_day
	balance.fatigue_work_per_day = 60.0

	# Journée assez longue pour mesurer l'accumulation et ouvrir la fiche sans wrap.
	GameManager.day_duration_seconds = 60.0
	solicitations.rate_override = 0.0
	GameManager.set_speed(3)
	await _real_wait(4.0)  # agents arrivés, au travail

	# Un agent quelconque + un « Stable » + un « Heures sup » (identifiés par display_name).
	var any_agent: Agent = null
	var stable: Agent = null
	var overtimer: Agent = null
	for node: Node in agents_root.get_children():
		if node is Agent:
			var a: Agent = node
			if any_agent == null:
				any_agent = a
			if a.get_display_name() == "Heures sup" and overtimer == null:
				overtimer = a
			if a.get_display_name() == "Stable" and stable == null:
				stable = a

	# (AC1 accumulation) la fatigue monte au travail.
	var f_a: int = any_agent.get_fatigue()
	await _real_wait(2.0)
	var f_b: int = any_agent.get_fatigue()
	var accrual_ok: bool = f_b > f_a

	# (AC1 fiche) ouverture → fatigue affichée ≈ fatigue agent ; puis suit en direct.
	selection.handle_agent_click(any_agent)
	var card_shows_ok: bool = card.is_showing() and absi(card.displayed_fatigue() - any_agent.get_fatigue()) <= 1
	var disp_before: int = card.displayed_fatigue()
	await _real_wait(2.0)
	var card_live_ok: bool = card.displayed_fatigue() > disp_before
	selection.handle_empty_click()

	# Ids pour le suivi inter-jour (roster persistant).
	var stable_id: int = stable.agent_id
	var overtimer_id: int = overtimer.agent_id

	# (AC4 + AC2) Forcer la fin de journée → bilan 1.10 → valider → nouveau matin.
	GameManager.day_duration_seconds = 1.0
	GameManager.set_speed(3)
	await _real_wait(2.0)
	var report_ok: bool = report.is_showing() and GameManager.is_awaiting_day_review()
	report.confirm()
	# Restaurer une journée LONGUE + vitesse normale AVANT d'inspecter : sinon le jour 2
	# reboucle aussitôt (duration 1.0 × x3) et ses agents repartent le soir → roster
	# introuvable (les départs sont échelonnés : le « Stable » part avant le « Heures sup »).
	GameManager.day_duration_seconds = 60.0
	GameManager.set_speed(1)
	await _real_wait(1.5)  # le nouveau matin peuple l'open space (agents présents, sans wrap)

	var stable2: Agent = _find_agent_by_id(agents_root, stable_id)
	var overtimer2: Agent = _find_agent_by_id(agents_root, overtimer_id)
	var same_roster_ok: bool = stable2 != null and overtimer2 != null  # MÊMES ids reviennent
	var morning_stable: int = stable2.get_fatigue() if stable2 != null else -1
	var morning_overtimer: int = overtimer2.get_fatigue() if overtimer2 != null else -1
	# AC2 : l'overtimer porte +15 de nuit relatif au stable ; carry-over prouvé (>0, ≠ reset).
	var overtime_ok: bool = stable2 != null and overtimer2 != null \
		and morning_overtimer > 0 and (morning_overtimer - morning_stable) >= 10

	# Restaurer l'équilibrage et les overrides de sollicitation.
	balance.fatigue_work_per_day = saved_work
	solicitations.rate_override = -1.0
	solicitations.desk_prob_override = -1.0
	Engine.time_scale = 1.0
	await _real_wait(0.5)  # respiration : agents du matin fraîchement spawnés (cf. 1.10)

	var ok_all: bool = accrual_ok and card_shows_ok and card_live_ok and report_ok \
		and same_roster_ok and overtime_ok
	Log.info("Fatigue smoke — accrual:%s(%d→%d) card:%s live:%s report:%s same_roster:%s morn(stable:%d overtime:%d)" % [
		accrual_ok, f_a, f_b, card_shows_ok, card_live_ok, report_ok, same_roster_ok,
		morning_stable, morning_overtimer])
	print("FATIGUE_SMOKE accrual=%s f=%d->%d card=%s live=%s report=%s same_roster=%s morn_stable=%d morn_overtime=%d" % [
		accrual_ok, f_a, f_b, card_shows_ok, card_live_ok, report_ok, same_roster_ok,
		morning_stable, morning_overtimer])
	print("FATIGUE_SMOKE_RESULT=%s" % ("PASS" if ok_all else "FAIL"))
	get_tree().quit(0 if ok_all else 1)

## Force tous les agents éligibles à lever une sollicitation BUREAU au prochain tick,
## puis coupe la cadence (overrides de test only).
func _force_desk_solicitation(solicitations: Node) -> void:
	solicitations.desk_prob_override = 1.0
	solicitations.rate_override = 1.0
	await _real_wait(1.0)
	solicitations.rate_override = 0.0

## Ouvre la 1re sollicitation active trouvée (exactement ce que le clic déclenche en jeu).
func _open_first_active(agents_root: Node3D, solicitations: Node) -> void:
	for node: Node in agents_root.get_children():
		if node is Agent and solicitations.has_active_solicitation((node as Agent).agent_id):
			solicitations.open_solicitation((node as Agent).agent_id)
			return

## Renvoie l'Agent d'identifiant donné dans le conteneur (ou null).
func _find_agent_by_id(agents_root: Node3D, agent_id: int) -> Agent:
	if agent_id < 0:
		return null
	for node: Node in agents_root.get_children():
		if node is Agent and (node as Agent).agent_id == agent_id:
			return node
	return null

## Distance horizontale minimale entre un agent et un point cible (m).
func _min_agent_distance_to(agents_root: Node3D, target: Vector3) -> float:
	var best: float = INF
	for node: Node in agents_root.get_children():
		if node is Node3D:
			var flat: Vector3 = (node as Node3D).global_position - target
			flat.y = 0.0
			best = minf(best, flat.length())
	return best

## Attend un délai en secondes RÉELLES, indépendamment de la pause et de time_scale
## (process_always=true, ignore_time_scale=true) → fenêtre de mesure comparable.
func _real_wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
