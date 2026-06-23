extends CanvasLayer
## DayReport — écran de BILAN de fin de journée (Story 1.10). UI MODALE (CanvasLayer +
## Blocker ColorRect plein écran, modèle DecisionPopup 1.5) qui s'affiche sur
## EventBus.day_ended et RÉCAPITULE la journée écoulée :
##   - le jour terminé ;
##   - la Trésorerie (placeholder réservé « € — » → Épic 3, patron HUD 1.8) ;
##   - le MORAL MOYEN de l'équipe (agrégé par signaux, réutilise HudMath) ;
##   - l'Avancement mission (placeholder réservé « — » → Épic 4).
## Le bouton « Lancer la journée suivante » (confirm) appelle GameManager.start_next_day()
## → le matin suivant démarre (spawn via AgentSpawner). Tant que le bilan n'est pas validé,
## la simulation reste gelée (SimClock arrêté par GameManager au day_ended).
##
## CONSOMMATEUR PUR : le bilan LIT/agrège, il ne modifie AUCUN système (sauf déclencher
## start_next_day au clic). ⚠️ Instantané du moral robuste aux départs du soir : on met à
## jour _day_avg_morale sur agent_spawned/agent_morale_changed (cohorte présente), JAMAIS
## sur agent_departed (sinon la moyenne finit par ne refléter que le dernier agent restant ;
## or les agents partent échelonnés AVANT le rebouclage). 100 % événementiel (NFR1).
## Conventions : EventBus-only, pas de chemin absolu, seuils data-driven (.tres), pas de
## class_name (nœud de scène), réutilise HudMath (zéro nouveau module/seuil).
## [Source: epics.md Story 1.10 (FR15) ; game-architecture.md#Decision-Summary D9 ; #Event-System ; NFR1/NFR7/NFR11 ; 1-8…md (agrégation moral + couleur de seuil) ; 1-5…md (modal)]

const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")

## Couleurs de présentation du signal de seuil (NFR7) — choix d'UI (pas d'équilibrage),
## en dur ; SEULS les seuils numériques vivent dans le .tres. Convention identique au HUD.
const _COLOR_NORMAL: Color = Color(0.12, 0.13, 0.14)   # texte foncé sur DA claire
const _COLOR_WARNING: Color = Color(0.78, 0.50, 0.05)  # ambre
const _COLOR_CRITICAL: Color = Color(0.78, 0.13, 0.13) # rouge

@onready var _title_label: Label = %TitleLabel
@onready var _treasury_label: Label = %TreasuryLabel
@onready var _morale_label: Label = %MoraleLabel
@onready var _mission_label: Label = %MissionLabel
@onready var _confirm_button: Button = %ConfirmButton

## Agrégation du moral par signaux (modèle HUD 1.8) — aucune référence de nœud agent.
var _morale_by_agent: Dictionary = {}  # agent_id → int (moral courant)
## Instantané de la moyenne de la journée. Mis à jour tant que la cohorte est présente
## (spawn/variation), PAS sur les départs du soir → robuste à la vidange du dictionnaire.
var _day_avg_morale: int = -1

func _ready() -> void:
	# Reste actif même si la sim est gelée → bouton cliquable, à jour le jeu arrêté.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.agent_spawned.connect(_on_agent_spawned)
	EventBus.agent_morale_changed.connect(_on_agent_morale_changed)
	EventBus.agent_departed.connect(_on_agent_departed)
	EventBus.day_started.connect(_on_day_started)
	_confirm_button.pressed.connect(confirm)
	Log.info("Bilan de fin de journée prêt — abonné à l'EventBus (day_ended, moral)")

# --- Agrégation du moral (modèle HUD) — instantané robuste aux départs (cf. doc) ---

func _on_agent_spawned(agent_id: int) -> void:
	# Seed à la valeur data-driven que le spawner passe à Agent.setup (cohérent HUD).
	_morale_by_agent[agent_id] = roundi(_BALANCE.agent_initial_morale)
	_recompute_snapshot()

func _on_agent_morale_changed(agent_id: int, morale: int) -> void:
	_morale_by_agent[agent_id] = morale
	_recompute_snapshot()

func _on_agent_departed(agent_id: int) -> void:
	# Retrait du set présent UNIQUEMENT : on NE recompute PAS l'instantané (un départ du
	# soir ne doit pas écraser la moyenne de la journée par celle du dernier agent restant).
	_morale_by_agent.erase(agent_id)

func _on_day_started(_day: int) -> void:
	# Nouveau jour : réinitialise le cycle d'agrégation (le bilan est déjà fermé).
	_morale_by_agent.clear()
	_day_avg_morale = -1

func _recompute_snapshot() -> void:
	if not _morale_by_agent.is_empty():
		_day_avg_morale = HudMath.average_morale(_morale_by_agent.values())

# --- Affichage du bilan à la fin de journée ---

func _on_day_ended(day: int) -> void:
	_title_label.text = "Jour %d terminé" % day
	_treasury_label.text = "Trésorerie : € —"        # placeholder réservé (Épic 3)
	_mission_label.text = "Avancement mission : —"   # placeholder réservé (Épic 4)
	_render_morale(_day_avg_morale)
	visible = true

func _render_morale(avg: int) -> void:
	_morale_label.text = "Moral moyen de l'équipe : —" if avg < 0 else "Moral moyen de l'équipe : %d" % avg
	var severity: int = HudMath.morale_severity(
		avg, _BALANCE.hud_morale_warn_below, _BALANCE.hud_morale_critical_below)
	_apply_severity(_morale_label, severity)

## Applique la couleur de seuil à un label (présentation pure ; seuils en .tres).
func _apply_severity(label: Label, severity: int) -> void:
	var color: Color = _COLOR_NORMAL
	if severity == HudMath.Severity.CRITICAL:
		color = _COLOR_CRITICAL
	elif severity == HudMath.Severity.WARNING:
		color = _COLOR_WARNING
	label.add_theme_color_override("font_color", color)

## POINT D'ENTRÉE COMMUN du bouton ET du test (--report-smoke). Referme le bilan et
## relance la journée suivante. Le bilan ne touche RIEN d'autre (pas de spawn/nettoyage).
func confirm() -> void:
	if not is_showing():
		return
	visible = false
	GameManager.start_next_day()
	Log.info("Bilan validé — passage au jour suivant")

# --- Getters pour le test d'intégration (--report-smoke), modèle Hud / DecisionPopup ---

func is_showing() -> bool:
	return visible

func displayed_day_avg_morale() -> int:
	return _day_avg_morale

func displayed_morale_severity() -> int:
	return HudMath.morale_severity(
		_day_avg_morale, _BALANCE.hud_morale_warn_below, _BALANCE.hud_morale_critical_below)
