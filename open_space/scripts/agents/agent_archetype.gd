class_name AgentArchetype
extends Resource
## Archétype d'agent data-driven (Resource .tres). L'AgentFactory lit ces valeurs
## pour configurer chaque agent instancié → variété visible sans toucher au code.
## Story 1.2 : identité, vitesse, teinte placeholder, décalage de départ du soir.
## Moral/fatigue/personnalité s'ajouteront aux épics suivants.
## [Source: game-architecture.md#Decision-Summary D6 ; #Entity-Patterns]

## Nom lisible de l'archétype (debug / fiche agent plus tard).
@export var display_name: String = "Agent"
## Vitesse de déplacement (m/s) le long du chemin de navigation.
@export var move_speed: float = 3.0
## Teinte du placeholder visuel (la DA réelle + animations = Épic 6).
@export var tint: Color = Color(0.45, 0.55, 0.65)
## Décalage de départ du soir : 0.0 = part au seuil du soir, >0 = part plus tard.
## Échelonne les départs ("certains plus tôt, d'autres plus tard").
@export var departure_offset: float = 0.0
