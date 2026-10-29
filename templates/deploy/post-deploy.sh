#!/usr/bin/env bash
# =============================================================================
# Post-deploy script — standard: jostkleigrewe/symfony-standards
# =============================================================================
# Runs after the hosting pulled the new code (Plesk: Git → "Additional deployment actions": bash deploy/post-deploy.sh).
# Keep this file identical to the template; project-specific settings go into:
#   deploy/deploy.env         versioned settings, no secrets (PHP binary, PATH, required vars)
#   deploy/post-deploy.local.sh   project-specific steps (seeds, imports) — runs after migrations
# Secrets and per-server values stay in .env.local, e.g. DEPLOY_HEALTH_URL (must answer 2xx after the deploy).
# =============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# --- Settings (defaults, overridable in deploy/deploy.env) -------------------
PHP_BIN="php"
COMPOSER_BIN="composer"
PHP_MEMORY_LIMIT="512M"
REQUIRED_VARS=(APP_SECRET)
DEPLOY_LOG="var/log/deploy.log"   # where the hosting action appends this script's output (see README)
DEPLOY_LOG_KEEP_LINES=5000
WORKER_STOP_CMD=""                # e.g. supervisorctl stop — runs before the migrations
WORKER_START_CMD=""               # e.g. supervisorctl restart — runs at the end, also when the deploy fails
FPM_RELOAD_CMD=""                 # e.g. systemctl reload <php-fpm> — clears the OPcache after new vendor code
# shellcheck source=/dev/null
[[ -f deploy/deploy.env ]] && source deploy/deploy.env

# Console calls get a higher memory limit (cache warmup, migrations). Composer is called directly — on Plesk/phpenv
# it is a shell shim, `php composer` would only print the shim.
console() { "$PHP_BIN" -d "memory_limit=$PHP_MEMORY_LIMIT" bin/console --no-interaction "$@"; }
console_has() { console list --raw 2>/dev/null | awk '{print $1}' | grep -x "$1" >/dev/null; }
step() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$1"; }

# Trim the deploy log in place: the hosting action keeps it open in append mode, so the file must stay the same inode.
if [[ -f "$DEPLOY_LOG" ]] && (( $(wc -l < "$DEPLOY_LOG") > DEPLOY_LOG_KEEP_LINES )); then
    tail -n "$DEPLOY_LOG_KEEP_LINES" "$DEPLOY_LOG" > "$DEPLOY_LOG.tmp"
    cat "$DEPLOY_LOG.tmp" > "$DEPLOY_LOG"
    rm -f "$DEPLOY_LOG.tmp"
fi

# --- 1. Pre-flight -----------------------------------------------------------
step "1/6 Pre-flight"
if [[ ! -f .env.local ]]; then
    echo "ERROR: .env.local missing — create it on the server (APP_ENV, APP_SECRET, DATABASE_URL, ...)." >&2
    exit 1
fi
APP_ENV="$(grep -E '^APP_ENV=' .env.local | tail -1 | cut -d= -f2- | tr -d "\"'" || true)"
APP_ENV="${APP_ENV:-prod}"
HEALTH_URL="$(grep -E '^DEPLOY_HEALTH_URL=' .env.local | tail -1 | cut -d= -f2- | tr -d "\"'" || true)"
missing=()
for var in "${REQUIRED_VARS[@]}"; do
    grep -qE "^${var}=" .env.local || missing+=("$var")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: .env.local lacks: ${missing[*]}" >&2
    exit 1
fi
echo "Project: $PROJECT_DIR · APP_ENV=$APP_ENV · $("$PHP_BIN" -r 'echo PHP_VERSION;')"

# --- 2. Dependencies ---------------------------------------------------------
step "2/6 Composer install"
# --no-scripts: cache and assets are handled below with the higher memory limit.
if [[ "$APP_ENV" == "prod" ]]; then
    "$COMPOSER_BIN" install --no-dev --optimize-autoloader --classmap-authoritative --no-interaction --no-progress --no-scripts
else
    "$COMPOSER_BIN" install --no-interaction --no-progress --no-scripts
fi

# --- 3. Assets ---------------------------------------------------------------
step "3/6 Assets"
if [[ -f importmap.php ]]; then
    # assets/vendor/ is not versioned — always install, also outside prod.
    console importmap:install
    if [[ "$APP_ENV" == "prod" ]]; then
        console asset-map:compile
    fi
fi
if console_has assets:install; then
    console assets:install public
fi

# --- 4. Cache ----------------------------------------------------------------
step "4/6 Cache"
# Remove the environment's cache first: cache:clear boots the OLD compiled container, which fails when it references
# a class deleted by this release (arma-ai, 2026-10-26: 30 min HTTP 500). The guard keeps rm away from var/cache/.
if [[ -z "$APP_ENV" || "$APP_ENV" == *[/.]* ]]; then
    echo "ERROR: invalid APP_ENV '$APP_ENV'" >&2
    exit 1
fi
rm -rf "var/cache/${APP_ENV}"
console cache:clear --no-warmup
console cache:warmup

# --- 5. Database + workers ---------------------------------------------------
step "5/6 Migrations + workers"
if [[ -n "$WORKER_STOP_CMD" ]]; then
    # Old workers would write with the old mapping against the new schema (arma-ai, 2026-10-24). Stop them first and
    # start them again on every exit, so a failed migration never leaves the queue without workers.
    if [[ -n "$WORKER_START_CMD" ]]; then
        trap 'echo "Starting workers: $WORKER_START_CMD"; eval "$WORKER_START_CMD" || echo "WARNING: worker start failed" >&2' EXIT
    fi
    echo "Stopping workers: $WORKER_STOP_CMD"
    eval "$WORKER_STOP_CMD"
fi
if console_has doctrine:migrations:migrate; then
    # Idempotent: exit 0 when nothing is pending. Never parse migrations:status (its format changes between versions).
    console doctrine:migrations:migrate --allow-no-migration
fi
if [[ -f deploy/post-deploy.local.sh ]]; then
    echo "Project steps: deploy/post-deploy.local.sh"
    # shellcheck source=/dev/null
    source deploy/post-deploy.local.sh
fi
if [[ -z "$WORKER_STOP_CMD" ]] && console_has messenger:stop-workers; then
    # Workers finish their current message and exit; the process manager (supervisor) starts them with the new code.
    console messenger:stop-workers
fi
if [[ -n "$FPM_RELOAD_CMD" ]]; then
    # PHP-FPM keeps the old code in its OPcache until reloaded (arma-ai: old vendor code after a framework upgrade).
    echo "Reloading PHP-FPM: $FPM_RELOAD_CMD"
    eval "$FPM_RELOAD_CMD"
fi

# --- 6. Self-test ------------------------------------------------------------
step "6/6 Self-test"
console about >/dev/null
echo "Kernel boots."
if [[ -n "$HEALTH_URL" ]]; then
    curl --fail --silent --show-error --max-time 30 --output /dev/null "$HEALTH_URL"
    echo "Health check OK."
fi

printf '\nDeployment finished (%s, %s)\n' "$APP_ENV" "$(git rev-parse --short HEAD 2>/dev/null || echo 'no git')"
