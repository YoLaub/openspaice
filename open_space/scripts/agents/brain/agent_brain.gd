class_name AgentBrain
extends RefCounted
## Interface commune des cerveaux d'agent (pattern Strategy, ADR-1).
## NativeBrain l'implémente ici ; LLMBrain l'implémentera en Épic 5 avec EXACTEMENT
## la même signature, en passant par le même ActionRegistry. On swap le cerveau sur
## un BrainComponent sans toucher au reste de l'agent.
## [Source: game-architecture.md#Novel-Pattern ; ADR-1]

## Décide de la prochaine action à partir du contexte. À surcharger.
## Synchrone et instantané pour NativeBrain ; LLMBrain introduira un chemin async
## (await) en Épic 5 — la signature reste compatible.
func decide(_ctx: AgentContext) -> AgentAction:
	push_error("AgentBrain.decide() doit être surchargé")
	return null
