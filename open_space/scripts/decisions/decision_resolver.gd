extends Node
## DecisionResolver — résolution immédiate vs différée des décisions (Story 1.6). Sur
## EventBus.decision_committed (émis par la pop-up au choix, Story 1.5/1.6), CLASSE le
## choix : ~60 % IMMÉDIAT (résolu tout de suite) / ~40 % DIFFÉRÉ (résolu 1-2 jours plus
## tard, ordonnancé sur le cycle de journée de GameManager/SimClock). À la résolution,
## émet le signal FONDATEUR EventBus.decision_resolved(decision_id, outcome) — jusqu'ici
## jamais émis ; les jauges futures (Moral 1.7, Trésorerie Épic 3…) s'y abonneront.
##
## Frontières (volontaires) :
##   - AUCUNE jauge concrète appliquée ici (elles n'existent pas encore) : `outcome` est
##     un code d'effet abstrait transporté tel quel. Système purement événementiel
##     (aucun _process → zéro coût par frame, NFR1).
##
## ⚠️ Anti save-scum (NFR9) : rien ne révèle l'issue d'un différé avant son échéance —
## aucun decision_resolved anticipé, AUCUN log de l'outcome d'un différé tant qu'il n'est
## pas résolu. Les callbacks de signal s'exécutent même en pause ; un choix fait en pause
## (pop-up PROCESS_MODE_ALWAYS) est bien reçu, sans nécessiter _process.
## Conventions : EventBus-only, pas de chemin absolu, équilibrage data-driven (.tres).
## [Source: epics.md Story 1.6 ; gdd.md (~60 %/~40 %, 1-2 j) ; FR6 ; NFR9 ; game-architecture.md#ADR-3]

const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")

var _rng := RandomNumberGenerator.new()

## Override de test (< 0 = utiliser la valeur d'équilibrage .tres). Permet au harnais
## --resolution-smoke de FORCER immédiat (1.0) ou différé (0.0) de façon déterministe,
## sans toucher au .tres partagé. Inutilisé en jeu réel. (Modèle : SolicitationSystem.)
var immediate_prob_override: float = -1.0

## Décisions différées en attente. Chaque entrée = { decision_id, outcome, due_day }.
## Anti save-scum : l'outcome y reste PRIVÉ jusqu'à l'échéance (jamais loggé/émis avant).
var _pending: Array = []

func _ready() -> void:
	_rng.randomize()
	EventBus.decision_committed.connect(_on_decision_committed)
	EventBus.day_started.connect(_on_day_started)

func _on_decision_committed(decision_id: int, outcome: int) -> void:
	var prob: float = immediate_prob_override if immediate_prob_override >= 0.0 else _BALANCE.decision_immediate_probability
	if DecisionResolutionMath.is_immediate(_rng.randf(), prob):
		# Immédiat : l'effet se résout tout de suite (l'outcome est déjà révélé → loggable).
		EventBus.decision_resolved.emit(decision_id, outcome)
		Log.info("Décision #%d résolue (immédiate) outcome=%d" % [decision_id, outcome])
		return
	# Différé : ordonnance à +1-2 jours. NE PAS logger l'outcome (anti save-scum, NFR9).
	var delay: int = DecisionResolutionMath.delay_days(
		_rng.randf(), _BALANCE.decision_deferred_min_days, _BALANCE.decision_deferred_max_days)
	var due_day: int = GameManager.day_count + delay
	_pending.append({"decision_id": decision_id, "outcome": outcome, "due_day": due_day})
	Log.info("Décision #%d différée → échéance jour %d" % [decision_id, due_day])

func _on_day_started(day: int) -> void:
	if _pending.is_empty():
		return
	# Émettre PUIS retirer hors itération de _pending (un consommateur pourrait re-piloter
	# le résolveur) : on reconstruit la liste des entrées encore en attente.
	var still_pending: Array = []
	var due: Array = []
	for entry: Dictionary in _pending:
		if DecisionResolutionMath.is_due(entry["due_day"], day):
			due.append(entry)
		else:
			still_pending.append(entry)
	_pending = still_pending
	for entry: Dictionary in due:
		EventBus.decision_resolved.emit(entry["decision_id"], entry["outcome"])
		Log.info("Décision #%d résolue (différée, échéance jour %d) outcome=%d" % [
			entry["decision_id"], entry["due_day"], entry["outcome"]])

## Nombre de décisions différées encore en attente (utile au test ; ne révèle PAS l'issue).
func pending_count() -> int:
	return _pending.size()
