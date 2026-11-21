# Changelog

All notable changes to this project are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.5.0] - 2026-11-21

### Added
- `check`: new step `importmap-install` right after `composer-audit`, before `cs-fixer`, `cache-warmup` and `phpunit`. It runs `importmap:install`, so `assets/vendor/` (not versioned) exists before the cache warmup and the tests; when the download fails it says that the network or jsDelivr (`cdn.jsdelivr.net`) is most likely unreachable. Skipped without `importmap.php` or without the console command. Covered by `tests/importmap-install.sh`.
- Deploy script: prod guard before anything changes. It asks Symfony's own `Dotenv::bootEnv()` (from `vendor/`, same logic as `symfony/runtime`: `.env.local.php`, `.env*` files in order, real environment variables first) for the effective `APP_ENV`/`APP_DEBUG` and stops unless they are `prod`/`0`. On the first deploy (no `vendor/`) the check runs right after `composer install`. `ALLOW_NON_PROD_ENV=1` in `deploy/deploy.env` turns the stop into a warning for intended exceptions. Covered by `tests/deploy-env.sh`. Background: on 2026-11-21 a beta and a live install ran with `APP_ENV=dev`/`APP_DEBUG=1`, `/_profiler/phpinfo` was public. Update `deploy/post-deploy.sh` in your projects (it stays identical to the template); a server whose `.env.local` lacks `APP_ENV=prod` while `.env` says `dev` now stops instead of deploying a dev app.
- The self-test workflow runs every `tests/*.sh` and lints them with shellcheck.

### Changed
- php-cs-fixer, house style B: `blank_line_before_statement` (only `return`) and `phpdoc_align` (fixer defaults: vertical, spacing 1) on top of `@PER-CS3x0`. **Projects get a one-time format diff on update:** run `vendor/bin/symfony-standards fix`, commit the result as its own commit and add its hash to `.git-blame-ignore-revs` (`git config blame.ignoreRevsFile .git-blame-ignore-revs`; GitHub reads the file automatically), so `git blame` skips it.
- Deploy script: a real `APP_ENV` environment variable now wins over `.env.local`, as it does in Symfony.
- The `ci.yml` template references the reusable workflow at `@v1.5.0`.

## [1.4.0] - 2026-11-20

### Changed
- The `ci.yml` template references the reusable workflow with the pinned tag `@v1.3.0` instead of the moving `@v1`; README "Versioning" describes pinned tags. The `v1` tag stays in place for existing projects but is deprecated.

### Added
- Template `.github/dependabot.yml` for `composer` and `github-actions`: monthly at 06:00 Europe/Berlin, minor + patch grouped per ecosystem plus a `security` group, major updates ignored, no `target-branch` (pull requests go to the default branch `develop`), commits `chore(deps): …`. The github-actions entry raises the pinned workflow tag by pull request. `init` copies it like every other template and keeps an existing file.

## [1.3.0] - 2026-11-20

### Added
- `check`: new first step `app-secret` (id `app-secret-in-env`) warns when `APP_SECRET` has a value in the committed `.env`; the value is never printed. `.env.local*`, `.env.dev` and `.env.test` are not checked; without `.env` the step is skipped.
- `check --strict` (or `SYMFONY_STANDARDS_STRICT=1`) turns warnings into failures. Without it warnings keep the run green and show up in the summary (`✅ all checks passed (1 warning)`) and, on GitHub Actions, as annotations.
- `tests/app-secret.sh` covers the step and runs in the self-test workflow.

## [1.2.1] - 2026-11-16

### Fixed
- Re-release of 1.2.0 without code changes: the `v1.2.0` tag was moved after its first publication, and Packagist keeps published versions immutable, so `v1.2.0` there still resolves to the 1.1.1 code. Use 1.2.1 to get the `defaultTestSuite` change.

## [1.2.0] - 2026-11-12

### Changed
- `check`: when the PHPUnit config sets `defaultTestSuite` (e.g. `unit`), PHPUnit runs every `<testsuite>` by name, so integration and application suites are never skipped silently.

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

[Unreleased]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/jostkleigrewe/symfony-standards/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/jostkleigrewe/symfony-standards/releases/tag/v1.0.0
