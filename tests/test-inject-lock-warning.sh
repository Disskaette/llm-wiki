#!/usr/bin/env bash
# Tests fuer inject-lock-warning.sh (Hook D)
set -uo pipefail

HOOK="$(dirname "$0")/../plugin/hooks/inject-lock-warning.sh"
PASS=0; FAIL=0

assert() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $name"; PASS=$((PASS+1))
  else
    echo "  FAIL: $name — expected='$expected' actual='$actual'"; FAIL=$((FAIL+1))
  fi
}

# --- Sandbox mit Wiki-Verzeichnis ---
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/wiki"

run_in_sandbox() {
  # Hook erwartet CLAUDE_PROJECT_DIR als cwd-Basis
  CLAUDE_PROJECT_DIR="$SANDBOX" echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK" 2>&1
  return $?
}

# --- Case 1: Kein _pending.json → silent, exit 0, keine Ausgabe ---
JSON='{"prompt":"hello","hook_event_name":"UserPromptSubmit"}'
OUT=$(run_in_sandbox "$JSON")
RC=$?
assert "no pending → exit 0" "0" "$RC"
assert "no pending → no output" "" "$OUT"

# --- Case 2: _pending.json mit stufe=gates → JSON mit additionalContext ---
echo '{"typ":"ingest","stufe":"gates","quelle":"fingerloos-ec2-2016","timestamp":"2026-04-10T12:00:00Z"}' > "$SANDBOX/wiki/_pending.json"
OUT=$(run_in_sandbox "$JSON")
RC=$?
assert "pending exists → exit 0" "0" "$RC"

# Output muss valides JSON sein
if echo "$OUT" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
  echo "  PASS: output is valid JSON with additionalContext"
  PASS=$((PASS+1))
else
  echo "  FAIL: output is not valid JSON: $OUT"
  FAIL=$((FAIL+1))
fi

# additionalContext muss Quellen-Name enthalten
CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null || echo "")
case "$CTX" in
  *fingerloos-ec2-2016*) echo "  PASS: context mentions source name"; PASS=$((PASS+1));;
  *) echo "  FAIL: context missing source — got: $CTX"; FAIL=$((FAIL+1));;
esac

# hookEventName muss gesetzt sein
EVT=$(echo "$OUT" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null || echo "")
assert "hookEventName=UserPromptSubmit" "UserPromptSubmit" "$EVT"

# --- Case 3: Kaputtes _pending.json → silent fail, keine Exception ---
echo 'not json at all' > "$SANDBOX/wiki/_pending.json"
OUT=$(run_in_sandbox "$JSON")
RC=$?
assert "broken pending → still exit 0" "0" "$RC"

rm -rf "$SANDBOX"
echo ""
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
