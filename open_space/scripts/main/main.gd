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

	# (c) AC#3 : une journée qui se termine émet day_ended et incrémente le compteur,
	# puis un nouveau cycle redémarre (day_started). On accélère fortement la journée.
	var ended_days: Array[int] = []
	EventBus.day_ended.connect(func(d: int) -> void: ended_days.append(d))
	var day_before: int = GameManager.day_count
	GameManager.day_duration_seconds = 1.0  # journée ultra-courte → wrap garanti
	GameManager.set_speed(3)
	await _real_wait(2.0)  # couvre ≥ 1 bouclage de journée

	# Restaure un état neutre.
	GameManager.set_speed(1)
	Engine.time_scale = 1.0

	var paused_ok: bool = absf(adv_paused) < 0.0001
	# Tolérance large (≥1.5x) : x3 fait avancer ~3x plus de ticks que x1 sur la même
	# fenêtre réelle ; on garde une marge confortable contre la quantification (±1 tick).
	var speed_ok: bool = adv_x1 > 0.0 and adv_x3 > adv_x1 * 1.5
	var cycle_ok: bool = ended_days.size() >= 1 and GameManager.day_count > day_before
	Log.info("Time smoke — adv_x1:%.5f adv_x3:%.5f adv_pause:%.5f day_ended:%d" % [
		adv_x1, adv_x3, adv_paused, ended_days.size()])
	print("TIME_SMOKE adv_x1=%.5f adv_x3=%.5f adv_pause=%.5f day_ended=%d day_count=%d" % [
		adv_x1, adv_x3, adv_paused, ended_days.size(), GameManager.day_count])
	var ok: bool = paused_ok and speed_ok and cycle_ok
	print("TIME_SMOKE_RESULT=%s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Attend un délai en secondes RÉELLES, indépendamment de la pause et de time_scale
## (process_always=true, ignore_time_scale=true) → fenêtre de mesure comparable.
func _real_wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
