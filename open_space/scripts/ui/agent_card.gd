extends CanvasLayer
## AgentCard — fiche d'inspection d'UN agent (Story 1.9). UI 2D non-modale
## (CanvasLayer + Panel ancré, D9) ouverte au clic gauche sur un agent SANS
## sollicitation active (le routage du clic vit dans SelectionController, qui appelle
## show_for() / hide_card() ici). Affiche :
##   - Identité : nom d'archétype + agent_id (lus une fois à l'ouverture) ;
##   - Jauge Moral (0-100, posée en 1.7), avec signal de seuil COULEUR réutilisant
##     HudMath.morale_severity + les seuils HUD du .tres (zéro nouveau module/seuil) ;
##   - Jauge Fatigue (0-100, Story 2.1), affichée en direct (agent_fatigue_changed filtré),
##     SANS couleur de seuil (le signal de risque ≥80 / indicateur burnout est la Story 2.2) ;
##   - Emplacements d'actions futures RÉSERVÉS et DÉSACTIVÉS (brancher/débrancher = Épic 5,
##     jour off = Épic 2) — placeholders sans logique (patron Trésorerie 1.8).
##
## LECTEUR d'état : ne conserve AUCUNE référence de nœud agent au-delà de l'ouverture ;
## suit le moral en direct par signal agent_morale_changed FILTRÉ sur _agent_id, et
## s'auto-ferme si l'agent affiché quitte l'open space (agent_departed → anti-fiche-fantôme).
## NON-MODALE : ne gèle pas le temps et ne pose PAS de catcher plein écran ; seul le Panel
## (mouse_filter = STOP) capte les clics dans son rect → ses boutons marchent et le cliquer
## ne déselectionne pas ; hors du Panel, les clics atteignent SelectionController (clic
## ailleurs ferme). Inverse de la pop-up modale 1.5. 100 % événementiel (NFR1).
## Conventions : EventBus-only, pas de chemin absolu, seuils data-driven (.tres).
## [Source: epics.md Story 1.9 ; FR43/FR12 ; game-architecture.md#Decision-Summary D9 ; #Event-System ; NFR1/NFR7/NFR11]

const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")

## Couleurs de présentation du signal de seuil (NFR7) — choix d'UI, pas d'équilibrage
## (mêmes teintes que le HUD 1.8). SEULS les seuils numériques vivent dans le .tres.
const _COLOR_NORMAL: Color = Color(0.12, 0.13, 0.14)   # texte foncé sur DA claire
const _COLOR_WARNING: Color = Color(0.78, 0.50, 0.05)  # ambre
const _COLOR_CRITICAL: Color = Color(0.78, 0.13, 0.13) # rouge

@onready var _name_label: Label = %NameLabel
@onready var _morale_label: Label = %MoraleLabel
@onready var _fatigue_label: Label = %FatigueLabel
@onready var _close_button: Button = %CloseButton

## Id de l'agent actuellement affiché (-1 = aucune fiche ouverte). Aucune référence de nœud
## conservée → robuste si l'agent est libéré (queue_free au départ).
var _agent_id: int = -1
## Dernier moral rendu (mémorisé pour le getter de test, plus robuste que parser le label).
var _shown_morale: int = -1
## Dernière fatigue rendue (mémorisée pour le getter de test, Story 2.1).
var _shown_fatigue: int = -1

func _ready() -> void:
	# UI active même en pause (cohérent DecisionPopup/Hud) ; la fiche ne met JAMAIS en pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# Abonnements PERSISTANTS : on filtre sur _agent_id plutôt que de (dé)connecter par ouverture.
	EventBus.agent_morale_changed.connect(_on_agent_morale_changed)
	EventBus.agent_fatigue_changed.connect(_on_agent_fatigue_changed)
	EventBus.agent_departed.connect(_on_agent_departed)
	_close_button.pressed.connect(hide_card)
	Log.info("Fiche agent prête — abonnée à l'EventBus (moral live, auto-fermeture au départ)")

## POINT D'ENTRÉE : ouvre/bascule la fiche sur l'agent donné (appelée par SelectionController).
## Lit l'identité + le moral courant UNE fois ; les variations suivent par signal.
func show_for(agent: Agent) -> void:
	if agent == null:
		return
	_agent_id = agent.agent_id
	_name_label.text = "%s #%d" % [agent.get_display_name(), agent.agent_id]
	_render_morale(agent.get_morale())
	_render_fatigue(agent.get_fatigue())
	visible = true
	Log.info("Fiche ouverte — agent %d (%s)" % [agent.agent_id, agent.get_display_name()])

## Ferme proprement la fiche (bouton Fermer, clic ailleurs, ou départ de l'agent affiché).
func hide_card() -> void:
	visible = false
	_agent_id = -1
	_shown_morale = -1
	_shown_fatigue = -1

# --- Handlers EventBus (filtrés sur l'agent affiché) ---

func _on_agent_morale_changed(agent_id: int, morale: int) -> void:
	if agent_id == _agent_id and is_showing():
		_render_morale(morale)  # mise à jour live du moral affiché

func _on_agent_fatigue_changed(agent_id: int, fatigue: int) -> void:
	if agent_id == _agent_id and is_showing():
		_render_fatigue(fatigue)  # mise à jour live de la fatigue affichée

func _on_agent_departed(agent_id: int) -> void:
	# Anti-fiche-fantôme : l'agent affiché a quitté l'open space → on referme.
	if agent_id == _agent_id:
		hide_card()

# --- Rendu ---

func _render_morale(morale: int) -> void:
	_shown_morale = morale
	_morale_label.text = "Moral : %d" % morale
	var severity: int = HudMath.morale_severity(
		morale, _BALANCE.hud_morale_warn_below, _BALANCE.hud_morale_critical_below)
	_apply_severity(_morale_label, severity)

## Rend la jauge Fatigue (Story 2.1). PAS de couleur de seuil ici : le signal de risque
## ≥80 / indicateur de burnout est la Story 2.2 (on n'anticipe aucun seuil de fatigue).
func _render_fatigue(fatigue: int) -> void:
	_shown_fatigue = fatigue
	_fatigue_label.text = "Fatigue : %d" % fatigue

## Applique la couleur de seuil à un label (présentation pure ; seuils en .tres). Identique HUD.
func _apply_severity(label: Label, severity: int) -> void:
	var color: Color = _COLOR_NORMAL
	if severity == HudMath.Severity.CRITICAL:
		color = _COLOR_CRITICAL
	elif severity == HudMath.Severity.WARNING:
		color = _COLOR_WARNING
	label.add_theme_color_override("font_color", color)

# --- Getters pour le test d'intégration (--card-smoke), modèle DecisionPopup/Hud ---

func is_showing() -> bool:
	return visible

func displayed_agent_id() -> int:
	return _agent_id

func displayed_morale() -> int:
	return _shown_morale

func displayed_fatigue() -> int:
	return _shown_fatigue
