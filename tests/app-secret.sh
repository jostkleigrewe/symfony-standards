#!/usr/bin/env bash
# DE: Tests für den Schritt app-secret — je Fall eine .env in einem leeren Fake-Projekt, dann `check app-secret`.
# EN: Tests for the app-secret step: one .env per case in an empty fake project, then `check app-secret`.
set -uo pipefail

BIN="$(cd "$(dirname "$0")/.." && pwd)/bin/symfony-standards"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
# DE: Testwerte bewusst entropiearm. EN: Test values deliberately low-entropy.
mkdir -p "$WORK/bin" && echo '{}' > "$WORK/composer.json" && : > "$WORK/bin/console"
fails=0

# DE: run_case <name> <erwartet: warn|none|skip> <.env-Inhalt|-> [check-Argumente…]
# EN: run_case <name> <expected: warn|none|skip> <.env content|-> [check args…]
run_case() {
    local name=$1 expect=$2 content=$3 out rc
    shift 3
    rm -f "$WORK/.env"
    [[ $content != - ]] && printf '%s\n' "$content" > "$WORK/.env"
    out=$(cd "$WORK" && GITHUB_ACTIONS='' SYMFONY_STANDARDS_STRICT='' "$BIN" check "$@" app-secret 2>&1)
    rc=$?
    local ok=1
    case $expect in
        warn) [[ $rc -eq 0 && $out == *"APP_SECRET has a value"* && $out == *"1 warning"* ]] || ok=0 ;;
        none) [[ $rc -eq 0 && $out != *"APP_SECRET has a value"* && $out == *"all checks passed"* && $out != *warning* ]] || ok=0 ;;
        skip) [[ $rc -eq 0 && $out == *"skipped"*"app-secret"* ]] || ok=0 ;;
        strict) [[ $rc -ne 0 && $out == *"failed: app-secret"* ]] || ok=0 ;;
    esac
    # DE: Der Wert darf nie in der Ausgabe stehen. EN: The value must never appear in the output.
    [[ $out == *abc* ]] && ok=0
    if [[ $ok -eq 1 ]]; then echo "ok   $name"; else echo "FAIL $name (rc=$rc)"; printf '     %s\n' "${out//$'\n'/$'\n'     }"; fails=$((fails + 1)); fi
}

run_case "no .env"              skip   -
run_case "empty"                none   'APP_SECRET='
run_case 'empty ""'             none   'APP_SECRET=""'
run_case "empty ''"             none   "APP_SECRET=''"
run_case "empty + comment"      none   'APP_SECRET= # comment'
run_case "no APP_SECRET line"   none   'APP_ENV=dev'
run_case "abc"                  warn   'APP_SECRET=abc'
run_case '"a b"'                warn   'APP_SECRET="a b"'
run_case "export"               warn   'export APP_SECRET=abc'
run_case "abc # c"              warn   'APP_SECRET=abc # c'
run_case "strict option"        strict 'APP_SECRET=abc' --strict
run_case "strict empty"         none   'APP_SECRET=' --strict

# DE: Strenger Modus per Umgebungsvariable. EN: Strict mode via environment variable.
printf 'APP_SECRET=abc\n' > "$WORK/.env"
if (cd "$WORK" && GITHUB_ACTIONS='' SYMFONY_STANDARDS_STRICT=1 "$BIN" check app-secret >/dev/null 2>&1); then
    echo "FAIL strict env"; fails=$((fails + 1))
else
    echo "ok   strict env"
fi

# DE: .env.local/.env.dev/.env.test werden nicht geprüft. EN: .env.local/.env.dev/.env.test are not checked.
printf 'APP_SECRET=\n' > "$WORK/.env"
for f in .env.local .env.dev .env.test; do printf 'APP_SECRET=abc\n' > "$WORK/$f"; done
run_case "other env files ignored" none 'APP_SECRET='

echo
if [[ $fails -gt 0 ]]; then echo "❌ $fails case(s) failed"; exit 1; fi
echo "✅ all cases passed"
