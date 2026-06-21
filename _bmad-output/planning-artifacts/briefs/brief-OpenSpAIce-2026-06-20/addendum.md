# Addendum — Game Brief: OpenSpAIce

Détails qui dépassent le brief court mais nourriront le GDD / PRD.

## Options de monétisation considérées (matrice)

| Option | Pour | Contre | Verdict |
|---|---|---|---|
| **Gratuit + microtransactions** | Volume potentiel, faible barrière | Jure avec le ton premium/Severance ; live-ops lourd en solo ; coûts LLM non bornés sur joueurs gratuits | ❌ Écarté |
| **Premium + studio fournit l'IA** | Expérience clé-en-main pour le joueur | Coûts LLM récurrents sur un achat unique = marge qui s'érode ; responsabilité/infra | ⚠️ Pas en v1 (envisagé post-lancement en abonnement/crédits) |
| **Premium + BYOK (clé du joueur)** | Coût & responsabilité nuls pour le studio ; fit desktop/Steam ; garde le hook | Friction technique pour joueurs non-techos ; segment LLM plus étroit au départ | ✅ Reco v1 |
| **Hybride (recommandé)** | Natif gratuit-par-défaut = produit vendable autonome ; LLM en BYOK optionnel ; tier managé plus tard | À architecturer proprement (abstraction agent natif/LLM) | ✅ Direction retenue (à valider) |

**Décision pressentie :** Premium Steam, mode natif = jeu par défaut, LLM optionnel en BYOK, tier « IA fournie » étudié post-lancement.

## Détail de l'IA hybride (pour l'architecture)

- Les deux modes (natif / LLM) doivent partager **les mêmes tools/actions** d'agent — seul le « cerveau » qui décide change. → Abstraction `Agent.brain` à prévoir.
- Le branchement doit être réversible (débrancher) avec un coût gameplay (moral).
- Prototyper tôt : latence, coût par appel, et surtout l'**intérêt ludique** d'un agent LLM vs natif.

## Contexte repris du brainstorming (2026-06-20)

- 12 concepts, hook = « agents à double cerveau ».
- 4 pressions : attention / argent / deadlines / moral.
- Émergence : agents qui se concertent + contagion du moral.
- Dérapages LLM (4 formes) = générateur d'histoires émergentes.
- Voir : `_bmad-output/brainstorming-session-2026-06-20.md`.
