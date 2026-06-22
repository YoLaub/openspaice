class_name DecisionCatalog
extends Resource
## Catalogue de décisions data-driven (Story 1.5) : deux listes de templates Decision,
## une par canal de sollicitation (DESK / MAIL, Story 1.4). Resource .tres → le contenu
## éditable vit dans data/decisions/, zéro texte codé en dur (D6). La sélection est PURE
## (testable) : à partir d'un tirage déjà fait, pick() renvoie un template du bon canal.
## Réutilise l'enum canal Solicitation.Channel (source unique de vérité) — aucun enum
## canal redéclaré ici.
## [Source: epics.md Story 1.5 AC#1/#5 ; game-architecture.md#System-Location-Mapping ; D6]

## Décisions présentées quand l'agent vient au bureau (canal DESK — décisions importantes).
@export var desk_decisions: Array[Decision] = []
## Décisions présentées via un mail (canal MAIL — sollicitations moins urgentes).
@export var mail_decisions: Array[Decision] = []

## Choisit un template Decision pour le canal donné, à partir d'un tirage `roll` (∈ [0,1)).
## Fallback : si la liste du canal est vide, bascule sur l'autre ; si tout est vide → null
## (le contrôleur gère le null défensivement, sans casser la simulation — NFR11).
func pick(channel: int, roll: float) -> Decision:
	var primary: Array[Decision] = desk_decisions if channel == Solicitation.Channel.DESK else mail_decisions
	var fallback: Array[Decision] = mail_decisions if channel == Solicitation.Channel.DESK else desk_decisions
	var list: Array[Decision] = primary if not primary.is_empty() else fallback
	if list.is_empty():
		return null
	return list[DecisionMath.pick_index(roll, list.size())]
