# Stratégie de branching Git

Workflow **GitFlow adapté** pour le projet AFI (1 seul développeur + relectures).

## Branches

| Branche | Rôle | Base | Fusion |
|---|---|---|---|
| `main` | Production, toujours déployable | — | `develop` ou `hotfix/*` (PR obligatoire) |
| `develop` | Intégration des fonctionnalités | `main` | `feature/*` (PR) |
| `feature/*` | Développement d'une story (ex. `feature/story-14-scan-ocr`) | `develop` | PR vers `develop` |
| `hotfix/*` | Correctif urgent en production | `main` | PR vers `main` **et** `develop` |

## Règles

1. **Nommage** : `feature/<story>-<description>`, `hotfix/<description>`.
2. **PR obligatoires** vers `main` et `develop` (pas de push direct) : template `.github/PULL_REQUEST_TEMPLATE.md`.
3. **CI obligatoire verte** avant fusion : lint, SAST, tests unitaires, intégration, e2e.
4. **Versionnage** : tag `vX.Y.Z` sur `main` → déclenche le build et le push d'image + déploiement.
5. `main` protégée (idéalement) : review + statuts CI requis.

## Déclencheurs GitHub Actions

- **CI** (`.github/workflows/ci.yml`) : sur `push` de `develop`/`main` et **toutes les PR**.
- **CD** (`.github/workflows/cd.yml`) : sur `push` de `main` et tags `v*`.

## Cycle type

```
feature/… → PR → CI verte → fusion develop → CI → test
develop   → PR → CI verte → fusion main  → CD (image + SonarQube + déploiement K8S)
hotfix/…  → PR → fusion main + develop  → CD
```