class_name BrainComponent
extends Node
## Point d'entrée unique du cerveau d'un agent (porté comme nœud enfant).
## Détient le cerveau courant et expose tick(ctx) -> AgentAction.
## Story 1.2 : NativeBrain uniquement (synchrone). L'Épic 5 ajoutera LLMBrain,
## connect_llm()/disconnect_llm() et le fallback natif — sans changer les appelants
## (tick() pourra alors faire `await _brain.decide(ctx)`).
## [Source: game-architecture.md#Novel-Pattern ; ADR-1 ; epics.md Story 5.3]

var _brain: AgentBrain = NativeBrain.new()

## Demande une décision au cerveau courant pour le contexte fourni.
func tick(ctx: AgentContext) -> AgentAction:
	return _brain.decide(ctx)
