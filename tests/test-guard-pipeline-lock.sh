#!/usr/bin/env bash
# Tests fuer guard-pipeline-lock.sh (Hook B)
set -uo pipefail

HOOK="$(dirname "$0")/../plugin/hooks/guard-pipeline-lock.sh"
PASS=0; FAIL=0

assert() {
  if [ "$2" = "$3" ]; then
    echo "  PASS: $1"; PASS=$((PASS+1))
  else
    echo "  FAIL: $1 — expected=$2 actual=$3"; FAIL=$((FAIL+1))
  fi
}

# Sandbox mit wiki/
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/wiki"

run_hook() {
  echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK" >/dev/null 2>&1
  return $?
}

# --- Case 1: Nicht-Ingest-Worker Agent → allow ---
JSON='{"tool_input":{"subagent_type":"general-purpose","description":"random task"},"hook_event_name":"PreToolUse","tool_name":"Agent"}'
run_hook "$JSON"
assert "non-ingest-worker allowed" "0" "$?"

# --- Case 2: Ingest-Worker + kein Pending → allow ---
JSON='{"tool_input":{"subagent_type":"bibliothek:ingest-worker","description":"Ingest: foo"},"hook_event_name":"PreToolUse","tool_name":"Agent"}'
run_hook "$JSON"
assert "ingest-worker without pending allowed" "0" "$?"

# --- Case 3: Ingest-Worker + Pending existiert → deny ---
echo '{"typ":"ingest","stufe":"gates","quelle":"test-q","gates_passed":0,"gates_total":4}' > "$SANDBOX/wiki/_pending.json"
run_hook "$JSON"
assert "ingest-worker with pending blocked" "2" "$?"

# --- Case 4: Pending auf Stufe sideeffects → trotzdem blocked ---
echo '{"typ":"ingest","stufe":"sideeffects","quelle":"test-q","gates_passed":4,"gates_total":4}' > "$SANDBOX/wiki/_pending.json"
run_hook "$JSON"
assert "ingest-worker with sideeffects pending blocked" "2" "$?"

# --- Case 5: Pending geloescht → wieder allow ---
rm "$SANDBOX/wiki/_pending.json"
run_hook "$JSON"
assert "ingest-worker after cleanup allowed" "0" "$?"

# --- Case 6: Kaputtes _pending.json → defensiv allow ---
echo 'garbage' > "$SANDBOX/wiki/_pending.json"
run_hook "$JSON"
assert "ingest-worker with broken pending allowed (defensive)" "0" "$?"

# --- Case 7: synthese-worker + kein Pending → allow ---
JSON_SW='{"tool_input":{"subagent_type":"bibliothek:synthese-worker","description":"Synthese: querkraft"},"hook_event_name":"PreToolUse","tool_name":"Agent"}'
run_hook "$JSON_SW"
assert "synthese-worker without pending allowed" "0" "$?"

# --- Case 8: synthese-worker + Pending existiert → deny ---
echo '{"typ":"synthese","stufe":"gates","quelle":"querkraft","gates_passed":0,"gates_total":3}' > "$SANDBOX/wiki/_pending.json"
run_hook "$JSON_SW"
assert "synthese-worker with pending blocked" "2" "$?"

# --- Case 9: synthese-worker + Ingest-Pending existiert → deny (cross-block) ---
echo '{"typ":"ingest","stufe":"gates","quelle":"test-buch","gates_passed":0,"gates_total":4}' > "$SANDBOX/wiki/_pending.json"
run_hook "$JSON_SW"
assert "synthese-worker with ingest-pending blocked (cross-block)" "2" "$?"

# --- Case 10: ingest-worker + Synthese-Pending existiert → deny (cross-block) ---
echo '{"typ":"synthese","stufe":"sideeffects","quelle":"querkraft","gates_passed":3,"gates_total":3}' > "$SANDBOX/wiki/_pending.json"
run_hook "$JSON"
assert "ingest-worker with synthese-pending blocked (cross-block)" "2" "$?"

rm -rf "$SANDBOX"
echo ""
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
