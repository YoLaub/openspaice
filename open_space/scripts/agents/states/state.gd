class_name AgentState
extends Node
## État de base de la State Machine d'agent (pattern : un nœud State par état).
## Story 1.2 : idle / work / move. Les états confer / queue / fatigue / burnout
## viendront s'ajouter aux Épics 2+ sans refonte (mêmes hooks enter/exit/update).
## [Source: game-architecture.md#State-Patterns ; #Decision-Summary D5]

## Agent propriétaire (injecté par l'agent au _ready).
var agent: Agent = null

## Appelé à l'entrée dans l'état.
func enter() -> void:
	pass

## Appelé à la sortie de l'état.
func exit() -> void:
	pass

## Appelé chaque frame physique tant que l'état est actif (mouvement fluide 60 FPS).
func physics_update(_delta: float) -> void:
	pass
