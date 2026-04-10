#!/usr/bin/env bash
# tests/test-gates-pending-hook.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$SCRIPT_DIR/hooks/check-gates-pending.sh"
PASS=0; FAIL=0
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

mkdir -p "$TMPDIR/wiki"

assert_allow() {
    local desc="$1" input="$2"
    RESULT=$(echo "$input" | WIKI_DIR="$TMPDIR/wiki" bash "$HOOK" 2>/dev/null)
    if echo "$RESULT" | grep -q '"allow"'; then
        echo "  ✅ $desc"; PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $desc — got: $RESULT"; FAIL=$((FAIL + 1))
    fi
}

assert_block() {
    local desc="$1" input="$2"
    RESULT=$(echo "$input" | WIKI_DIR="$TMPDIR/wiki" bash "$HOOK" 2>/dev/null)
    if echo "$RESULT" | grep -q '"block"'; then
        echo "  ✅ $desc (blocked)"; PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $desc — expected block, got: $RESULT"; FAIL=$((FAIL + 1))
    fi
}

echo "=== check-gates-pending.sh Tests ==="

# Kein _pending.json → alles erlaubt
rm -f "$TMPDIR/wiki/_pending.json"
assert_allow "Kein pending — normaler Agent erlaubt" \
    '{"subagent_type": "general-purpose", "prompt": "Ingest test"}'
assert_allow "Kein pending — Gate-Agent erlaubt" \
    '{"subagent_type": "bibliothek:quellen-pruefer", "prompt": "Check"}'

# _pending.json mit stufe: gates
echo '{"typ":"ingest","stufe":"gates","quelle":"fingerloos-ec2-2016"}' > "$TMPDIR/wiki/_pending.json"
assert_block "Gates pending — normaler Agent blockiert" \
    '{"subagent_type": "general-purpose", "prompt": "Ingest test"}'
assert_allow "Gates pending — quellen-pruefer erlaubt" \
    '{"subagent_type": "bibliothek:quellen-pruefer", "prompt": "Check"}'
assert_allow "Gates pending — vollstaendigkeits-pruefer erlaubt" \
    '{"subagent_type": "bibliothek:vollstaendigkeits-pruefer", "prompt": "Check"}'
assert_allow "Gates pending — konsistenz-pruefer erlaubt" \
    '{"subagent_type": "bibliothek:konsistenz-pruefer", "prompt": "Check"}'
assert_allow "Gates pending — vokabular-pruefer erlaubt" \
    '{"subagent_type": "bibliothek:vokabular-pruefer", "prompt": "Check"}'
assert_allow "Gates pending — struktur-reviewer erlaubt" \
    '{"subagent_type": "bibliothek:struktur-reviewer", "prompt": "Check"}'
assert_allow "Gates pending — duplikat-validator erlaubt" \
    '{"subagent_type": "bibliothek:duplikat-validator", "prompt": "Check"}'

# _pending.json mit stufe: sideeffects
echo '{"typ":"ingest","stufe":"sideeffects","quelle":"fingerloos-ec2-2016"}' > "$TMPDIR/wiki/_pending.json"
assert_block "Sideeffects pending — normaler Agent blockiert" \
    '{"subagent_type": "general-purpose", "prompt": "Ingest test"}'
assert_allow "Sideeffects pending — pruefer erlaubt" \
    '{"subagent_type": "bibliothek:quellen-pruefer", "prompt": "Check"}'

# Kein subagent_type angegeben
echo '{"typ":"ingest","stufe":"gates","quelle":"fingerloos-ec2-2016"}' > "$TMPDIR/wiki/_pending.json"
assert_block "Gates pending — Agent ohne subagent_type blockiert" \
    '{"prompt": "Ingest test"}'

echo ""
echo "=== Ergebnis: $PASS PASS, $FAIL FAIL ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
