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
