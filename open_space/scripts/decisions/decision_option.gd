class_name DecisionOption
extends Resource
## Une option actionnable d'une pop-up de décision (Story 1.5). Resource .tres
## data-driven (modèle agent_archetype.gd). À ce stade, l'option ne porte que son
## LIBELLÉ affiché sur le bouton ; les champs d'EFFET (montant €, type immédiat/
## différé, jauge impactée…) seront ajoutés par la Story 1.6 (résolution) — laissé
## extensible ici, sans les anticiper.
## [Source: epics.md Story 1.5 ; game-architecture.md#Decision-Summary D6 ; #System-Location-Mapping]

## Libellé affiché sur le bouton de l'option (ex. "Rassurer", "Baisser le prix -500 €").
@export var label: String = ""

## Code d'EFFET abstrait de l'option (Story 1.6). Émis tel quel dans
## EventBus.decision_resolved(decision_id, outcome) à la résolution (immédiate ou
## différée). À ce stade, les jauges concrètes n'existent pas encore (Moral = Story 1.7,
## Trésorerie = Épic 3, Fatigue = Épic 2) : `outcome` est un identifiant que les systèmes
## de jauges FUTURS traduiront en deltas réels. Laissé extensible (deltas typés viendront
## avec ces jauges) — non anticipé ici. 0 = effet neutre/non spécifié.
@export var outcome: int = 0
