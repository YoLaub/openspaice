---
title: 'Game Architecture'
project: 'OpenSpAIce'
date: '2026-06-20'
author: 'John'
version: '1.0'
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9]
status: 'complete'
engine: 'Godot 4.6.3-stable'
platform: 'PC / Steam (principal) ; itch.io (démo)'

# Source Documents
gdd: '_bmad-output/planning-artifacts/gdds/gdd-OpenSpAIce-2026-06-20/gdd.md'
epics: '_bmad-output/planning-artifacts/gdds/gdd-OpenSpAIce-2026-06-20/epics.md'
brief: '_bmad-output/planning-artifacts/briefs/brief-OpenSpAIce-2026-06-20/brief.md'
---

# Game Architecture

## Executive Summary

L'architecture de **OpenSpAIce** est conçue pour **Godot 4.6.3-stable**, ciblant **PC / Steam** (démo itch.io), en vrai 3D isométrique (caméra orthographique).

**Décisions architecturales clés :**

- **Dual-Mode Agent Brain** (Strategy) : `NativeBrain` et `LLMBrain` exposent les mêmes actions via un `ActionRegistry` partagé ; on swap le cerveau à chaud sur un `BrainComponent`.
- **`LLMService` async/fallback/BYOK** : appels `HTTPRequest` non bloquants, timeout + fallback natif → le jeu ne gèle jamais ; clé API stockée localement.
- **`SimClock` ~3 Hz découplé du rendu 60 FPS** : la simulation tourne à basse fréquence ; les agents LLM « réfléchissent » sur plusieurs ticks sans bloquer.

**Structure :** organisation hybride, 10 systèmes cœur, communication via `EventBus`.
**Patterns :** 1 pattern nouveau (Dual-Mode Brain) + 4 standards, garantissant la cohérence entre agents IA de dev.

**Prêt pour :** la phase de création des épics et l'implémentation.

## Document Status

**Steps Completed:** 9 of 9 — **Status: complete**

---

---

## Project Context

### Game Overview

**OpenSpAIce** — jeu de gestion/simulation sociale (tycoon de bureau) où l'on dirige une start-up d'agents IA jusqu'à l'IPO. Hook : brancher des agents sur un vrai LLM (puissant mais imprévisible).

### Technical Scope

**Platform:** PC / Steam (principal) ; itch.io (démo). Clavier-souris. Le mode natif tourne hors-ligne, solo.
**Genre:** Simulation (haute complexité). **Engine:** Godot.
**Project Level:** Complexité globale HAUTE (un seul driver « réseau » = appels IA sortants ; sinon mono-joueur local).

### Core Systems

| Système | Complexité | Réf. GDD |
|---|---|---|
| Simulation des agents (comportements, tick ~2-4 Hz) | Moyenne-Haute | Core Simulation Systems |
| Abstraction `Agent.brain` (natif ⇄ LLM) | Haute | Mécaniques §3, Épic 5.1 |
| Intégration LLM async + fallback + BYOK | Haute (risque n°1) | Technical Specs, Épic 5.4/5.7 |
| Jauges interdépendantes (moral, fatigue, trésorerie, budget IA) | Moyenne | Mécaniques §2 |
| Contagion par échanges (events inter-agents) | Moyenne | Mécaniques §4 |
| Pathfinding + rendu iso (open space extensible, grille) | Faible-Moyenne | Building/Construction |
| Décisions/pop-ups (immédiat vs différé) | Faible-Moyenne | Boucle cœur |
| Contrats/missions + progression/déblocages | Faible-Moyenne | Progression |
| Sauvegarde/chargement (état complet de la sim) | Moyenne | Tech Specs |

### Technical Requirements

60 FPS open space peuplé ; sim agents ~2-4 Hz ; appels LLM 100 % async non bloquants + fallback natif ; BYOK (clé stockée localement, jamais relayée ailleurs qu'au fournisseur choisi) ; sauvegarde de l'état complet de la simulation.

### Complexity Drivers

1. Abstraction `Agent.brain` (natif ⇄ LLM partagent les mêmes tools/actions).
2. Intégration LLM async + fallback + BYOK.
3. Déterminisme/équilibrage (résultats différés, RNG des dérapages, anti save-scum).

### Technical Risks

- Latence / coût / fiabilité du LLM → prototyper tôt sur 1 agent.
- Fuite de complexité pour un solo dev → séquence MVP « natif d'abord ».
- Pas de netcode (mono-joueur) → risque réseau limité aux appels API sortants.

---

## Engine & Framework

### Selected Engine

**Godot 4.6.3-stable** (branche stable éprouvée ; 4.7-stable disponible mais trop récente — choix prudence).

**Rationale :** open-source/gratuit (marge préservée), excellent pour 2D/3D iso mono-joueur, export PC + HTML5 (démo itch.io), GDScript = itération rapide en solo, large communauté.

### Engine-Provided Architecture

| Component | Solution | Notes |
|---|---|---|
| Rendu | Renderer 2D/3D Godot | Iso en 2D ou 3D (à trancher étape 4) |
| Scènes | Système Scene/Node + instanciation | Base de l'architecture |
| Physique | 2D/3D intégrée | Peu sollicitée (pas de physique temps réel) |
| Audio | Bus audio | Musique adaptative + SFX |
| Input | Input Map | Actions clavier-souris configurables |
| Build/Export | Templates PC + HTML5 | Win/Linux/Mac + démo web itch.io |
| Scripting | GDScript (C# possible) | GDScript par défaut |

### Remaining Architectural Decisions

1. Abstraction `Agent.brain` (natif ⇄ LLM, tools partagés)
2. Couche LLM async + fallback + BYOK (critique)
3. Boucle de simulation (tick ~2-4 Hz) + structure données agents
4. Jauges / events / contagion
5. Sauvegarde/chargement (état complet sim)
6. Organisation projet (dossiers, autoloads, conventions)

### AI Development Tooling (MCP)

- **Gopeak Godot MCP** (`HaD0Yun/Gopeak-godot-mcp`) — ~95+ outils, lancement `npx`, sans plugin Godot. Vérifier l'activité du repo avant install.
- **Context7** (`upstash/context7`) — doc Godot à jour pour les agents IA.
- (Détails d'install repris dans la section Development Environment.)

---

## Architectural Decisions

### Decision Summary

| # | Catégorie | Décision | Rationale |
|---|---|---|---|
| D1 | Cerveau d'agent | Pattern Strategy : `AgentBrain` → `NativeBrain` / `LLMBrain`, tools partagés, `BrainComponent` | Hook propre, branchement à chaud |
| D2 | Couche LLM | Autoload `LLMService` via `HTTPRequest` async, timeout 10 s, fallback `NativeBrain`, BYOK chiffré local | Jamais de gel ; coût/responsabilité nuls |
| D3 | Simulation | Autoload `SimClock` ~3 Hz, découplé du rendu 60 FPS | Perf + async LLM naturel |
| D4 | Communication | `EventBus` (signals) + autoloads `GameManager` / `SaveManager` | Découplage |
| D5 | États agents | State Machine (idle / travail / concertation / file / fatigue / burnout) | Lisibilité, extensible |
| D6 | Données | Resources `.tres` data-driven (agents, contrats, meubles) | Éditable, scalable |
| D7 | Sauvegarde | Fichiers locaux (binaire/JSON via `SaveManager`), état complet ; Steam Cloud plus tard | Offline-first |
| D8 | Grille | `GridMap` (3D) pour placement snap | Cohérent vrai 3D |
| D9 | UI/HUD | Control nodes + `CanvasLayer` | Natif Godot |
| D10 | Langage | GDScript typé statiquement | Idéal solo |
| D11 | Steam | GodotSteam (intégré Épic 7) | Succès / Cloud / achievements |
| D12 | Rendu | Vrai 3D + caméra orthographique (Forward+) | Look Severance, GridMap, rotation/zoom |

### Architecture Decision Records (clés)

**ADR-1 — Agent.brain (Strategy).** `AgentBrain` (base) → `NativeBrain` (FSM/règles) + `LLMBrain`, même interface `decide(context) -> Action` sur un **registre de tools/actions commun**. Les agents portent un `BrainComponent` ; brancher/débrancher = swap du brain (le natif reste le fallback). Garantit que natif et LLM partagent exactement les mêmes capacités (GDD Épic 5.1).

**ADR-2 — LLMService (async / fallback / BYOK).** Autoload utilisant `HTTPRequest` (non bloquant). File de requêtes, timeout ~10 s, retry limité ; échec/time-out → fallback `NativeBrain` pour ce tick. Clé API stockée en `user://` (chiffrée), transmise uniquement au fournisseur choisi. SDK/fournisseur LLM = **[NOTE]** à choisir (cf. questions ouvertes du GDD).

**ADR-3 — SimClock découplé.** Tick logique ~3 Hz indépendant du rendu 60 FPS ; un agent LLM peut « réfléchir » sur plusieurs ticks sans bloquer la simulation ni l'affichage. Les résultats différés et le RNG des dérapages s'ordonnancent sur cette horloge.

---

## Cross-cutting Concerns

Ces patterns s'appliquent à TOUS les systèmes et doivent être suivis par chaque implémentation (humaine ou agent IA de dev).

### Error Handling

**Stratégie :** hybride — objets `Result`/codes de retour pour les flux d'échec attendus (appel LLM, contrat raté) + `EventBus` pour les erreurs à signaler (notification joueur).

- Une erreur **ne met jamais le jeu en pause** et n'est jamais fatale pour la simulation.
- Critique vs récupérable : échec réseau LLM = récupérable → log WARN + **fallback `NativeBrain`**, transparent pour le joueur.

```gdscript
func _on_request_completed(result, code, headers, body) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        Logger.warn("LLM call failed (%d) → fallback natif" % code)
        EventBus.llm_call_failed.emit(_agent_id, "http_%d" % code)
        _fallback_to_native(_agent_id)
        return
    _apply_llm_decision(body)
```

### Logging

**Format :** texte lisible en dev. **Destination :** console + fichier `user://logs/`.
**Niveaux :** ERROR / WARN / INFO / DEBUG (DEBUG désactivé en release).
**Toujours loggés :** appels LLM (latence, coût estimé, fallback), transitions de jour, game-over.

```gdscript
Logger.info("Jour %d terminé — tréso %d, moral moyen %d" % [day, cash, avg_morale])
```

### Configuration

Trois couches :
- **Constantes** — `const` GDScript (valeurs immuables).
- **Valeurs d'équilibrage** — Resources `.tres` (durée de jour, % dérapage, coûts) tunables sans toucher au code.
- **Réglages joueur** — `user://settings.cfg` (`ConfigFile`), dont la **clé API BYOK chiffrée**.

### Event System

**Pattern :** `EventBus` autoload, **signals typés**, traitement synchrone côté jeu (l'async vit dans `LLMService`). Nommage `snake_case` au passé.

```gdscript
# autoloads/event_bus.gd
signal agent_burned_out(agent_id: int)
signal decision_resolved(decision_id: int, outcome: int)
signal llm_call_failed(agent_id: int, reason: String)
signal day_ended(day: int)
```

### Debug Tools

- **Console de debug** (toggle F1, dev only) : forcer un dérapage, régler les jauges, accélérer le temps, simuler un échec LLM, basculer un agent natif↔LLM.
- **Overlay visuel** des jauges/états d'agents.
- Exclus du build release (gardés derrière un flag de build dev).

---

## Project Structure

### Organization Pattern

**Pattern :** Hybride (types au niveau racine, features à l'intérieur). **Rationale :** clarté pour un solo dev + agents IA de dev, et frontières nettes entre systèmes.

### Directory Structure

```
open_space/
├── project.godot
├── addons/                      # GoPeak MCP, GUT (tests), GodotSteam
├── assets/
│   ├── models/                  # agents, mobilier (3D)
│   ├── materials/  textures/  shaders/
│   ├── audio/{music,sfx}/
│   └── fonts/
├── scenes/
│   ├── main/                    # main.tscn, boot
│   ├── world/                   # open_space.tscn, grille, caméra ortho
│   ├── agents/                  # agent.tscn (+ BrainComponent, StateMachine)
│   ├── furniture/               # bureaux, salle repos, café… (instançables sur grille)
│   └── ui/                      # hud, pop-ups décision, fiche agent, écrans méta, écran IPO
├── scripts/
│   ├── autoloads/               # GameManager, EventBus, SimClock, LLMService,
│   │                            #   SaveManager, AudioManager, Logger, ConfigService
│   ├── agents/
│   │   ├── brain/               # agent_brain.gd, native_brain.gd, llm_brain.gd
│   │   ├── tools/               # registre des actions/tools partagés natif↔LLM
│   │   └── states/              # idle, work, confer, queue, fatigue, burnout
│   ├── systems/                 # gauges, morale_contagion, wellbeing, contracts,
│   │                            #   economy(cash+ai_credits), progression
│   ├── decisions/               # decision_popup logic, résolution immédiate/différée
│   ├── llm/                     # client http, prompt build, parsing, fallback
│   └── utils/
├── data/                        # Resources .tres
│   ├── agents/                  # archétypes/personnalités
│   ├── contracts/               # missions
│   ├── furniture/               # effets de zone
│   └── balance/                 # valeurs tunables (jour, %dérapage, coûts)
├── tests/{unit,integration}/    # GUT
└── docs/                        # gdd, architecture (copies/refs)
```

### System Location Mapping

| Système | Emplacement |
|---|---|
| `Agent.brain` (natif/LLM) | `scripts/agents/brain/` + tools partagés `scripts/agents/tools/` |
| Couche LLM async/BYOK | `scripts/llm/` + autoload `LLMService` |
| Boucle de simulation | autoload `SimClock` |
| Jauges / contagion / bien-être | `scripts/systems/` |
| Contrats / progression / économie | `scripts/systems/` + données `data/*` |
| Décisions (pop-ups) | `scripts/decisions/` + scènes `scenes/ui/` |
| Sauvegarde | autoload `SaveManager` |

### Naming Conventions

| Élément | Convention | Exemple |
|---|---|---|
| Fichiers/dossiers | `snake_case` | `native_brain.gd` |
| Classes | `PascalCase` (`class_name`) | `AgentBrain` |
| Fonctions/variables | `snake_case` | `decide_next_action` |
| Constantes | `UPPER_SNAKE` | `MAX_FATIGUE` |
| Signals | `snake_case` au passé | `agent_burned_out` |

### Architectural Boundaries

- Un agent **ne parle jamais directement** à `LLMService` — toujours via son `BrainComponent`.
- Les systèmes communiquent via `EventBus` (signals), pas par appels directs en dur.
- **Jamais de chemins de nœuds absolus** (`@onready` / `%UniqueName` / signals uniquement).
- Les valeurs d'équilibrage vivent dans `data/balance/*.tres`, jamais codées en dur dans la logique.

---

## Implementation Patterns

### Novel Pattern — Dual-Mode Agent Brain

**But :** natif et LLM exposent exactement les mêmes actions ; on swap le cerveau sans toucher au reste de l'agent.

```gdscript
# scripts/agents/brain/agent_brain.gd — interface commune
class_name AgentBrain
extends RefCounted

func decide(ctx: AgentContext) -> AgentAction:
    push_error("decide() must be overridden")
    return null

# native_brain.gd — FSM/règles, déterministe, instantané
class_name NativeBrain
extends AgentBrain

func decide(ctx: AgentContext) -> AgentAction:
    if ctx.fatigue >= 80: return ActionRegistry.make("request_rest")
    if ctx.has_blocking_question: return ActionRegistry.make("ask_boss", ctx.question)
    return ActionRegistry.make("work_on", ctx.current_task)

# llm_brain.gd — async, passe par LLMService, mêmes actions
class_name LLMBrain
extends AgentBrain

func decide(ctx: AgentContext) -> AgentAction:
    var raw := await LLMService.request_decision(ctx.to_prompt(), ActionRegistry.schema())
    if raw == null:                              # échec/timeout
        return NativeBrain.new().decide(ctx)     # fallback transparent
    return ActionRegistry.parse(raw)             # valide contre le registre
```

```gdscript
# BrainComponent (node sur l'agent) — point d'entrée unique, swap à chaud
class_name BrainComponent
extends Node

var _brain: AgentBrain = NativeBrain.new()

func connect_llm() -> void: _brain = LLMBrain.new()
func disconnect_llm() -> void:
    _brain = NativeBrain.new()
    EventBus.agent_unplugged.emit(get_parent().agent_id)   # -15 moral géré ailleurs

func tick(ctx: AgentContext) -> AgentAction:
    return await _brain.decide(ctx)
```

**Règle d'or :** une nouvelle capacité d'agent = on l'ajoute à `ActionRegistry`, jamais en dur dans un brain. Garantit la parité natif ↔ LLM.

### Communication Patterns

**Pattern :** `EventBus` (signals typés). Référence directe réservée à parent → enfant connu.

### Entity Patterns

**Création :** `AgentFactory` lit un Resource d'archétype `.tres` et configure l'agent instancié ; mobilier via factory + placement `GridMap`. Pas d'object pooling en v1 (effectifs modestes).

### State Patterns

**Pattern :** State Machine (idle / work / confer / queue / fatigue / burnout), un nœud `State` par état sous un `StateMachine`.

### Data Patterns

**Accès :** Resources `.tres` data-driven + autoloads pour l'accès. Valeurs d'équilibrage dans `data/balance/`.

### Consistency Rules

| Pattern | Convention | Application |
|---|---|---|
| Actions d'agent | Toujours via `ActionRegistry` | Parité natif/LLM |
| Inter-systèmes | `EventBus`, jamais d'appel dur | Découplage |
| Appel LLM | Via `BrainComponent` → `LLMService`, jamais direct | Fallback garanti |
| Équilibrage | `.tres` dans `data/balance/` | Zéro magic number |

---

## Architecture Validation

### Validation Summary

| Check | Résultat | Notes |
|---|---|---|
| Compatibilité des décisions | ✅ PASS | Godot + patterns + transverses cohérents |
| Couverture du GDD | ✅ PASS | 10/10 systèmes couverts |
| Complétude des patterns | ✅ PASS | création/comm/états/erreurs/données/events |
| Mapping des épics | ✅ PASS | 7/7 épics mappés à l'archi |
| Complétude du document | ✅ PASS | aucun placeholder bloquant |

### Coverage Report

- **Systèmes couverts :** 10/10
- **Patterns définis :** 1 nouveau (Dual-Mode Brain) + 4 standards
- **Décisions prises :** 12 (D1-D12)

### Issues / Open Items

- **[NOTE]** Choix du fournisseur/SDK LLM exact — non bloquant, à trancher à l'attaque de l'Épic 5.

### Validation Date

2026-06-20 — Statut global : **PASS**

---

## Development Environment

### Prerequisites

- **Godot 4.6.3-stable** (éditeur + templates d'export PC/HTML5)
- **Node.js** (pour les serveurs MCP)
- **Git** (versioning)
- Une **clé API LLM** (BYOK) — uniquement pour tester le mode branché (Épic 5)

### AI Tooling (MCP Servers)

| MCP Server | Rôle | Install |
|---|---|---|
| **Gopeak Godot MCP** (`HaD0Yun/Gopeak-godot-mcp`) | Inspection/édition directe de scènes & scripts par l'IA (~95+ outils) | `npx -y gopeak`, pointer vers l'exécutable Godot + un profil d'outils |
| **Context7** (`upstash/context7`) | Doc Godot à jour pour l'IA | Serveur MCP standard |

> Vérifier l'activité des repos MCP avant install (l'écosystème bouge vite).

### First Steps

1. Créer le projet Godot `open_space/` selon la structure de dossiers définie.
2. Poser les autoloads de base (`EventBus`, `SimClock`, `GameManager`, `Logger`, `ConfigService`).
3. Configurer les serveurs MCP (ci-dessus) pour le dev assisté par IA.
4. Attaquer l'**Épic 1** (open space + boucle cœur, IA native pure) — le LLM vient en Épic 5.

