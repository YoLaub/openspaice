class_name AgentAction
extends RefCounted
## Action décidée par un cerveau d'agent (résultat de AgentBrain.decide()).
## Objet de données pur (aucune dépendance scène/autoload) → testable en isolation.
## Toujours construit via ActionRegistry.make() pour garantir la parité natif ↔ LLM.
## [Source: game-architecture.md#Novel-Pattern ; #Consistency-Rules]

var type: StringName
var data: Dictionary

func _init(action_type: StringName, action_data: Dictionary = {}) -> void:
	type = action_type
	data = action_data
