extends CanvasLayer
## DecisionPopup — première UI 2D du projet (Story 1.5). Sur EventBus.solicitation_opened
## (émis par la Story 1.4), affiche une pop-up : contexte + 2-3 options (boutons). Le
## choix d'une option émet EventBus.decision_chosen(decision_id, option_index) (consommé
## par la résolution immédiate/différée, Story 1.6) et referme la pop-up.
##
## Frontières (volontaires) :
##   - AUCUN effet de jeu ici (jauges/état/immédiat-vs-différé = Story 1.6).
##   - L'agent repart dès l'OUVERTURE (timing posé en 1.4 : open_solicitation →
##     clear_solicitation) ; on NE touche PAS à l'agent. La file physique/patience/moral
##     est la Story 1.7 (ici, simple FIFO mémoire anti-perte de décision).
##
## ⚠️ PROCESS_MODE_ALWAYS : la pop-up doit rester cliquable même en PAUSE (le joueur met
## en pause pour réfléchir — même piège que l'input « Espace »/clic en 1.3/1.4). Mais elle
## ne met JAMAIS le jeu en pause d'elle-même (AC#2 : le temps continue sauf pause joueur).
## Conventions : EventBus-only, pas de chemin absolu, contenu data-driven (.tres).
## [Source: epics.md Story 1.5 ; game-architecture.md#Decision-Summary D9 ; #System-Location-Mapping ; #Event-System]

const _CATALOG: DecisionCatalog = preload("res://data/decisions/decision_catalog.tres")

@onready var _context_label: Label = %ContextLabel
@onready var _options_box: VBoxContainer = %OptionsBox

var _rng := RandomNumberGenerator.new()
## Identifiant incrémental de décision (runtime) — distinct du contenu .tres.
var _next_decision_id: int = 0
var _current_decision_id: int = -1
var _current_agent_id: int = -1
## Template de la décision actuellement affichée. Conservé (Story 1.6) pour pouvoir lire
## l'EFFET (outcome) de l'option choisie au moment du clic — sinon perdu à la fermeture.
var _current_decision: Decision = null
## FIFO des sollicitations reçues pendant qu'une pop-up est déjà ouverte. Chaque entrée
## = [agent_id, channel]. GARDE-FOU MINIMAL : empêche d'empiler deux pop-ups ET de perdre
## une décision (la 1.4 a déjà consommé la sollicitation à l'ouverture). La vraie file
## d'attente physique (patience + moral + ordre au bureau) est la Story 1.7.
var _pending: Array = []

func _ready() -> void:
	# Actif en pause → boutons cliquables pendant que le temps est gelé (AC#3).
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_rng.randomize()
	EventBus.solicitation_opened.connect(_on_solicitation_opened)

func _on_solicitation_opened(agent_id: int, channel: int) -> void:
	if is_showing():
		# Une pop-up est déjà à l'écran → on enfile (anti-perte), on affichera à la fermeture.
		_pending.append([agent_id, channel])
		return
	_present(agent_id, channel)

## Construit et affiche la pop-up pour (agent_id, channel) à partir d'un template du catalogue.
func _present(agent_id: int, channel: int) -> void:
	var decision: Decision = _CATALOG.pick(channel, _rng.randf())
	if decision == null:
		Log.warn("DecisionPopup : aucune décision pour le canal %d (catalogue vide ?)" % channel)
		return
	if not DecisionMath.is_valid_option_count(decision.options.size()):
		Log.warn("DecisionPopup : décision '%s' a %d options (hors 2-3) — ignorée" % [
			decision.context_text, decision.options.size()])
		return
	_current_agent_id = agent_id
	_current_decision = decision
	_current_decision_id = _next_decision_id
	_next_decision_id += 1
	_context_label.text = decision.context_text
	_clear_options()
	for i: int in decision.options.size():
		var btn := Button.new()
		btn.text = decision.options[i].label
		# bind(i) : le bouton (signal pressed sans argument) appelle choose_option(i).
		btn.pressed.connect(choose_option.bind(i))
		_options_box.add_child(btn)
	visible = true
	Log.info("DecisionPopup ouverte #%d (agent %d, %d options)" % [
		_current_decision_id, agent_id, decision.options.size()])

## POINT D'ENTRÉE COMMUN du clic bouton ET du test d'intégration (--decision-smoke).
## Émet decision_chosen, referme, puis dépile une sollicitation en attente. AUCUN effet
## de jeu ici (Story 1.6) ; AUCUNE action sur l'agent (retour géré en 1.4).
func choose_option(index: int) -> void:
	if not is_showing():
		return
	EventBus.decision_chosen.emit(_current_decision_id, index)
	Log.info("Décision #%d — option %d choisie (agent %d)" % [
		_current_decision_id, index, _current_agent_id])
	# Story 1.6 : publier l'EFFET de l'option choisie vers la résolution (immédiat/différé).
	# La pop-up reste UI pure : elle ne tire RIEN et n'applique RIEN — DecisionResolver décide.
	if _current_decision != null and index >= 0 and index < _current_decision.options.size():
		var outcome: int = _current_decision.options[index].outcome
		EventBus.decision_committed.emit(_current_decision_id, outcome)
	else:
		Log.warn("DecisionPopup : choix #%d index %d hors bornes — pas de decision_committed" % [
			_current_decision_id, index])
	_close()
	_advance_pending()

## Vrai si la pop-up est visible (utile au clic/test).
func is_showing() -> bool:
	return visible

## Nombre de boutons d'options actuellement affichés (utile au test).
func option_button_count() -> int:
	return _options_box.get_child_count()

func _close() -> void:
	visible = false
	_current_decision_id = -1
	_current_agent_id = -1
	_current_decision = null
	_clear_options()

func _advance_pending() -> void:
	if _pending.is_empty():
		return
	var next: Array = _pending.pop_front()
	_present(next[0], next[1])

func _clear_options() -> void:
	for child: Node in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()
