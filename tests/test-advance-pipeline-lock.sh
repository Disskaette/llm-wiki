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

# --- Case 7: Synthese-Pending mit gates_total=3 → nach 3 Gates sideeffects ---
echo '{"typ":"synthese","stufe":"gates","quelle":"querkraft","gates_passed":0,"gates_total":3}' > "$PENDING"
run_hook "$JSON"
run_hook "$JSON"
run_hook "$JSON"
STUFE3=$(jq -r '.stufe' "$PENDING")
COUNT3=$(jq -r '.gates_passed' "$PENDING")
assert "synthese gates_total=3 → sideeffects nach 3" "sideeffects" "$STUFE3"
assert "synthese counter = 3" "3" "$COUNT3"

# --- Case 8: INGEST-ID matcht → Counter wird inkrementiert ---
echo '{"typ":"ingest","stufe":"gates","quelle":"test-buch","gates_passed":0,"gates_total":4}' > "$PENDING"
JSON_ID='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"Pruefbericht: [INGEST-ID:test-buch] Ergebnis PASS"}'
run_hook "$JSON_ID"
COUNT_ID=$(jq -r '.gates_passed' "$PENDING")
assert "INGEST-ID matcht → counter 1" "1" "$COUNT_ID"

# --- Case 9: INGEST-ID matcht NICHT → Counter bleibt ---
echo '{"typ":"ingest","stufe":"gates","quelle":"test-buch","gates_passed":1,"gates_total":4}' > "$PENDING"
JSON_MISMATCH='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"Pruefbericht: [INGEST-ID:anderes-buch] Ergebnis PASS"}'
run_hook "$JSON_MISMATCH"
COUNT_MM=$(jq -r '.gates_passed' "$PENDING")
assert "INGEST-ID mismatch → counter bleibt 1" "1" "$COUNT_MM"

# --- Case 10: Kein INGEST-ID im Output → Counter steigt (Rueckwaertskompatibilitaet) ---
echo '{"typ":"ingest","stufe":"gates","quelle":"test-buch","gates_passed":1,"gates_total":4}' > "$PENDING"
run_hook "$JSON"
COUNT_NO_ID=$(jq -r '.gates_passed' "$PENDING")
assert "kein ID im Output → counter steigt (compat)" "2" "$COUNT_NO_ID"

# --- Case 11: Gate-FAIL → Counter wird NICHT inkrementiert ---
echo '{"typ":"ingest","stufe":"gates","quelle":"test-buch","gates_passed":0,"gates_total":4}' > "$PENDING"
JSON_FAIL='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"Pruefbericht: [INGEST-ID:test-buch] **Ergebnis:** FAIL\n\nAnhang A fehlt."}'
run_hook "$JSON_FAIL"
COUNT_FAIL=$(jq -r '.gates_passed' "$PENDING")
assert "Gate-FAIL → counter bleibt 0" "0" "$COUNT_FAIL"

# --- Case 12: Gate-PASS nach Korrektur → Counter steigt ---
JSON_REPASS='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"Pruefbericht: [INGEST-ID:test-buch] **Ergebnis:** PASS\n\nAlle Kapitel erfasst."}'
run_hook "$JSON_REPASS"
COUNT_REPASS=$(jq -r '.gates_passed' "$PENDING")
assert "Gate-PASS nach Korrektur → counter 1" "1" "$COUNT_REPASS"

# --- Case 13: Gate-PASS MIT HINWEISEN → Counter steigt (kein FAIL) ---
echo '{"typ":"ingest","stufe":"gates","quelle":"test-buch","gates_passed":1,"gates_total":4}' > "$PENDING"
JSON_HINTS='{"agent_type":"bibliothek:vokabular-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"[INGEST-ID:test-buch] **Ergebnis:** PASS MIT HINWEISEN\n\nKerve als Vokabular-Kandidat."}'
run_hook "$JSON_HINTS"
COUNT_HINTS=$(jq -r '.gates_passed' "$PENDING")
assert "PASS MIT HINWEISEN → counter steigt auf 2" "2" "$COUNT_HINTS"

# --- Case 14: Gate-FAIL ohne ID → Counter bleibt trotzdem (FAIL hat Vorrang) ---
echo '{"typ":"ingest","stufe":"gates","quelle":"test-buch","gates_passed":2,"gates_total":4}' > "$PENDING"
JSON_FAIL_NO_ID='{"agent_type":"bibliothek:quellen-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"**Ergebnis:** FAIL\n\n2 falsche Seitenangaben."}'
run_hook "$JSON_FAIL_NO_ID"
COUNT_FAIL2=$(jq -r '.gates_passed' "$PENDING")
assert "FAIL ohne ID → counter bleibt 2" "2" "$COUNT_FAIL2"

# --- Case 15: SYNTHESE-ID matcht → Counter steigt ---
echo '{"typ":"synthese","stufe":"gates","quelle":"querkraft","gates_passed":0,"gates_total":3}' > "$PENDING"
JSON_SID='{"agent_type":"bibliothek:quellen-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"[SYNTHESE-ID:querkraft] **Ergebnis:** PASS"}'
run_hook "$JSON_SID"
COUNT_SID=$(jq -r '.gates_passed' "$PENDING")
assert "SYNTHESE-ID matcht → counter 1" "1" "$COUNT_SID"

rm -rf "$SANDBOX"
echo ""
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
