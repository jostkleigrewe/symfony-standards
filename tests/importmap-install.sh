#!/usr/bin/env bash
# DE: Tests für den Schritt importmap-install — Fake-Projekt mit einer bin/console, die nur `list --raw` und
#     `importmap:install` kennt; FAKE_INSTALL_RC steuert den Ausgang des Downloads.
# EN: Tests for the importmap-install step: a fake project whose bin/console only knows `list --raw` and
#     `importmap:install`; FAKE_INSTALL_RC controls the download result.
set -uo pipefail

BIN="$(cd "$(dirname "$0")/.." && pwd)/bin/symfony-standards"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
mkdir -p "$WORK/bin" && echo '{}' > "$WORK/composer.json"
cat > "$WORK/bin/console" <<'PHP'
<?php
// DE: Minimal-Konsole für den Test. EN: Minimal console for the test.
$args = array_slice($argv, 1);
if ($args === ['list', '--raw']) {
    echo getenv('FAKE_COMMANDS') ?: "about\nimportmap:install\n";
    exit(0);
}
if (($args[0] ?? '') === 'importmap:install') {
    echo "fake importmap:install\n";
    exit((int) (getenv('FAKE_INSTALL_RC') ?: 0));
}
exit(1);
PHP
fails=0

# DE: run_case <name> <erwartet: ok|fail|skip> <importmap.php: yes|no> [Umgebung…]
# EN: run_case <name> <expected: ok|fail|skip> <importmap.php: yes|no> [env…]
run_case() {
    local name=$1 expect=$2 importmap=$3 out rc ok=1
    shift 3
    rm -f "$WORK/importmap.php"
    [[ $importmap == yes ]] && echo '<?php return [];' > "$WORK/importmap.php"
    out=$(cd "$WORK" && env GITHUB_ACTIONS='' SYMFONY_STANDARDS_STRICT='' "$@" "$BIN" check importmap-install 2>&1)
    rc=$?
    case $expect in
        ok) [[ $rc -eq 0 && $out == *"fake importmap:install"* && $out == *"all checks passed"* ]] || ok=0 ;;
        fail) [[ $rc -ne 0 && $out == *"jsDelivr"* && $out == *"assets/vendor/"* && $out == *"failed: importmap-install"* ]] || ok=0 ;;
        skip) [[ $rc -eq 0 && $out == *"skipped"*"importmap-install"* && $out != *"fake importmap:install"* ]] || ok=0 ;;
    esac
    if [[ $ok -eq 1 ]]; then echo "ok   $name"; else echo "FAIL $name (rc=$rc)"; printf '     %s\n' "${out//$'\n'/$'\n'     }"; fails=$((fails + 1)); fi
}

run_case "no importmap.php"      skip no
run_case "installs"              ok   yes
run_case "download fails"        fail yes FAKE_INSTALL_RC=1
run_case "command missing"       skip yes FAKE_COMMANDS=$'about\n'

# DE: Der Schritt läuft vor cs-fixer, cache-warmup und phpunit. EN: The step runs before cs-fixer, cache-warmup and phpunit.
order=$("$BIN" steps | tr '\n' ' ')
if [[ $order =~ importmap-install.*cs-fixer.*cache-warmup.*phpunit ]]; then echo "ok   step order"; else echo "FAIL step order: $order"; fails=$((fails + 1)); fi

echo
if [[ $fails -gt 0 ]]; then echo "❌ $fails case(s) failed"; exit 1; fi
echo "✅ all cases passed"
