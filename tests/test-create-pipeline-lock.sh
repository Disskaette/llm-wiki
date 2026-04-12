#!/usr/bin/env bash
# Tests fuer create-pipeline-lock.sh (Hook E)
set -uo pipefail

HOOK="$(dirname "$0")/../plugin/hooks/create-pipeline-lock.sh"
PASS=0; FAIL=0

assert() {
  if [ "$2" = "$3" ]; then
    echo "  PASS: $1"; PASS=$((PASS+1))
  else
    echo "  FAIL: $1 — expected=$2 actual=$3"; FAIL=$((FAIL+1))
  fi
}

assert_json() {
  local name="$1" field="$2" expected="$3" file="$4"
  local actual
  actual=$(jq -r "$field" "$file" 2>/dev/null || echo "PARSE_ERROR")
  assert "$name" "$expected" "$actual"
}

SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/wiki"
PENDING="$SANDBOX/wiki/_pending.json"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

run_hook() {
  echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK" 2>/dev/null
  return $?
}

echo "╔════════════════════════════════════════════╗"
echo "║  Tests: create-pipeline-lock.sh (Hook E)  ║"
echo "╚════════════════════════════════════════════╝"

# --- Case 1: Nicht-Worker SubagentStop → exit 0, kein _pending.json ---
echo ""
echo "━━━ Case 1: Nicht-Worker Agent ━━━"
JSON_GATE='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"Gate 1 done"}'
run_hook "$JSON_GATE"
assert "non-worker → exit 0" "0" "$?"
assert "non-worker → kein _pending.json" "false" "$([ -f "$PENDING" ] && echo true || echo false)"

# --- Case 2: Ingest-Worker Stop → _pending.json mit typ=ingest, gates_total=4 ---
echo ""
echo "━━━ Case 2: Ingest-Worker Stop ━━━"
JSON_INGEST='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":"Ingest abgeschlossen. [INGEST-ID:schaenzlin-langzeitverhalten-2003]"}'
run_hook "$JSON_INGEST"
assert "ingest-worker → exit 0" "0" "$?"
assert "ingest-worker → _pending.json existiert" "true" "$([ -f "$PENDING" ] && echo true || echo false)"
assert_json "typ = ingest" ".typ" "ingest" "$PENDING"
assert_json "stufe = gates" ".stufe" "gates" "$PENDING"
assert_json "quelle extrahiert" ".quelle" "schaenzlin-langzeitverhalten-2003" "$PENDING"
assert_json "gates_passed = 0" ".gates_passed" "0" "$PENDING"
assert_json "gates_total = 4" ".gates_total" "4" "$PENDING"
TS=$(jq -r '.timestamp // empty' "$PENDING" 2>/dev/null)
assert "timestamp vorhanden" "true" "$([ -n "$TS" ] && echo true || echo false)"
rm -f "$PENDING"

# --- Case 3: Synthese-Worker Stop → _pending.json mit typ=synthese, gates_total=3 ---
echo ""
echo "━━━ Case 3: Synthese-Worker Stop ━━━"
JSON_SYNTHESE='{"agent_type":"bibliothek:synthese-worker","hook_event_name":"SubagentStop","last_assistant_message":"Synthese fertig. [SYNTHESE-ID:querkraft]"}'
run_hook "$JSON_SYNTHESE"
assert "synthese-worker → exit 0" "0" "$?"
assert_json "typ = synthese" ".typ" "synthese" "$PENDING"
assert_json "gates_total = 3" ".gates_total" "3" "$PENDING"
assert_json "quelle = querkraft" ".quelle" "querkraft" "$PENDING"
rm -f "$PENDING"

# --- Case 4: _pending.json existiert bereits → kein Überschreiben ---
echo ""
echo "━━━ Case 4: Bestehende _pending.json ━━━"
echo '{"typ":"ingest","stufe":"sideeffects","quelle":"altes-buch","gates_passed":4,"gates_total":4}' > "$PENDING"
run_hook "$JSON_INGEST"
assert "bestehende lock → exit 0" "0" "$?"
assert_json "quelle unverändert" ".quelle" "altes-buch" "$PENDING"
assert_json "stufe unverändert" ".stufe" "sideeffects" "$PENDING"
rm -f "$PENDING"

# --- Case 5: Worker-Output ohne ID-Marker → quelle = "unbekannt" ---
echo ""
echo "━━━ Case 5: Kein ID-Marker im Output ━━━"
JSON_NO_ID='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":"Ingest fertig. Keine ID."}'
run_hook "$JSON_NO_ID"
assert "kein marker → exit 0" "0" "$?"
assert_json "quelle = unbekannt (fallback)" ".quelle" "unbekannt" "$PENDING"
assert_json "typ = ingest (trotzdem korrekt)" ".typ" "ingest" "$PENDING"
rm -f "$PENDING"

# --- Case 6: Leerer last_assistant_message → quelle = "unbekannt" ---
echo ""
echo "━━━ Case 6: Leere Message ━━━"
JSON_EMPTY_MSG='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":""}'
run_hook "$JSON_EMPTY_MSG"
assert "leere message → exit 0" "0" "$?"
assert_json "quelle = unbekannt" ".quelle" "unbekannt" "$PENDING"
rm -f "$PENDING"

# --- Case 7: Fehlender last_assistant_message key → quelle = "unbekannt" ---
echo ""
echo "━━━ Case 7: Fehlender Message-Key ━━━"
JSON_NO_MSG='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop"}'
run_hook "$JSON_NO_MSG"
assert "fehlender key → exit 0" "0" "$?"
assert_json "quelle = unbekannt" ".quelle" "unbekannt" "$PENDING"
rm -f "$PENDING"

# --- Case 8: INGEST-ID mit .md Suffix → .md wird gestripped ---
echo ""
echo "━━━ Case 8: ID mit .md Suffix ━━━"
JSON_MD='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":"[INGEST-ID:fingerloos-ec2-2016.md] Done"}'
run_hook "$JSON_MD"
assert "md suffix → exit 0" "0" "$?"
assert_json "quelle ohne .md" ".quelle" "fingerloos-ec2-2016" "$PENDING"
rm -f "$PENDING"

# --- Case 9: Nicht-existentes wiki-Verzeichnis → exit 0, kein Crash ---
echo ""
echo "━━━ Case 9: Kein wiki/ Verzeichnis ━━━"
SANDBOX_EMPTY=$(mktemp -d)
JSON_NO_WIKI='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":"[INGEST-ID:test]"}'
echo "$JSON_NO_WIKI" | CLAUDE_PROJECT_DIR="$SANDBOX_EMPTY" bash "$HOOK" 2>/dev/null
assert "kein wiki/ → exit 0" "0" "$?"
assert "kein _pending.json angelegt" "false" "$([ -f "$SANDBOX_EMPTY/wiki/_pending.json" ] && echo true || echo false)"
rm -rf "$SANDBOX_EMPTY"

# --- Case 10: Allgemeiner (nicht-bibliothek) Agent → ignoriert ---
echo ""
echo "━━━ Case 10: General-Purpose Agent ━━━"
JSON_GP='{"agent_type":"general-purpose","hook_event_name":"SubagentStop","last_assistant_message":"Done"}'
run_hook "$JSON_GP"
assert "general-purpose → exit 0" "0" "$?"
assert "general-purpose → kein _pending.json" "false" "$([ -f "$PENDING" ] && echo true || echo false)"

echo ""
echo "════════════════════════════════"
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
