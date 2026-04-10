#!/usr/bin/env bash
# tests/test-wiki-write-hook.sh — Testfälle für check-wiki-write.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$SCRIPT_DIR/hooks/check-wiki-write.sh"
PASS=0; FAIL=0

assert_allow() {
    local desc="$1" input="$2"
    RESULT=$(echo "$input" | bash "$HOOK" 2>/dev/null)
    if echo "$RESULT" | grep -q '"allow"'; then
        echo "  ✅ $desc"; PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $desc — got: $RESULT"; FAIL=$((FAIL + 1))
    fi
}

assert_block() {
    local desc="$1" input="$2"
    RESULT=$(echo "$input" | bash "$HOOK" 2>/dev/null)
    if echo "$RESULT" | grep -q '"block"'; then
        echo "  ✅ $desc (blocked)"; PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $desc — expected block, got: $RESULT"; FAIL=$((FAIL + 1))
    fi
}

echo "=== check-wiki-write.sh Tests ==="

# Lesende Bash-Befehle mit wiki/ — müssen ALLOW sein
assert_allow "wc -l ohne Umleitung" \
    '{"tool": "Bash", "tool_input": {"command": "wc -l wiki/quellen/*.md"}}'

assert_allow "wc -l mit 2>/dev/null" \
    '{"tool": "Bash", "tool_input": {"command": "wc -l wiki/quellen/*.md 2>/dev/null"}}'

assert_allow "grep mit 2>/dev/null" \
    '{"tool": "Bash", "tool_input": {"command": "grep \"pattern\" wiki/quellen/*.md 2>/dev/null"}}'

assert_allow "cat (lesen)" \
    '{"tool": "Bash", "tool_input": {"command": "cat wiki/quellen/test.md"}}'

assert_allow "head Befehl" \
    '{"tool": "Bash", "tool_input": {"command": "head -20 wiki/quellen/test.md 2>/dev/null"}}'

# Schreibende Bash-Befehle mit wiki/ — müssen BLOCK sein
assert_block "echo redirect" \
    '{"tool": "Bash", "tool_input": {"command": "echo test > wiki/quellen/test.md"}}'

assert_block "sed -i" \
    '{"tool": "Bash", "tool_input": {"command": "sed -i s/foo/bar/ wiki/quellen/test.md"}}'

assert_block "tee" \
    '{"tool": "Bash", "tool_input": {"command": "echo test | tee wiki/quellen/test.md"}}'

assert_block "rm" \
    '{"tool": "Bash", "tool_input": {"command": "rm wiki/quellen/test.md"}}'

assert_block "mv" \
    '{"tool": "Bash", "tool_input": {"command": "mv wiki/quellen/a.md wiki/quellen/b.md"}}'

# Nicht-Wiki-Pfade — müssen ALLOW sein
assert_allow "Bash ohne wiki-Pfad" \
    '{"tool": "Bash", "tool_input": {"command": "ls -la /tmp/"}}'

echo ""
echo "=== Ergebnis: $PASS PASS, $FAIL FAIL ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
