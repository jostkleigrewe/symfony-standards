#!/usr/bin/env bash
# DE: Tests für den Umgebungs-Check in templates/deploy/post-deploy.sh — Fake-Projekt mit echtem symfony/dotenv,
#     Fake-Composer und Fake-Konsole. Erreicht der Lauf Composer, hat der Check bestanden; ein Abbruch muss davor kommen.
# EN: Tests for the environment check in templates/deploy/post-deploy.sh: fake project with the real symfony/dotenv,
#     a fake composer and a fake console. Reaching composer means the check passed; a stop must come before it.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
# DE: Testwerte bewusst entropiearm. EN: Test values deliberately low-entropy.
DOTENV="$WORK/dotenv"
mkdir -p "$DOTENV"
if ! (cd "$DOTENV" && echo '{}' > composer.json && composer require symfony/dotenv --no-interaction --no-progress --quiet); then
    echo "FAIL could not install symfony/dotenv (network?)"; exit 1
fi

APP="$WORK/app"
FAKE="$WORK/fake"
mkdir -p "$FAKE"
# DE: Fake-Composer: meldet sich und bricht ab (42) — außer beim ersten Deploy, dort legt er vendor/ an.
# EN: Fake composer: reports and stops (42), except on the first deploy where it creates vendor/.
cat > "$FAKE/composer" <<SH
#!/usr/bin/env bash
echo "COMPOSER-REACHED"
if [[ -n "\${FAKE_FIRST_DEPLOY:-}" ]]; then cp -r "$DOTENV/vendor" vendor; exit 0; fi
exit 42
SH
chmod +x "$FAKE/composer"
fails=0

# DE: run_case <name> <erwartet: ok|stop|warn> <.env> <.env.local> [deploy.env-Zeile] — weitere Dateien per EXTRA_FILE.
# EN: run_case <name> <expected: ok|stop|warn> <.env> <.env.local> [deploy.env line] — more files via EXTRA_FILE.
run_case() {
    local name=$1 expect=$2 dotenv=$3 local_env=$4 deploy_line=${5:-} out rc ok=1
    rm -rf "$APP" && mkdir -p "$APP/deploy" "$APP/bin"
    cp "$ROOT/templates/deploy/post-deploy.sh" "$APP/deploy/"
    printf 'COMPOSER_BIN="%s"\n%s\n' "$FAKE/composer" "$deploy_line" > "$APP/deploy/deploy.env"
    # DE: Fake-Konsole: jeder Aufruf scheitert, damit der Lauf nach dem Check endet. EN: Every call fails so the run ends after the check.
    printf '<?php\necho "CONSOLE-REACHED\\n";\nexit(42);\n' > "$APP/bin/console"
    printf '%s\n' "$dotenv" > "$APP/.env"
    printf '%s\nAPP_SECRET=x\n' "$local_env" > "$APP/.env.local"
    [[ -n ${EXTRA_FILE:-} ]] && printf '%s\n' "$EXTRA_CONTENT" > "$APP/$EXTRA_FILE"
    [[ -z ${FAKE_FIRST_DEPLOY:-} ]] && cp -r "$DOTENV/vendor" "$APP/vendor"
    out=$(cd "$WORK" && env -u APP_ENV -u APP_DEBUG ${CASE_ENV:+"$CASE_ENV"} bash "$APP/deploy/post-deploy.sh" 2>&1)
    rc=$?
    case $expect in
        ok) [[ $out == *"COMPOSER-REACHED"* && $out != *"ERROR: the server would run"* && $out != *WARNING* ]] || ok=0 ;;
        warn) [[ $out == *"COMPOSER-REACHED"* && $out == *"allowed by ALLOW_NON_PROD_ENV=1"* ]] || ok=0 ;;
        stop) [[ $rc -ne 0 && $out == *"ERROR: the server would run"* ]] || ok=0
              # DE: Ohne vendor/ erst nach Composer, sonst davor. EN: Without vendor/ only after composer, otherwise before.
              if [[ -z ${FAKE_FIRST_DEPLOY:-} && $out == *"COMPOSER-REACHED"* ]]; then ok=0; fi
              [[ $out == *"CONSOLE-REACHED"* ]] && ok=0 ;;
    esac
    [[ $out == *"APP_SECRET=x"* ]] && ok=0
    if [[ $ok -eq 1 ]]; then echo "ok   $name"; else echo "FAIL $name (rc=$rc)"; printf '     %s\n' "${out//$'\n'/$'\n'     }"; fails=$((fails + 1)); fi
}

run_case "prod, debug 0"                 ok   'APP_ENV=dev' 'APP_ENV=prod'
run_case "prod, APP_DEBUG=0 explicit"    ok   'APP_ENV=dev' $'APP_ENV=prod\nAPP_DEBUG=0'
run_case "dev in .env.local"             stop 'APP_ENV=dev' 'APP_ENV=dev'
run_case "no APP_ENV in .env.local"      stop 'APP_ENV=dev' ''
run_case "prod + APP_DEBUG=1"            stop 'APP_ENV=dev' $'APP_ENV=prod\nAPP_DEBUG=1'
run_case "prod + APP_DEBUG=true"         stop 'APP_ENV=dev' $'APP_ENV=prod\nAPP_DEBUG=true'
run_case "exception variable"            warn 'APP_ENV=dev' 'APP_ENV=dev' 'ALLOW_NON_PROD_ENV=1'
CASE_ENV=APP_ENV=dev run_case "process env wins"  stop 'APP_ENV=prod' 'APP_ENV=prod'
EXTRA_FILE=.env.local.php EXTRA_CONTENT="<?php return ['APP_ENV' => 'prod', 'APP_DEBUG' => '0'];" \
    run_case "dump-env .env.local.php wins"  ok 'APP_ENV=dev' 'APP_ENV=dev'
EXTRA_FILE=.env.prod.local EXTRA_CONTENT='APP_DEBUG=1' \
    run_case ".env.prod.local turns debug on" stop 'APP_ENV=dev' 'APP_ENV=prod'
FAKE_FIRST_DEPLOY=1 run_case "first deploy, prod"  ok   'APP_ENV=dev' 'APP_ENV=prod'
FAKE_FIRST_DEPLOY=1 run_case "first deploy, dev"   stop 'APP_ENV=dev' 'APP_ENV=dev'

echo
if [[ $fails -gt 0 ]]; then echo "❌ $fails case(s) failed"; exit 1; fi
echo "✅ all cases passed"
