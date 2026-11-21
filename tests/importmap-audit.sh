#!/usr/bin/env bash
# DE: Tests für den Schritt importmap-audit — Fake-Konsole; FAKE_AUDIT steuert den Ausgang (ok, vuln, ratelimit, other).
# EN: Tests for the importmap-audit step: fake console; FAKE_AUDIT selects the outcome (ok, vuln, ratelimit, other).
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
    echo "about\nimportmap:audit\n";
    exit(0);
}
if (($args[0] ?? '') === 'importmap:audit') {
    switch (getenv('FAKE_AUDIT') ?: 'ok') {
        case 'vuln':
            echo "1 vulnerability found\n";
            exit(1);
        case 'ratelimit':
            fwrite(STDERR, "In ImportMapAuditor.php line 68:\n  Error 403 auditing packages. Response: {\"message\":\"API rate limit exceeded for 1.2.3.4.\"}\n");
            exit(1);
        case 'other':
            fwrite(STDERR, "  Error 500 auditing packages. Response: {}\n");
            exit(1);
        default:
            echo "No vulnerabilities found.\n";
            exit(0);
    }
}
exit(1);
PHP
echo '<?php return [];' > "$WORK/importmap.php"
fails=0

# DE: run_case <name> <erwartet: ok|fail|warn> [Umgebung…]   EN: run_case <name> <expected: ok|fail|warn> [env…]
run_case() {
    local name=$1 expect=$2 out rc ok=1
    shift 2
    out=$(cd "$WORK" && env GITHUB_ACTIONS='' SYMFONY_STANDARDS_STRICT='' "$@" "$BIN" check importmap-audit 2>&1)
    rc=$?
    case $expect in
        ok) [[ $rc -eq 0 && $out == *"all checks passed"* && $out != *"warning"* ]] || ok=0 ;;
        fail) [[ $rc -ne 0 && $out == *"failed: importmap-audit"* ]] || ok=0 ;;
        warn) [[ $rc -eq 0 && $out == *"rate limit"* && $out == *"warnings: importmap-audit"* ]] || ok=0 ;;
    esac
    if [[ $ok -eq 1 ]]; then echo "ok   $name"; else echo "FAIL $name (rc=$rc)"; printf '     %s\n' "${out//$'\n'/$'\n'     }"; fails=$((fails + 1)); fi
}

run_case "no findings"                ok
run_case "vulnerability fails"        fail FAKE_AUDIT=vuln
run_case "rate limit warns"           warn FAKE_AUDIT=ratelimit
run_case "rate limit fails in strict" fail FAKE_AUDIT=ratelimit SYMFONY_STANDARDS_STRICT=1
run_case "other API error fails"      fail FAKE_AUDIT=other

echo
if [[ $fails -gt 0 ]]; then echo "❌ $fails case(s) failed"; exit 1; fi
echo "✅ all cases passed"
