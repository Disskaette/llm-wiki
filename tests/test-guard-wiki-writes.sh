#!/usr/bin/env bash
# Tests fuer guard-wiki-writes.sh (Hook A)
set -uo pipefail

HOOK="$(dirname "$0")/../plugin/hooks/guard-wiki-writes.sh"
PASS=0; FAIL=0

assert() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $name"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $name — expected=$expected actual=$actual"
    FAIL=$((FAIL+1))
  fi
}

run_hook() {
  echo "$1" | bash "$HOOK" 2>&1
  return $?
}

# --- Mock-Transcripts fuer Tests ---
# Format muss dem echten Claude-Code-Transcript entsprechen:
# Skill-Tool-Calls stehen als tool_use-Events in assistant-Messages.
MOCK_DIR=$(mktemp -d)
T_WITH_INGEST="$MOCK_DIR/t_ingest.jsonl"
T_EMPTY="$MOCK_DIR/t_empty.jsonl"
T_FALSE_POSITIVE="$MOCK_DIR/t_false_positive.jsonl"
echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"bibliothek:ingest"}}]}}' > "$T_WITH_INGEST"
echo '{"type":"user","message":{"content":[{"type":"text","text":"hello"}]}}' > "$T_EMPTY"
# Transcript das "ingest" im Gespraech enthaelt, aber KEIN Skill-Tool-Call ist
echo '{"type":"assistant","message":{"content":[{"type":"text","text":"Wir besprechen den /ingest Workflow"}]}}' > "$T_FALSE_POSITIVE"

# --- Case 1: Nicht-Wiki-Pfad wird durchgelassen ---
JSON1='{"transcript_path":"'"$T_EMPTY"'","tool_input":{"file_path":"/tmp/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_hook "$JSON1" >/dev/null
assert "non-wiki path allowed" "0" "$?"

# --- Case 2: Wiki-Pfad mit Skill-Marker im Transcript ---
JSON2='{"transcript_path":"'"$T_WITH_INGEST"'","tool_input":{"file_path":"/Users/x/wiki/quellen/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_hook "$JSON2" >/dev/null
assert "wiki path + ingest in transcript allowed" "0" "$?"

# --- Case 3: Wiki-Pfad ohne Skill-Marker → blockiert ---
JSON3='{"transcript_path":"'"$T_EMPTY"'","tool_input":{"file_path":"/Users/x/wiki/konzepte/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_hook "$JSON3" >/dev/null
assert "wiki path without skill marker blocked" "2" "$?"

# --- Case 4: Edit auf _vokabular.md (Sonderdatei) mit vokabular-Skill ---
T_VOKAB="$MOCK_DIR/t_vokab.jsonl"
echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"vokabular"}}]}}' > "$T_VOKAB"
JSON4='{"transcript_path":"'"$T_VOKAB"'","tool_input":{"file_path":"/Users/x/wiki/_vokabular.md"},"hook_event_name":"PreToolUse","tool_name":"Edit"}'
run_hook "$JSON4" >/dev/null
assert "vokabular.md with /vokabular skill allowed" "0" "$?"

# --- Case 5: transcript_path fehlt ---
JSON5='{"tool_input":{"file_path":"/Users/x/wiki/quellen/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_hook "$JSON5" >/dev/null
assert "missing transcript_path blocks" "2" "$?"

# --- Case 6: FALSE POSITIVE — "ingest" im Gespraech, aber kein Skill-Call ---
JSON6='{"transcript_path":"'"$T_FALSE_POSITIVE"'","tool_input":{"file_path":"/Users/x/wiki/quellen/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_hook "$JSON6" >/dev/null
assert "ingest in conversation text (no skill call) blocked" "2" "$?"

rm -rf "$MOCK_DIR"
echo ""
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
