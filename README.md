# symfony-standards

Shared quality and deploy standards for Symfony apps — one place for the tool configs, one command that runs
the same checks locally and in CI, a reusable GitHub workflow with a test gate before the deploy, and a deploy
script template.

```bash
composer require --dev jostkleigrewe/symfony-standards
vendor/bin/symfony-standards init     # copies missing templates, never overwrites
vendor/bin/symfony-standards fix      # php-cs-fixer + rector, once for existing code
vendor/bin/symfony-standards check    # what CI runs
```

## What you get

| Part | Where | Purpose |
|---|---|---|
| Tool configs | `config/` (used via one-line project files) | php-cs-fixer (PER-CS 3.0 + `declare_strict_types`), PHPStan (level 6, Symfony/Doctrine/PHPUnit/deprecation extensions), Rector (PHP and framework sets from your installed versions) |
| `check` | `bin/symfony-standards` | `composer validate`/`audit`, php-cs-fixer, PHPStan, Rector dry-run, `lint:container`/`yaml`/`twig`, `doctrine:schema:validate --skip-sync`, `importmap:audit`, PHPUnit. Steps the project does not use (no Doctrine, no importmap, no tests) are skipped. |
| Reusable workflow | `.github/workflows/symfony-ci.yml` | Runs `check`; after green checks a push to `develop`/`master` calls the beta/live deploy webhook. |
| Deploy script | `templates/deploy/post-deploy.sh` | composer install, assets, fresh cache, migrations, project hook, worker restart, self-test |

The package requires the tools (php-cs-fixer pinned exactly, the others with `^`), so one `require --dev` is enough.

## Project files after `init`

```
.php-cs-fixer.dist.php     one line → config/php-cs-fixer.php (extra rules as 2nd argument)
phpstan.neon               includes config/phpstan.neon; paths, level, baseline live here
rector.php                 one line → config/rector.php (chain ->withSkip()/->withRules())
.github/workflows/ci.yml   calls the reusable workflow — set php-version
deploy/post-deploy.sh      keep identical to the template
deploy/deploy.env          versioned deploy settings (PHP binary, PATH, required vars) — no secrets
```

Symfony Flex recipes may already have created `.php-cs-fixer.dist.php`; `init` warns when an existing file does
not use the standard. Replace it with the template.

Existing projects: run `fix` once, then create a PHPStan baseline
(`vendor/bin/phpstan analyse --generate-baseline`, add it to `phpstan.neon`). New code must not add entries.

## Deploy with test gate

```
push develop/master → CI checks → green → POST deploy webhook → hosting pulls → deploy/post-deploy.sh
```

1. Repository secrets `DEPLOY_WEBHOOK_BETA` / `DEPLOY_WEBHOOK_LIVE` = the hosting's webhook URL
   (Plesk: Websites & Domains → Git → Repository settings). Without a secret the deploy job only logs a notice.
2. Remove the hosting's push webhook from the GitHub repository — otherwise it deploys before CI.
3. Hosting runs `bash deploy/post-deploy.sh` after the pull (Plesk: "Additional deployment actions").
4. Server-only values in `.env.local`: `APP_ENV`, secrets, optional `DEPLOY_HEALTH_URL` (must answer 2xx).

Project-specific deploy steps (seeds, imports) go into `deploy/post-deploy.local.sh`; it runs after the migrations.

Optional settings in `deploy/deploy.env` (all off by default):

| Setting | Effect |
|---|---|
| `WORKER_STOP_CMD` / `WORKER_START_CMD` | Stop the workers (e.g. `sudo -n /usr/bin/supervisorctl stop 'app:*'`) before the migrations, start them again at the end — also when the deploy fails. Without it the script sends `messenger:stop-workers`. |
| `FPM_RELOAD_CMD` | Reload PHP-FPM after the deploy so the OPcache drops old code (e.g. `sudo -n /usr/bin/systemctl reload plesk-php85-fpm`). |
| `DEPLOY_LOG` / `DEPLOY_LOG_KEEP_LINES` | The hosting action appends the output to `var/log/deploy.log`; the script keeps the last 5000 lines. |

The sudo commands need a sudoers rule for the hosting user that allows exactly these commands.

### Deployments on GitHub

With `deployments: write` in the project's `ci.yml` (the template sets it), the deploy job records a GitHub deployment
per environment (`beta`, `live`) with the commit and the webhook result. The repository page then shows what runs where;
the senior hub reads the same data. Without the permission the deploy still runs and the job logs a warning.

Branches: `master` = live, `develop` = beta (inputs `live-branch`/`beta-branch` to change).

## Workflow inputs

| Input | Default | |
|---|---|---|
| `runs-on` | `'"ubuntu-latest"'` | runner as JSON, e.g. `'["self-hosted","senior-ci"]'` |
| `timeout-minutes` | `20` | |
| `php-version` | — (required) | same as production |
| `php-extensions` | `intl, pdo_mysql, zip` | |
| `mysql-version` | `''` | e.g. `8.4` starts a MySQL service and sets `DATABASE_URL` |
| `beta-branch` / `live-branch` | `develop` / `master` | |

## Self-hosted runner

Private repositories pay for GitHub-hosted minutes. The template therefore targets a self-hosted runner with the labels
`self-hosted, senior-ci` and lets the repository variable `CI_RUNS_ON` switch back (`"ubuntu-latest"`, as JSON string).
The workflow adapts to the runner:

- `setup-php` gets `runner: self-hosted`, so it uses the PHP versions installed on the runner.
- No Docker is assumed: instead of the MySQL service, the runner provides `CI_DATABASE_HOST`, `CI_DATABASE_USER`,
  `CI_DATABASE_PASSWORD` (and optionally `CI_DATABASE_VERSION`); each run gets its own database
  `ci_<repo>_<run id>_<attempt>`. The runner is responsible for dropping leftovers.

Never use a self-hosted runner for a public repository: anyone could run code on it through a pull request.

## Versioning

Semver. The workflow is referenced as `@v1` (moving major tag); configs follow the Composer version.
A rule change that can turn a green project red is a major version. See [CHANGELOG.md](CHANGELOG.md).
