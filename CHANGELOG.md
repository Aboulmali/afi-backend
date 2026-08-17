# Changelog

Le format s'inspire de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).
Ce projet respecte [Semantic Versioning](https://semver.org/lang/fr/).

Chaque release correspond à un tag `vX.Y.Z` ; la section du numéro de version
est extraite automatiquement par le workflow de release.

## [Unreleased]

### Amélioré

- Seuil de couverture des tests unitaires : 70 % minimum (gate bloquant en CI)
- Scan de sécurité **Trivy hebdomadaire** (lundi 06:00 UTC, déclenchable à
  la main) avec rapport SARIF publié dans l'onglet Security du dépôt

## [0.2.0] - 2026-08-17

### Ajouté

- **Cache Redis** (TTL 60 s) sur `/dashboard/balance` et `/dashboard/stats` :
  servis depuis le cache, invalidation automatique à chaque écriture de
  transaction (create/update/delete), repli transparent vers PostgreSQL si
  Redis est indisponible
- **Redis déployé sur EKS** (`afi-prod`) : Deployment + Service, probes,
  runAsNonRoot, politique LRU 128 Mo
- **OCR EasyOCR activé dans l'image de production** (scan de factures
  fonctionnel via l'API)
- **Stockage S3 en production** : bucket `afi-invoices-eu-west-3`,
  `UPLOADS_BUCKET` câblé via Helm, repli local en dev
- **Ingress de production** : host `api.samapoche.sn` (TLS à activer une
  fois le DNS enregistré)
- Tests unitaires du cache Redis et de l'invalidation (13 tests → **55
  tests**, couverture ≈ 81 %)

### Corrigé

- SAST bandit `B110` (try/except/pass) dans le service de cache
- Alarmes Pydantic v2 : `class Config` remplacé par `ConfigDict`/`SettingsConfigDict`

### Sécurité

- Redis restreint au cluster (pas de port exposé), args `--maxmemory` LRU,
  conteneur non-root avec capabilities drop

## [0.1.0] - 2026-08-17

Première release de l'API REST AFI — Assistant Financier Intelligent.

### Ajouté

- Authentification **JWT + bcrypt** : inscription, connexion, profil, mot de
  passe oublié (token 2 h) et réinitialisation
- **Transactions** : création, édition, suppression, listing avec filtres
  (type, catégorie, dates, recherche) ; catégories
- **Budgets** avec alertes 80 % / 100 % et historique des alertes
- **Dashboard** : solde, stats du mois (+ comparaison), dépenses par
  catégorie (week/month/year), évolution mensuelle sur 6 mois
- **IA** (OpenAI si `OPENAI_API_KEY`, sinon moteur local sur les vraies
  données) : insights automatiques, conseils personnalisés (sauvegarde et
  notation 1-5), chat avec historique et suggestions, bilan mensuel + export
  PDF
- **Notifications** : liste (all/unread/read), lecture individuelle ou
  totale, réglages du rappel 20 h, rappels du jour avec logique anti-doublon
- **OCR de factures** (EasyOCR, optionnel) : scan → validation → transaction
- **Import SMS** bancaires : analyse → confirmation → transactions
- **Planificateur** au démarrage : rappels à l'heure configurée, bilans
  mensuels le 1er du mois
- **Infrastructure & Ops** : Docker multi-étages (+ profil OCR optionnel),
  `docker-compose`, chart Helm + K8s (EKS AWS), Terraform (VPC, EKS, RDS
  PostgreSQL 15, S3, ECR), observabilité (Prometheus, Grafana, Loki,
  Alertmanager) ; `terraform validate` au CI
- **CI/CD** : 42 tests unitaires (SQLite), 5 tests intégration/e2e sur
  PostgreSQL 15 réel, lint `ruff`, SAST `bandit` + `hadolint`, scan d'image
  `Trivy` (HIGH/CRITICAL bloquant), DAST OWASP ZAP, SonarCloud avec quality
  gate bloquante, image Docker poussée sur ECR (tags sha/latest) et
  déploiement Helm sur EKS (`afi-prod`) avec rollback automatique en cas
  d'échec
- **API** : OpenAPI/Pydantic, health check, middleware request-id robuste

### Sécurité

- Mots de passe hashés `bcrypt`, authentification JWT, secrets injectés via
  K8s (`afi-secrets`, jamais dans le dépôt)
- Scan d'image Trivy (bloquant) et DAST ZAP dans le pipeline

### Corrigé

- Scan OCR : réponse `400` au lieu d'un `500` quand le dossier soumis est
  invalide
- Dates normalisées timezone-aware, CORS vide, noms de clés de secrets K8s
  et namespace Helm alignés
- Version Python analysée par Sonar alignée sur le CI (3.12)
- Durcissement global : ingress NGINX, nettoyage des ressources obsolètes