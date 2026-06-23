extends Node
## Autoload GameManager — conteneur d'état global et chef d'orchestre du jeu.
## [Source: game-architecture.md#Decision-Summary D4]
##
## Story 1.2 : porte la source du cycle de journée (phase matin→soir) et démarre SimClock.
## Story 1.3 : devient le PROPRIÉTAIRE UNIQUE DU TEMPS — pause (Espace) et vitesses
## x1/x2/x3 (1/2/3), via les APIs natives Godot, sans toucher au code des agents
## ni de SimClock :
##   - PAUSE  = get_tree().paused (gèle tous les nœuds pausables : SimClock → plus de
##     ticks → décisions figées ; agents → mouvement figé ; futures jauges Épic 2).
##   - VITESSE = Engine.time_scale (multiplie le delta partout : SimClock tick plus vite
##     ET mouvement agents plus vite, de façon cohérente).
## ⚠️ Ce nœud DOIT être PROCESS_MODE_ALWAYS, sinon il ne reçoit plus l'input « Espace »
## une fois le jeu en pause (deadlock : impossible de reprendre).
## La durée de journée (~5 min cible) est tunable dans data/balance/sim_balance.tres.
##
## Story 1.10 : la fin de journée N'ENCHAÎNE PLUS automatiquement le matin suivant. Au
## rebouclage, on émet day_ended PUIS on GÈLE la simulation (SimClock.stop() → plus de
## tick → day_phase figée, aucun spawn) en posant _awaiting_day_review = true. C'est le
## BILAN de fin de journée (DayReport, %DayReport) qui, une fois validé par le joueur,
## appelle start_next_day() → SimClock.start() + day_started(N+1) (spawn du matin via
## AgentSpawner, HUD à jour). Pendant l'attente, l'input pause/vitesses est ignoré (le
## temps est piloté par le bilan, pas par le joueur).
## [Source: epics.md Story 1.3/1.10 ; 1-2…md#Frontière-avec-la-Story-1.3 ; game-architecture.md#ADR-3]

const DayPhaseMathC := preload("res://scripts/agents/day_phase_math.gd")
const TimeControlC := preload("res://scripts/systems/time_control.gd")
const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")

## Phase normalisée de la journée en cours (0.0 = matin → 1.0 = soir). Lue par les agents.
var day_phase: float = 0.0
## Numéro du jour courant (incrémenté à chaque nouveau matin).
var day_count: int = 0
## Seuil de base du soir (les départs s'échelonnent autour via les archétypes).
var evening_phase: float = 0.6
## Durée active d'une journée (s). Seedée depuis l'équilibrage ; les tests l'accélèrent.
var day_duration_seconds: float = 300.0

## Vrai quand le jeu est en pause (temps gelé). Lu par le HUD futur (Story 1.8).
var is_paused: bool = false
## Niveau de vitesse courant (1/2/3). Lu par le HUD futur (Story 1.8).
var speed_level: int = 1

var _day_active: bool = false
## Story 1.10 : vrai entre la fin d'une journée (day_ended) et la validation du bilan
## (start_next_day). Pendant ce temps, SimClock est arrêté et le matin suivant est gelé.
var _awaiting_day_review: bool = false

func _ready() -> void:
	# Reste actif même quand l'arbre est en pause → continue de lire l'input de reprise.
	process_mode = Node.PROCESS_MODE_ALWAYS
	evening_phase = _BALANCE.evening_phase
	day_duration_seconds = _BALANCE.day_duration_seconds
	# État temporel par défaut : en marche, vitesse x1.
	is_paused = false
	speed_level = 1
	Engine.time_scale = TimeControlC.scale_for_speed(speed_level)
	EventBus.day_started.connect(_on_day_started)
	SimClock.simulation_tick.connect(_on_simulation_tick)
	SimClock.start()

func _unhandled_input(event: InputEvent) -> void:
	# On ne réagit qu'aux pressions (pas aux relâchements/echo).
	if not (event is InputEventKey) or event.is_echo() or not event.is_pressed():
		return
	# Story 1.10 : pendant l'attente du bilan, le temps est piloté par le bilan (start_next_day),
	# pas par le joueur → on ignore pause/vitesses (évite un état temporel trompeur au HUD).
	if _awaiting_day_review:
		return
	if event.is_action_pressed("game_pause"):
		toggle_pause()
	elif event.is_action_pressed("speed_x1"):
		set_speed(1)
	elif event.is_action_pressed("speed_x2"):
		set_speed(2)
	elif event.is_action_pressed("speed_x3"):
		set_speed(3)

## Bascule pause ↔ reprise. À la reprise, restaure la vitesse sélectionnée.
func toggle_pause() -> void:
	set_paused(not is_paused)

## Gèle (true) ou relance (false) le temps. En pause : get_tree().paused arrête tous
## les nœuds pausables (SimClock, agents, futures jauges) — aucun code par-système requis.
func set_paused(paused: bool) -> void:
	if paused == is_paused:
		return
	is_paused = paused
	get_tree().paused = paused
	# Au gel, time_scale est sans effet (les nœuds ne s'exécutent plus) ; on le laisse
	# tel quel et on le restaure logiquement à la reprise via la vitesse courante.
	EventBus.game_paused.emit(is_paused)
	Log.info("Temps : %s" % ("PAUSE" if is_paused else "REPRISE (x%d)" % speed_level))

## Applique un niveau de vitesse (borné 1..3). Si le jeu est en pause, reprend.
func set_speed(level: int) -> void:
	speed_level = TimeControlC.clamp_speed_level(level)
	Engine.time_scale = TimeControlC.scale_for_speed(speed_level)
	if is_paused:
		set_paused(false)
	EventBus.speed_changed.emit(speed_level)
	Log.info("Vitesse : x%d" % speed_level)

func _on_day_started(day: int) -> void:
	day_count = day

func _on_simulation_tick(tick_delta: float) -> void:
	# Premier tick : amorce la toute première journée (les systèmes de scène sont
	# désormais dans l'arbre et abonnés à day_started).
	if not _day_active:
		_day_active = true
		day_phase = 0.0
		EventBus.day_started.emit(day_count + 1)
		return

	var previous: float = day_phase
	day_phase = DayPhaseMathC.advance(previous, tick_delta, day_duration_seconds)
	if DayPhaseMathC.has_wrapped(previous, day_phase):
		# Fin de journée (Story 1.10) : signaler le jour qui se termine (consommé par le
		# bilan DayReport) PUIS GELER la simulation. On N'ENCHAÎNE PLUS day_started ici :
		# le matin suivant ne démarre que sur validation du bilan (start_next_day).
		EventBus.day_ended.emit(day_count)
		_awaiting_day_review = true
		SimClock.stop()  # plus de tick → day_phase figée, aucun spawn jusqu'à start_next_day()
		Log.info("Fin de journée %d — bilan en attente" % day_count)

## Story 1.10 : appelée par le bilan (DayReport.confirm) une fois validé par le joueur.
## Relance l'horloge et ouvre le matin suivant (spawn via AgentSpawner sur day_started).
func start_next_day() -> void:
	if not _awaiting_day_review:
		return
	_awaiting_day_review = false
	SimClock.start()
	EventBus.day_started.emit(day_count + 1)  # _on_day_started fixe day_count ; AgentSpawner respawn
	Log.info("Bilan validé — démarrage du jour %d" % (day_count))

## Vrai entre day_ended et la validation du bilan (utile au test et au bilan).
func is_awaiting_day_review() -> bool:
	return _awaiting_day_review
