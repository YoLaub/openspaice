class_name NativeBrain
extends AgentBrain
## Cerveau natif — règles déterministes et instantanées (le fallback du projet).
## Périmètre Story 1.2 : aller au poste → travailler → repartir le soir.
## Logique pure (aucune dépendance scène/autoload) → testable en isolation.
## Toutes les actions passent par ActionRegistry (parité natif ↔ LLM, ADR-1).
## [Source: game-architecture.md#Novel-Pattern ; epics.md Story 1.2 AC#1/#2/#3]

func decide(ctx: AgentContext) -> AgentAction:
	if ctx.evening:
		return ActionRegistry.make(ActionRegistry.LEAVE)
	if not ctx.arrived_at_post:
		return ActionRegistry.make(ActionRegistry.GO_TO_POST)
	return ActionRegistry.make(ActionRegistry.WORK)
