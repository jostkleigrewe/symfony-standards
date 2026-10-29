# Changelog

All notable changes to this project are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Tool configs: php-cs-fixer 3.95.27 (`@PER-CS3x0`, `declare_strict_types`, ordered imports), PHPStan 2 (level 6, Symfony/Doctrine/PHPUnit/deprecation extensions), Rector 2 (PHP + composer-based sets).
- `bin/symfony-standards` with `check`, `fix`, `init`, `steps`.
- Reusable workflow `symfony-ci.yml` with optional MySQL service and deploy webhook after green checks.
- Templates: project tool configs, `ci.yml`, `deploy/post-deploy.sh`, `deploy/deploy.env`.
