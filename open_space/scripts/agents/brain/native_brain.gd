class_name NativeBrain
extends AgentBrain
## Cerveau natif — règles déterministes et instantanées (le fallback du projet).
## Périmètre Story 1.2 : aller au poste → travailler → repartir le soir.
## Story 1.4 : si une sollicitation présentielle est en cours, l'agent va au bureau
## du joueur (GO_TO_DESK) — le soir prime (un agent qui doit partir ne va pas au bureau).
## Logique pure (aucune dépendance scène/autoload) → testable en isolation.
## Toutes les actions passent par ActionRegistry (parité natif ↔ LLM, ADR-1).
## [Source: game-architecture.md#Novel-Pattern ; epics.md Story 1.2/1.4]

func decide(ctx: AgentContext) -> AgentAction:
	if ctx.evening:
		return ActionRegistry.make(ActionRegistry.LEAVE)
	if ctx.has_desk_solicitation:
		return ActionRegistry.make(ActionRegistry.GO_TO_DESK)
	if not ctx.arrived_at_post:
		return ActionRegistry.make(ActionRegistry.GO_TO_POST)
	return ActionRegistry.make(ActionRegistry.WORK)
