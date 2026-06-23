class_name HudMath
extends RefCounted
## Logique PURE d'agrégation & de classification de seuils du HUD (Story 1.8) —
## transformations sans état ni dépendance scène/autoload → testables en isolation
## (`--script`), modèle MoraleMath / SolicitationMath / DecisionResolutionMath.
## La COLLECTE (dictionnaires d'agents/sollicitations) et le RENDU vivent dans Hud ;
## ici, uniquement les fonctions pures de calcul.
## [Source: game-architecture.md#Data-Patterns ; #System-Location-Mapping ; epics.md Story 1.8 (FR9/FR14/NFR7)]

## Niveaux de sévérité d'une jauge globale (pour le signal visuel de seuil, NFR7).
enum Severity { NORMAL = 0, WARNING = 1, CRITICAL = 2 }

## Moyenne ENTIÈRE arrondie d'une liste de moraux (0-100).
## Défensif : liste vide → -1 (sentinelle « aucun agent » → le HUD affiche « — »).
static func average_morale(values: Array) -> int:
	if values.is_empty():
		return -1
	var sum: float = 0.0
	for v: Variant in values:
		sum += float(v)
	return roundi(sum / float(values.size()))

## Classe le moral moyen selon deux seuils : critique sous `critical_below`,
## alerte sous `warn_below`, sinon normal. Les bornes sont EXCLUSIVES (avg == seuil
## → niveau du dessus). Défensif : moyenne < 0 (sentinelle vide) → NORMAL (pas
## d'alerte sans agent présent).
static func morale_severity(average: int, warn_below: int, critical_below: int) -> int:
	if average < 0:
		return Severity.NORMAL
	if average < critical_below:
		return Severity.CRITICAL
	if average < warn_below:
		return Severity.WARNING
	return Severity.NORMAL

## Classe la charge d'attention (file + mails) : alerte quand le nombre en attente
## atteint le seuil (>=). Défensif : seuil <= 0 → toujours NORMAL (évite une alerte
## permanente si mal configuré).
static func attention_severity(pending_count: int, warn_at: int) -> int:
	if warn_at > 0 and pending_count >= warn_at:
		return Severity.WARNING
	return Severity.NORMAL
