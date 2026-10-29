# Changelog

All notable changes to this project are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.1.1] - 2026-10-29

### Fixed
- `check`: a project with `tests/` but no PHPUnit config fails with a clear message instead of PHPUnit's usage text.

## [1.1.0] - 2026-10-29

### Added
- Deploy script: optional `WORKER_STOP_CMD`/`WORKER_START_CMD` (stop workers before the migrations, start them on every exit) and `FPM_RELOAD_CMD` (reload PHP-FPM for a fresh OPcache).
- Deploy script: trims `var/log/deploy.log` to `DEPLOY_LOG_KEEP_LINES` (default 5000) in place.
- Deploy job records a GitHub deployment (environment `beta`/`live`, commit, webhook result) when the caller grants `deployments: write`; the `ci.yml` template grants it.

### Changed
- The reusable workflow sets permissions per job instead of workflow-wide, so the deploy job can use the caller's `deployments: write`.

## [1.0.1] - 2026-10-29

### Fixed
- The deploy job runs on the `runs-on` runner like the checks instead of a hard-coded `ubuntu-latest`; it never started on accounts without GitHub-hosted minutes.

## [1.0.0] - 2026-10-29

### Added
- Tool configs: php-cs-fixer 3.95.27 (`@PER-CS3x0`, `declare_strict_types`, ordered imports), PHPStan 2 (level 6, Symfony/Doctrine/PHPUnit/deprecation extensions), Rector 2 (PHP + composer-based sets).
- `bin/symfony-standards` with `check`, `fix`, `init`, `steps`.
- Reusable workflow `symfony-ci.yml` with optional MySQL service and deploy webhook after green checks.
- Templates: project tool configs, `ci.yml`, `deploy/post-deploy.sh`, `deploy/deploy.env`.
- Workflow inputs `runs-on` (JSON) and `timeout-minutes`; on self-hosted runners `setup-php` runs in self-hosted mode and the database comes from `CI_DATABASE_*` instead of a service container.

[Unreleased]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/jostkleigrewe/symfony-standards/releases/tag/v1.0.0
