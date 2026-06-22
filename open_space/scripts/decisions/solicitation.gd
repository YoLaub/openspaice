class_name Solicitation
extends RefCounted
## Sollicitation d'un agent vers le joueur (Story 1.4). Deux canaux :
##   - DESK : décision importante → l'agent se déplace jusqu'au bureau du joueur.
##   - MAIL : sollicitation moins urgente → indicateur clignotant, sans déplacement.
## Objet de données PUR (aucune dépendance scène/autoload) → testable en isolation
## (modèle agent_action.gd / agent_context.gd). L'enum Channel est la SOURCE UNIQUE
## de vérité du canal (réutilisée par SolicitationSystem, EventBus, UI, tests).
## [Source: epics.md Story 1.4 ; game-architecture.md#System-Location-Mapping (scripts/decisions/)]

enum Channel { DESK = 0, MAIL = 1 }

var id: int = -1
var agent_id: int = -1
var channel: int = Channel.DESK

func _init(p_id: int = -1, p_agent_id: int = -1, p_channel: int = Channel.DESK) -> void:
	id = p_id
	agent_id = p_agent_id
	channel = p_channel
