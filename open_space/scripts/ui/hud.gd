extends CanvasLayer
## Hud — première brique du HUD PERSISTANT du projet (Story 1.8). Surcouche 2D
## (CanvasLayer + Control/Label natifs, D9) toujours affichée, qui AGRÈGE et MONTRE
## l'état déjà émis sur l'EventBus :
##   - Jour en cours (day_started / GameManager.day_count) ;
##   - Moral moyen des agents présents (agent_spawned + agent_morale_changed + agent_departed) ;
##   - Charge d'ATTENTION (pilier #1) : compteur de file bureau + compteur de mails
##     (solicitation_raised / solicitation_opened / agent_departed) ;
##   - Emplacement Trésorerie RÉSERVÉ (placeholder « € — » → Épic 3).
##
## CONSOMMATEUR PUR : le HUD LIT/agrège, il n'émet RIEN et ne modifie AUCUN système.
## Reconstruit ses compteurs par signaux (pas de référence de nœud) → robuste à
## l'ordre d'instanciation, symétrique file ↔ mails, et anti-fantôme (un agent qui
## part purge ses compteurs SANS solicitation_opened — cf. SolicitationSystem).
##
## ⚠️ mouse_filter = IGNORE sur les Control (cf. .tscn) → les clics traversent vers la
## caméra / SelectionController : le HUD ne vole JAMAIS un clic de sélection (inverse
## de la pop-up modale 1.5). 100 % événementiel (aucun _process) → coût/frame nul (NFR1).
## Conventions : EventBus-only, pas de chemin absolu, seuils data-driven (.tres).
## [Source: epics.md Story 1.8 ; game-architecture.md#Decision-Summary D9 ; #Event-System ; #Configuration ; NFR1/NFR7/NFR11]

const SolicitationC := preload("res://scripts/decisions/solicitation.gd")
const _BALANCE: SimBalance = preload("res://data/balance/sim_balance.tres")

## Couleurs de présentation du signal de seuil (NFR7). Ce sont des choix d'UI (pas de
## l'équilibrage) → en dur ici ; SEULS les seuils numériques vivent dans le .tres.
const _COLOR_NORMAL: Color = Color(0.12, 0.13, 0.14)   # texte foncé sur DA claire
const _COLOR_WARNING: Color = Color(0.78, 0.50, 0.05)  # ambre
const _COLOR_CRITICAL: Color = Color(0.78, 0.13, 0.13) # rouge

@onready var _day_label: Label = %DayLabel
@onready var _morale_label: Label = %MoraleLabel
@onready var _file_label: Label = %FileLabel
@onready var _mail_label: Label = %MailLabel
@onready var _treasury_label: Label = %TreasuryLabel
@onready var _time_label: Label = %TimeLabel

## État reconstruit par signaux (EventBus-only, aucune référence de nœud agent).
var _morale_by_agent: Dictionary = {}  # agent_id → int (moral courant)
var _desk_agents: Dictionary = {}      # agent_id → true (sollicitation DESK en attente)
var _mail_agents: Dictionary = {}      # agent_id → true (sollicitation MAIL en attente)

func _ready() -> void:
	# Reste actif même en pause → reflète l'état (et reçoit les signaux) le jeu gelé.
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.day_started.connect(_on_day_started)
	EventBus.agent_spawned.connect(_on_agent_spawned)
	EventBus.agent_morale_changed.connect(_on_agent_morale_changed)
	EventBus.agent_departed.connect(_on_agent_departed)
	EventBus.solicitation_raised.connect(_on_solicitation_raised)
	EventBus.solicitation_opened.connect(_on_solicitation_opened)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.speed_changed.connect(_on_speed_changed)
	_render_all()
	Log.info("HUD prêt — abonné à l'EventBus (jour, moral, file/mails, temps)")

# --- Handlers EventBus (mettent à jour l'état puis re-rendent la section concernée) ---

func _on_day_started(day: int) -> void:
	_render_day(day)

func _on_agent_spawned(agent_id: int) -> void:
	# Le 1er agent_morale_changed n'arrive qu'AU CHANGEMENT → on seed à la valeur
	# data-driven que le spawner passe à Agent.setup (cohérent, pas de divergence).
	_morale_by_agent[agent_id] = roundi(_BALANCE.agent_initial_morale)
	_render_morale()

func _on_agent_morale_changed(agent_id: int, morale: int) -> void:
	_morale_by_agent[agent_id] = morale
	_render_morale()

func _on_agent_departed(agent_id: int) -> void:
	# Anti-fantôme : un départ purge le moral ET les compteurs d'attention (un agent
	# parti ne déclenche PAS solicitation_opened côté SolicitationSystem).
	_morale_by_agent.erase(agent_id)
	_desk_agents.erase(agent_id)
	_mail_agents.erase(agent_id)
	_render_morale()
	_render_attention()

func _on_solicitation_raised(agent_id: int, channel: int) -> void:
	if channel == SolicitationC.Channel.DESK:
		_desk_agents[agent_id] = true
	else:
		_mail_agents[agent_id] = true
	_render_attention()

func _on_solicitation_opened(agent_id: int, _channel: int) -> void:
	# Retrait des deux sets par sécurité (un agent n'a qu'une sollicitation à la fois).
	_desk_agents.erase(agent_id)
	_mail_agents.erase(agent_id)
	_render_attention()

func _on_game_paused(_is_paused: bool) -> void:
	_render_time()

func _on_speed_changed(_level: int) -> void:
	_render_time()

# --- Rendu ---

func _render_all() -> void:
	_render_day(GameManager.day_count)
	_render_morale()
	_render_attention()
	_render_time()
	_treasury_label.text = "€ —"  # placeholder réservé (Trésorerie = Épic 3)

func _render_day(day: int) -> void:
	_day_label.text = "Jour %d" % day

func _render_morale() -> void:
	var avg: int = HudMath.average_morale(_morale_by_agent.values())
	_morale_label.text = "Moral moyen : —" if avg < 0 else "Moral moyen : %d" % avg
	var severity: int = HudMath.morale_severity(
		avg, _BALANCE.hud_morale_warn_below, _BALANCE.hud_morale_critical_below)
	_apply_severity(_morale_label, severity)

func _render_attention() -> void:
	var desk: int = _desk_agents.size()
	var mail: int = _mail_agents.size()
	_file_label.text = "File bureau : %d" % desk
	_mail_label.text = "Mails : %d" % mail
	# La charge d'attention TOTALE (file + mails) pilote le signal de seuil sur les
	# deux compteurs (lisibilité d'un coup d'œil de la pression, pilier #1 / NFR7).
	var severity: int = HudMath.attention_severity(desk + mail, _BALANCE.hud_attention_warn_at)
	_apply_severity(_file_label, severity)
	_apply_severity(_mail_label, severity)

func _render_time() -> void:
	_time_label.text = "PAUSE" if GameManager.is_paused else "x%d" % GameManager.speed_level

## Applique la couleur de seuil à un label (présentation pure ; seuils en .tres).
func _apply_severity(label: Label, severity: int) -> void:
	var color: Color = _COLOR_NORMAL
	if severity == HudMath.Severity.CRITICAL:
		color = _COLOR_CRITICAL
	elif severity == HudMath.Severity.WARNING:
		color = _COLOR_WARNING
	label.add_theme_color_override("font_color", color)

# --- Getters pour le test d'intégration (--hud-smoke), modèle DecisionPopup ---

func displayed_day() -> int:
	return GameManager.day_count

func displayed_file_count() -> int:
	return _desk_agents.size()

func displayed_mail_count() -> int:
	return _mail_agents.size()

func displayed_average_morale() -> int:
	return HudMath.average_morale(_morale_by_agent.values())

func displayed_morale_severity() -> int:
	return HudMath.morale_severity(
		displayed_average_morale(), _BALANCE.hud_morale_warn_below, _BALANCE.hud_morale_critical_below)
