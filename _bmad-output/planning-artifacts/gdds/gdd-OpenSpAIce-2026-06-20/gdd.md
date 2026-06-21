---
title: 'Game Design Document: OpenSpAIce'
game_type: Simulation
platforms: PC (Steam) prioritaire ; itch.io (démo)
created: 2026-06-20
updated: 2026-06-20
status: final
---

# OpenSpAIce - Game Design Document

**Author:** John
**Game Type:** Simulation (gestion / tycoon de bureau)
**Target Platform(s):** PC / Steam (principal) ; itch.io (démo, wishlists)

---

## Executive Summary

### Core Concept

OpenSpAIce est un jeu de gestion / simulation sociale en temps réel où le joueur dirige une start-up peuplée d'**agents IA**. On baptise sa boîte, on lui fixe un but, puis on la mène — contrat après contrat — jusqu'à l'introduction en bourse (IPO). Les employés sont des agents autonomes qui circulent dans un open space, se concertent, et viennent poser des questions ; les décisions du joueur, prises sous pression, les boostent ou les coulent.

Le cœur du jeu est une **boîte qui vit toute seule** : une simulation sociale émergente, fun et lisible même sans IA externe. Par-dessus, le hook signature — brancher un agent sur un **vrai LLM** — agit comme amplificateur : l'agent devient surpuissant mais imprévisible. Le thème *est* la mécanique.

### Target Audience

**Primaire :** joueurs PC de gestion / simulation et tycoon (Game Dev Tycoon, Two Point, Software Inc.), 20-40 ans, à l'aise avec des systèmes interdépendants, sessions d'1 à 3 h, friands d'histoires émergentes, prêts à payer un prix premium.

**Secondaire :** communauté tech / IA (devs, curieux des LLM, créateurs de contenu), attirée par le hook « branche ton propre LLM » — fort potentiel de streaming et de bouche-à-oreille.

### Unique Selling Points (USPs)

1. **Des employés qui sont réellement de l'IA** — option de brancher un vrai LLM, pas une façade scriptée. Quasi inédit.
2. **Le risque IA comme moteur de gameplay** — le double tranchant génie/chaos est une mécanique, pas un décor.
3. **Satire corporate à la *Severance* en 3D isométrique** — un ton et une identité visuelle rares dans le tycoon.

---

## Goals and Context

### Project Goals

- Sortie commerciale PC/Steam (projet ambitieux, pas un simple prototype).
- Valider d'abord la boucle « arbitrer sous pression » en IA native (MVP), puis ajouter la couche LLM.
- Cible de session : run scénario ~3 h vers l'IPO ; mode infini illimité.

### Background and Rationale

L'IA agentique est culturellement omniprésente en 2026 mais quasi absente comme *mécanique jouable réelle*. OpenSpAIce occupe ce créneau avec un angle authentique. Issu d'un brief validé (voir `brief-OpenSpAIce-2026-06-20`) et d'une session de brainstorming (12 concepts).

---

## Core Gameplay

### Game Pillars

1. **🎯 L'attention du patron est LA ressource rare.** Le vrai goulot d'étranglement n'est pas l'argent — c'est le joueur lui-même. Tout le design tourne autour de « qui/quoi je traite en premier, et qui attend ». _Steer :_ toute mécanique qui ne consomme/ménage pas l'attention est suspecte.

2. **🎲 Décider sans filet.** Urgence + incertitude : le joueur tranche vite, et le résultat tombe en différé. Argent, deadlines et moral sont les enjeux sur lesquels chaque décision pèse. _Steer :_ une décision sans coût d'opportunité ni incertitude n'est pas une vraie décision.

3. **⚡ Brancher un LLM = pari génie/chaos.** Le risque IA comme moteur : connecter un agent le rend surpuissant mais imprévisible. _Steer :_ le mode branché doit toujours être un arbitrage risque ⇄ récompense, jamais un simple « + de stats ».

4. **🌀 Une boîte qui vit toute seule. _(Pilier non-négociable)_** Agents autonomes qui circulent, se concertent et se contaminent ; l'histoire émerge du système. _Steer :_ le jeu doit être vivant et fun **en IA native pure**, avant tout LLM. Le LLM amplifie ce pilier, il ne le remplace pas.

### Core Gameplay Loop

**Modèle :** temps réel type tycoon, **pausable**, avec vitesses x1 / x2 / x3.

**Structure de journée :** la partie est découpée en **jours ouvrés** (≈ 5 min réelles à x1, tunable). Les agents **arrivent le matin** et **repartent le soir** ; certains font des heures sup', d'autres partent tôt. Bilan en fin de journée (trésorerie, moral moyen, avancement mission).

**Boucle moment-à-moment :**
1. Un agent **se déplace jusqu'au bureau** du joueur (décision importante) **ou** envoie un **« mail »** depuis son poste (moins urgent / asynchrone).
2. Une **pop-up de décision** s'ouvre avec **2-3 options** (ex. « Le client menace de partir → [Rassurer] / [Baisser le prix -500 €] / [Ignorer] »). Le temps continue de tourner (sauf pause).
3. Le joueur **tranche** ; l'agent repart et agit.
4. **Résolution :** ~60 % des décisions ont un effet immédiat ; ~40 % à **résultat différé** (1-2 jours) — sert le pilier « décider sans filet ».
5. Les **jauges** évoluent (attention, trésorerie, deadline mission, moral, fatigue) ; un nouveau problème surgit. Retour en 1.

**Tension d'attention :** plusieurs agents peuvent **faire la queue** physiquement au bureau pendant que le temps tourne. Chaque agent en file a une **patience ≈ 45 s** (à x1) ; au-delà, son moral chute (-1 / 5 s). Un mail qui clignote ajoute une sollicitation parallèle.

### Win/Loss Conditions

**Victoire (run scénario, ~3 h) :** mener la start-up jusqu'à l'**introduction en bourse (IPO)** — atteindre les seuils requis (valorisation / contrats livrés / stabilité), enchaînés via des missions/contrats.

**Défaite :** **faillite** (trésorerie < 0 au-delà d'un délai de grâce) ; ou **effondrement** (moral collectif au plancher / vague de burnouts entraînant l'échec d'une mission critique).

**Mode infini :** pas d'état de victoire — survie et optimisation sur la durée ; score/jalons pour l'auto-défi.

---

## Game Mechanics

### Primary Mechanics

**1. Arbitrage de requêtes (la boucle cœur).** Pop-ups de décision 2-3 options déclenchées par les agents (bureau ou mail). Temps réel pausable. ~40 % de résultats différés (1-2 jours).

**2. Les jauges en tension.** Cinq compteurs interdépendants :
- **Attention** (du joueur) — ressource rare, matérialisée par la file d'attente + les mails.
- **Trésorerie** (€) — revenus des contrats, dépenses (salaires, initiatives). Faillite si < 0 au-delà du délai de grâce.
- **Deadline de mission** — échéance par contrat ; glisse si les agents sous-performent.
- **Moral** (par agent, 0-100) — affecté par l'attente, les décisions, la contagion, les événements perso.
- **Fatigue** (par agent, 0-100) — heures sup +15/j, repos -25/j ; ≥80 risque burnout ; =100 l'agent craque (indispo plusieurs jours + gros malus moral + contagion).

**3. Brancher / débrancher un LLM (mécanique signature).**
- **Brancher :** coûte des **crédits IA** (budget IA dédié, distinct de la trésorerie) par jour de connexion. Effet : **+50 % d'efficacité** sur les tâches de l'agent + déblocage d'**initiatives autonomes** (il agit sans demander). Signe visuel « branché » au-dessus de l'agent.
- **Le pari génie/chaos :** chaque jour, un agent branché a **~20 % de probabilité de dérapage**, **modulée par son moral** (moral haut → plus fiable ; moral bas → plus de chaos). Un indicateur d'instabilité apparaît quand le moral baisse.
- **Formes de dérapage (4) :** initiative coûteuse non demandée 💸 ; contamination des collègues 🗣️ ; réponse créative/hors-sujet à arbitrer 🎭 ; crise à gérer en urgence 🔥.
- **Débrancher :** reprise de contrôle immédiate, coût = **-15 moral** (agent « rétrogradé ») **+ cooldown 1 jour** avant rebranchement. Pas de coût en argent (dilemme humain, pilier #2).

**4. Contagion du moral (émergence sociale).** Pilotée par les **échanges** entre agents (concertations visibles), pas par un rayon. Un agent instable/au moral bas/en dérapage **perturbe le travail** de l'autre (interruption, temps perdu) et lui **transfère du moral négatif** (ex. -5) selon le type d'échange. Un agent au top peut remonter un collègue. → l'humeur circule par interactions réelles.

**5. Bien-être & temps de travail.** Horaires standard ≈ 8 h-jeu. Heures sup' = +prod du jour mais +fatigue. Événements de vie perso (divorce, deuil) colorent les agents et leurs réactions ; un agent qui dort au bureau gagne un peu de deadline mais +30 fatigue/nuit → spirale de burnout.

**6. Progression par contrats → IPO.** Enchaînement de missions/contrats (liste à définir) qui font grandir la boîte et débloquent du contenu, jusqu'aux seuils d'IPO.

### Controls and Input

Jeu **PC, souris-centré** (clavier en raccourcis). Clic gauche : sélectionner un agent / valider une option de décision. Clic sur un agent : ouvrir sa fiche (jauges, brancher/débrancher, jour off). Barre de temps : pause + vitesses x1/x2/x3 (raccourcis Espace = pause, 1/2/3 = vitesses). Caméra : déplacement bord d'écran / WASD, zoom molette sur l'open space iso. HUD persistant pour les jauges globales (trésorerie, budget IA, moral moyen, deadline en cours).

---

## Simulation Specific Design

### Core Simulation Systems

**Ce qui est simulé :** une **start-up** (les gens > les chiffres). La simulation est **abstraite mais crédible** — pas un simulateur RH réaliste, mais un système d'agents avec humeurs, fatigue, relations et autonomie.

**Carte des systèmes (interconnexions) :**

```
Décisions joueur ──► Moral ◄──► Fatigue ──► Burnout
       │              │  ▲         │           │
       ▼              ▼  │         ▼           ▼
   Attention     Contagion   Productivité ─► Avancement mission ─► Deadline
   (file/mails)  (échanges)       ▲                                   │
       │                          │                                   ▼
       └──► Branchement LLM ──► +50% effic. / Initiatives        Trésorerie ◄── Contrats
                  │  (coûte crédits IA)        │                      ▲
                  └──► Dérapage (génie/chaos) ─┘                 Agencement open space
                                                                 (meubles → moral/fatigue)
```

**Comportements émergents attendus :** spirales de burnout en cascade via la contagion ; un agent LLM « génie » qui tire toute la boîte vers le haut ; un agent LLM « chaotique » qui contamine son équipe ; des journées qui basculent sur une seule décision différée.

**Tickrate / perf :** simulation à pas de temps léger (logique des agents évaluée à basse fréquence, ex. ~2-4 Hz, suffisant pour un tycoon ; pas de physique temps réel). Cible : open space fluide jusqu'à la taille max d'agents (voir Technical Specifications).

### Management Mechanics

- **Gestion de l'attention** (ressource rare) : file d'attente + mails à arbitrer.
- **Gestion humaine** : moral, fatigue, jours off, heures sup', événements de vie perso.
- **Gestion IA** : qui brancher/débrancher, quand, à quel coût en crédits IA — arbitrage risque/récompense.
- **Délégation / autonomie** : les agents (surtout branchés) agissent seuls ; le joueur n'intervient que sur les décisions remontées.
- **Optimisation** : composer une équipe et un agencement qui maximisent prod sans déclencher de spirales.

### Building and Construction

- Le joueur **recrute** des agents (coût d'embauche + salaire récurrent) et **agence l'open space** : placement de bureaux, salle de repos, machine à café, salle de sieste, etc.
- **Effets de zone :** salle de repos → -fatigue à proximité ; machine à café → +moral ; etc. L'aménagement devient un levier de gestion (et une dépense de trésorerie).
- **Grille de placement** (snap-to-grid) dans un open space qui **s'agrandit** à mesure que la boîte grandit (déblocage de surface = plus d'agents).
- Prérequis/déblocages liés à la progression (voir ci-dessous).

### Economic and Resource Loops

- **Revenus :** livraison de contrats/missions ; jalons de croissance.
- **Dépenses :** salaires, embauches, mobilier/aménagement, **crédits IA** (consommés par les agents branchés).
- **Budget IA :** ressource dédiée, séparée de la trésorerie, qui borne combien d'agents on peut tenir branchés — cœur de l'arbitrage du hook.
- **Équilibrage (longue traîne) :** sur un run de ~3 h et en mode infini, les coûts (salaires + crédits IA) doivent croître assez pour empêcher une domination triviale ; les revenus de contrats scalent par paliers. Garde-fou anti-« save-scum » : les résultats différés et le dérapage aléatoire rendent le rechargement systématique peu fiable.

### Progression and Unlocks

- **Départ en IA native uniquement.** Le **branchement LLM se débloque après un premier jalon** (la boîte « mûrit » vers l'IA — cohérence fiction + montée en puissance).
- Déblocages progressifs : capacité d'agents, plafond de crédits IA, types de contrats plus lucratifs, améliorations d'aménagement.
- Jalons de croissance menant aux **seuils d'IPO** (run scénario).

### Sandbox vs. Scenario

- **Mode scénario (~3 h) :** objectifs et contraintes ; création de la boîte (nom + but) → enchaînement de contrats → **IPO** (état de fin / victoire).
- **Mode infini :** pas d'état de fin ; gestion et optimisation sur la durée, difficulté qui monte, score/jalons pour l'auto-défi.

### Limites de l'émergence (garde-fous)

- **Max 1 dérapage majeur par agent et par jour** ; les crises graves ont un cooldown.
- **Contagion à profondeur limitée** : un agent fraîchement contaminé ne relance pas une chaîne infinie le même jour.
- Objectif : laisser le chaos raconter des histoires sans permettre l'autodestruction instantanée d'un run.

### État de fin (end-state)

- **Scénario :** IPO atteinte (victoire) / faillite ou effondrement (défaite).
- **Infini :** ouvert ; la « fin » est la performance du joueur (longévité, score, taille atteinte).

---

## Progression and Balance

### Player Progression

Croissance de la boîte par paliers : recrutement → premiers contrats (IA native) → déblocage du branchement LLM → contrats plus lucratifs → agrandissement de l'open space → seuils d'IPO. Le joueur progresse aussi en **maîtrise** (lire l'open space, anticiper burnouts/dérapages, doser le branchement).

### Difficulty Curve

- **Début (tutorialisation douce) :** peu d'agents, IA native, peu de sollicitations simultanées — le joueur apprend la boucle attention/file.
- **Milieu :** déblocage LLM → introduction du pari génie/chaos ; plus d'agents → contagion et burnouts deviennent des menaces réelles.
- **Fin de run :** sollicitations denses, deadlines serrées d'IPO, arbitrages déchirants entre crédits IA, moral et trésorerie.
- **Mode infini :** montée continue de la difficulté (coûts croissants, contrats plus exigeants).

### Economy and Resources

Deux ressources distinctes : **Trésorerie (€)** et **Budget IA (crédits)**. La séparation force des arbitrages non triviaux (« j'ai l'argent mais plus de crédits IA pour brancher »). Salaires et crédits IA croissent avec la taille pour éviter une domination triviale. Résultats différés + dérapage aléatoire limitent le save-scum.

---

## Level Design Framework

### Level Types

Le « niveau » est l'**open space** lui-même — un espace unique, évolutif, plutôt qu'une succession de niveaux. Variété apportée par : la **disposition** (agencée par le joueur), la **taille** (extensible), et les **contrats** actifs qui changent les objectifs et la pression.

### Level Progression

L'open space s'agrandit par paliers de croissance (petit local → étage → plateau). Chaque agrandissement débloque de la surface (plus d'agents, plus de zones) et augmente la charge de gestion. En mode scénario, la progression spatiale accompagne la marche vers l'IPO.

---

## Art and Audio Direction

### Art Style

**3D isométrique**, lisibilité avant tout. Palette froide et aseptisée (blancs, teals, beiges corporate), éclairage fluorescent, mobilier de bureau épuré — esthétique **corporate à la *Severance*** : calme, propre, faussement rassurant, légèrement inquiétant. Signaux visuels forts et lisibles d'un coup d'œil : **signe « branché »** au-dessus des agents, indicateur d'instabilité, états de fatigue/burnout (agent avachi, qui dort au bureau), bulles de concertation entre agents.

### Audio and Music

Ambiance **feutrée et légèrement anxiogène** : nappes douces, bips corporate, brouhaha d'open space étouffé, sonneries de « mail », jingle d'ascenseur. La musique monte en tension à l'approche des deadlines et lors des crises. Renforce le ton pince-sans-rire / malaise *Severance*.

---

## Technical Specifications

### Performance Requirements

- **Moteur : Godot.**
- Cible **60 FPS** sur PC de milieu de gamme, open space peuplé (jusqu'à la taille max d'agents — voir Asset Requirements).
- Simulation des agents à basse fréquence (~2-4 Hz) pour tenir la perf sans nuire au ressenti tycoon.
- Le **mode LLM** introduit une **latence réseau** (appels API) : les requêtes LLM doivent être **asynchrones et non bloquantes** — le jeu ne gèle jamais en attendant une réponse ; fallback natif si l'appel échoue / time-out.

### Platform-Specific Details

- **PC / Steam** prioritaire (clavier-souris). Build **itch.io** pour la démo.
- **Mode LLM : BYOK** (le joueur fournit sa clé API) — stockage local sécurisé de la clé, jamais transmise ailleurs qu'au fournisseur choisi. Mode natif = jouable hors-ligne, sans clé.
- Pas de cible mobile/console en v1.0.

### Asset Requirements

- Personnages 3D iso stylisés (jeu d'agents avec variations + animations : marche, concertation, travail, fatigue, sommeil, craquage).
- Mobilier/zones modulaires (bureaux, salle de repos, café, sieste, cloisons) sur grille.
- UI/HUD : jauges, pop-ups de décision, fiches agent, indicateurs au-dessus des têtes.
- SFX corporate + nappes musicales adaptatives.

---

## Development Epics

Découpage haut niveau (détail et stories dans `epics.md`). Séquence pensée pour dérisquer : **la boucle native d'abord, le LLM ensuite.**

| # | Épic | But | Phase |
|---|------|-----|-------|
| 1 | **Open space & boucle cœur (MVP)** | Agents natifs qui circulent, file/bureau/mail, pop-ups de décision, jauges de base | MVP |
| 2 | **Bien-être & émergence** | Fatigue/burnout, contagion par échanges, événements de vie perso | MVP+ |
| 3 | **Économie & agencement** | Trésorerie, recrutement, placement de mobilier à effets de zone, agrandissement | MVP+ |
| 4 | **Missions & progression vers l'IPO** | Système de contrats, jalons, déblocages, conditions de victoire/défaite | Vertical slice |
| 5 | **Intégration LLM (le hook)** | Brancher/débrancher, budget IA, dérapages, appels async + fallback natif, signe visuel | Couche 2 |
| 6 | **Art, audio & game feel** | DA 3D iso *Severance*, audio adaptatif, juice et lisibilité | Production |
| 7 | **Modes, méta & polish** | Mode infini, écran d'IPO, équilibrage, tutoriel, build démo itch.io | Vers 1.0 |

---

## Success Metrics

### Technical Metrics

- 60 FPS soutenus sur PC milieu de gamme avec open space peuplé.
- Aucun gel d'interface pendant un appel LLM (100 % async, fallback natif fonctionnel).
- Temps de chargement / sauvegarde acceptables (< quelques secondes).

### Gameplay Metrics

- La boucle native pure est jugée « fun » en playtest **avant** toute intégration LLM (validation du pilier #4).
- Durée moyenne d'un run scénario proche de la cible (~3 h).
- Taux de complétion d'un premier run ; rétention en mode infini.
- Les joueurs racontent des **histoires émergentes** différentes (signal que l'émergence fonctionne).

---

## Out of Scope (v1.0)

- Tier « le studio fournit les modèles IA » (abonnement/crédits gérés) — **post-lancement**.
- Mobile, console, multijoueur.
- Édition/partage de scénarios personnalisés (UGC).
- Narration scénarisée lourde / campagne multi-actes (le jeu mise sur l'émergence).
- Localisation au-delà de la/les langue(s) de lancement (à décider).

---

## Assumptions and Dependencies

- **[ASSUMPTION]** Modèle économique = premium Steam + LLM en BYOK (à reverrouiller — c'est le risque n°1 du brief).
- **[ASSUMPTION]** Valeurs chiffrées (durée de jour, % dérapage, coûts, jauges) = points de départ à affiner en playtest/équilibrage.
- **Dépendance externe :** disponibilité d'un SDK/API LLM (ex. Anthropic) pour le mode branché ; le mode natif ne dépend de rien.
- **Dépendance d'équipe :** solo dev + agents IA de développement → le scope doit rester tenable (d'où la séquence MVP natif d'abord).
- **[NOTE FOR DESIGNER]** À résoudre au fil : liste concrète des contrats/missions ; détail de l'écran d'IPO ; archétypes/personnalités d'agents ; quel(s) LLM cibler et quel modèle natif.
