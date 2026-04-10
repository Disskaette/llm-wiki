#!/usr/bin/env bash
# Tests fuer advance-pipeline-lock.sh (Hook C)
set -uo pipefail

HOOK="$(dirname "$0")/../plugin/hooks/advance-pipeline-lock.sh"
PASS=0; FAIL=0

assert() {
  if [ "$2" = "$3" ]; then
    echo "  PASS: $1"; PASS=$((PASS+1))
  else
    echo "  FAIL: $1 — expected=$2 actual=$3"; FAIL=$((FAIL+1))
  fi
}

SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/wiki"
PENDING="$SANDBOX/wiki/_pending.json"

run_hook() {
  echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK" >/dev/null 2>&1
  return $?
}

# --- Case 1: Kein Pending → exit 0 silent ---
JSON='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop"}'
run_hook "$JSON"
assert "no pending → exit 0" "0" "$?"

# --- Case 2: Pending mit Counter 0 → Counter wird 1 ---
echo '{"typ":"ingest","stufe":"gates","quelle":"q1","gates_passed":0,"gates_total":4}' > "$PENDING"
run_hook "$JSON"
assert "first gate → exit 0" "0" "$?"
COUNT=$(jq -r '.gates_passed' "$PENDING")
assert "counter incremented to 1" "1" "$COUNT"
STUFE=$(jq -r '.stufe' "$PENDING")
assert "stufe stays gates" "gates" "$STUFE"

# --- Case 3: Drei weitere Gates → Counter 4, Stufe wechselt ---
for i in 1 2 3; do run_hook "$JSON" >/dev/null; done
COUNT=$(jq -r '.gates_passed' "$PENDING")
assert "counter after 4 gates" "4" "$COUNT"
STUFE=$(jq -r '.stufe' "$PENDING")
assert "stufe wechselt zu sideeffects" "sideeffects" "$STUFE"

# --- Case 4: Erneute SubagentStop auf stufe=sideeffects → keine Aenderung ---
run_hook "$JSON"
COUNT2=$(jq -r '.gates_passed' "$PENDING")
assert "counter bleibt 4 nach sideeffects" "4" "$COUNT2"
STUFE2=$(jq -r '.stufe' "$PENDING")
assert "stufe bleibt sideeffects" "sideeffects" "$STUFE2"

# --- Case 5: Alte Pending ohne gates_passed → defensive Default 0 → 1 ---
echo '{"typ":"ingest","stufe":"gates","quelle":"q2"}' > "$PENDING"
run_hook "$JSON"
COUNT3=$(jq -r '.gates_passed' "$PENDING")
assert "legacy pending migriert zu counter 1" "1" "$COUNT3"

# --- Case 6: Kaputtes Pending → exit 0 ohne Crash ---
echo 'garbage' > "$PENDING"
run_hook "$JSON"
assert "broken pending → exit 0" "0" "$?"

rm -rf "$SANDBOX"
echo ""
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
