class_name AgentContext
extends RefCounted
## Snapshot minimal lu par un cerveau d'agent pour décider de son action.
## Objet de données pur (aucune dépendance scène/autoload) → testable.
## Extensible : moral, fatigue, sollicitations, etc. s'ajouteront aux épics suivants
## sans casser les brains existants.
## [Source: game-architecture.md#Novel-Pattern ; epics.md Story 1.2]

## L'agent a-t-il atteint son poste de travail ?
var arrived_at_post: bool = false

## Est-on dans la tranche du soir où cet agent doit repartir ?
## (calculé par agent : phase de journée >= phase de départ personnelle)
var evening: bool = false

## Story 1.4 : l'agent a-t-il une sollicitation PRÉSENTIELLE (bureau) en cours ?
## Si oui, le cerveau le dirige vers le bureau du joueur (action GO_TO_DESK).
## Posé par SolicitationSystem via l'agent ; le canal MAIL ne touche pas ce champ.
var has_desk_solicitation: bool = false

func _init(p_arrived_at_post: bool = false, p_evening: bool = false, p_has_desk_solicitation: bool = false) -> void:
	arrived_at_post = p_arrived_at_post
	evening = p_evening
	has_desk_solicitation = p_has_desk_solicitation
