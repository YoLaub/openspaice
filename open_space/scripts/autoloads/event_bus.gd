extends Node
## Autoload EventBus — bus de signals typés pour la communication inter-systèmes.
## Convention : signals en snake_case, au passé. Les systèmes émettent/écoutent
## ici plutôt que de s'appeler en dur.
## [Source: game-architecture.md#Event-System ; #Architectural-Boundaries]

# --- Signals fondateurs (posés en Story 1.1, consommés plus tard) ---
signal agent_burned_out(agent_id: int)
signal decision_resolved(decision_id: int, outcome: int)
signal llm_call_failed(agent_id: int, reason: String)
signal day_ended(day: int)

# --- Cycle de journée & agents (Story 1.2) ---
## Émis au début de chaque matinée (nouveau jour) → déclenche le spawn des agents.
signal day_started(day: int)
## Émis quand un agent vient d'apparaître dans l'open space.
signal agent_spawned(agent_id: int)
## Émis quand un agent a quitté l'open space (fin de journée / départ).
signal agent_departed(agent_id: int)

# --- Contrôle du temps (Story 1.3) ---
## Émis à chaque bascule pause/reprise (true = en pause). Le HUD (Story 1.8) s'y abonnera.
signal game_paused(is_paused: bool)
## Émis quand le niveau de vitesse change (1/2/3). Le HUD (Story 1.8) s'y abonnera.
signal speed_changed(speed_level: int)

# --- Sollicitations (Story 1.4) ---
## Émis quand un agent lève une sollicitation. channel = Solicitation.Channel
## (0 = DESK / bureau, 1 = MAIL). Le compteur HUD (Story 1.8) s'y abonnera.
signal solicitation_raised(agent_id: int, channel: int)
## Émis quand le joueur ouvre une sollicitation (clic). Consommé par la pop-up de
## décision (Story 1.5) ; alimente aussi le compteur HUD (Story 1.8).
signal solicitation_opened(agent_id: int, channel: int)

# --- Décisions (Story 1.5) ---
## Émis quand le joueur CHOISIT une option de la pop-up de décision. option_index est
## l'index (0-based) de l'option choisie dans Decision.options. Consommé par la
## RÉSOLUTION immédiate/différée (Story 1.6, qui émettra ensuite decision_resolved) ;
## alimentera aussi le compteur HUD (Story 1.8). ⚠️ NE PAS confondre avec le signal
## fondateur decision_resolved (effet appliqué) — ici on signale seulement le CHOIX.
signal decision_chosen(decision_id: int, option_index: int)

# --- Résolution des décisions (Story 1.6) ---
## Émis par la pop-up au CHOIX d'une option : porte l'EFFET (outcome) de l'option choisie
## (data-driven .tres). Consommé par DecisionResolver (Story 1.6) qui classe immédiat
## (~60 %) vs différé (~40 %) puis émet le signal fondateur decision_resolved. Distinct de
## decision_chosen (« clic UI », pour le compteur HUD Story 1.8, qui n'a pas besoin de
## l'effet) : ici on transporte l'issue À RÉSOUDRE, pas l'index du bouton.
signal decision_committed(decision_id: int, outcome: int)

# --- Moral & file d'attente (Story 1.7) ---
## Émis par l'agent quand sa jauge Moral (0-100) change effectivement (uniquement sur
## variation réelle, pas à chaque tick). morale = valeur entière courante. Consommé plus
## tard par la fiche agent (Story 1.9) et le HUD (Story 1.8). Source de variation à ce
## stade : l'impatience en file d'attente au bureau (DeskQueue).
signal agent_morale_changed(agent_id: int, morale: int)

# --- Fatigue (Story 2.1) ---
## Émis par l'agent quand sa jauge Fatigue (0-100) change effectivement (uniquement sur
## variation réelle, pas à chaque tick — jumeau de agent_morale_changed). fatigue = valeur
## entière courante. Consommé par la fiche agent (1.9, affichage live) et par l'AgentSpawner
## (report inter-jour : il mémorise la dernière fatigue connue avant le départ du soir).
signal agent_fatigue_changed(agent_id: int, fatigue: int)
