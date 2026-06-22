class_name Decision
extends Resource
## Template de contenu d'une pop-up de décision (Story 1.5) : un contexte textuel
## + 2 à 3 options actionnables. Resource .tres data-driven → le contenu vit dans
## data/decisions/, jamais codé en dur (D6). Objet de CONTENU pur : le decision_id
## runtime et l'agent_id concerné sont portés par le contrôleur (decision_popup.gd),
## PAS par le .tres. L'EFFET des options (immédiat ~60 % / différé ~40 %) est la
## Story 1.6 ; ici on ne décrit que ce qui s'affiche.
## [Source: epics.md Story 1.5 ; gdd.md §Boucle-cœur (pop-up 2-3 options) ; game-architecture.md D6]

## Texte de contexte présenté au joueur (ex. "Le client menace de partir.").
@export var context_text: String = ""
## Options actionnables (2 ou 3 — invariant vérifié par DecisionMath.is_valid_option_count).
@export var options: Array[DecisionOption] = []
