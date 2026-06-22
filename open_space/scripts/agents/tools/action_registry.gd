class_name ActionRegistry
extends RefCounted
## Registre central des actions d'agent — SOURCE UNIQUE DE VÉRITÉ des capacités.
## Règle d'or (ADR-1) : toute nouvelle capacité d'agent s'ajoute ICI, jamais en
## dur dans un brain. Garantit que NativeBrain et (plus tard) LLMBrain exposent
## exactement les mêmes actions.
## [Source: game-architecture.md#Novel-Pattern ; #Consistency-Rules ; ADR-1]
##
## Périmètre Story 1.2 : locomotion + travail de base. Les actions de décision,
## de bien-être, de branchement LLM, etc. viendront s'enregistrer ici aux épics
## correspondants (parité garantie). En Épic 5 : schema() + parse(raw) pour le LLM.

const GO_TO_POST: StringName = &"go_to_post"
const WORK: StringName = &"work"
const IDLE: StringName = &"idle"
const LEAVE: StringName = &"leave"
## Story 1.4 : l'agent se déplace jusqu'au bureau du joueur pour une sollicitation
## présentielle (canal DESK). Capacité de locomotion → enregistrée ICI (golden rule
## ADR-1) ; en Épic 5 le LLMBrain disposera de la même action (parité garantie).
const GO_TO_DESK: StringName = &"go_to_desk"

const KNOWN: Array[StringName] = [GO_TO_POST, WORK, IDLE, LEAVE, GO_TO_DESK]

## Fabrique l'action demandée après vérification qu'elle est bien enregistrée.
static func make(action_type: StringName, data: Dictionary = {}) -> AgentAction:
	assert(action_type in KNOWN, "Action inconnue (non enregistrée) : %s" % action_type)
	return AgentAction.new(action_type, data)

## Vrai si l'action est connue du registre (utile pour valider une sortie externe,
## p.ex. une réponse LLM en Épic 5).
static func is_known(action_type: StringName) -> bool:
	return action_type in KNOWN
