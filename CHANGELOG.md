# Changelog

All notable changes to this project are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-10-29

### Added
- Tool configs: php-cs-fixer 3.95.27 (`@PER-CS3x0`, `declare_strict_types`, ordered imports), PHPStan 2 (level 6, Symfony/Doctrine/PHPUnit/deprecation extensions), Rector 2 (PHP + composer-based sets).
- `bin/symfony-standards` with `check`, `fix`, `init`, `steps`.
- Reusable workflow `symfony-ci.yml` with optional MySQL service and deploy webhook after green checks.
- Templates: project tool configs, `ci.yml`, `deploy/post-deploy.sh`, `deploy/deploy.env`.
- Workflow inputs `runs-on` (JSON) and `timeout-minutes`; on self-hosted runners `setup-php` runs in self-hosted mode and the database comes from `CI_DATABASE_*` instead of a service container.

[Unreleased]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/jostkleigrewe/symfony-standards/releases/tag/v1.0.0
