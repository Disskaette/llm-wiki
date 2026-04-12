#!/usr/bin/env bash
# test-integration-pipeline.sh — Umfassender Integration-Test
# Simuliert den kompletten Pipeline-Lifecycle mit allen 4 Hooks im Zusammenspiel.
#
# Testet:
#   A) guard-wiki-writes.sh   (PreToolUse Edit|Write)
#   B) guard-pipeline-lock.sh (PreToolUse Agent)
#   C) advance-pipeline-lock.sh (SubagentStop)
#   D) inject-lock-warning.sh (UserPromptSubmit)
#   E) check-wiki-output.sh   (Gate-Agent-Checks)
#   E) create-pipeline-lock.sh  (SubagentStop Worker)
#   F) Cross-Hook-Interaktionen ueber den gesamten Lifecycle
#
# Phasen (spiegeln den echten Ingest-Workflow):
#   0. Clean State — kein Lock, kein Transcript
#   1. Ingest gestartet — Skill-Marker im Transcript
#   2. Lock angelegt (stufe=gates) — nach Ingest-Worker-Rueckkehr
#   3. Gate-Advancement — 4 SubagentStops → stufe wechselt
#   4. Sideeffects-Phase — Lock noch aktiv
#   5. Cleanup — Lock geloescht, System wieder frei
#   6. Multi-Skill — synthese/normenupdate/vokabular Transcripts
#   7. Edge Cases — korrupte Daten, fehlende Dateien
#   8. check-wiki-output — deterministische Seiten-Checks (12 Checks)
#   9. Synthese-Pipeline-Lifecycle — synthese-worker Lock, Cross-Block
#  10. INGEST-ID-Matching — ID-basiertes Gate-Counting
#  11. Vollstaendiger Lifecycle (End-to-End Replay)
#  12. Auto-Lock nach Worker-Stop — Hook E erzeugt _pending.json

# Kein -e: fehlgeschlagene Hook-Aufrufe (exit 2) sollen den Test NICHT abbrechen
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/../plugin"

HOOK_A="$PLUGIN_DIR/hooks/guard-wiki-writes.sh"
HOOK_B="$PLUGIN_DIR/hooks/guard-pipeline-lock.sh"
HOOK_C="$PLUGIN_DIR/hooks/advance-pipeline-lock.sh"
HOOK_D="$PLUGIN_DIR/hooks/inject-lock-warning.sh"
CHECK_OUTPUT="$PLUGIN_DIR/hooks/check-wiki-output.sh"
HOOK_E="$PLUGIN_DIR/hooks/create-pipeline-lock.sh"

PASS=0; FAIL=0; SECTION=""

# ============================================================
# Hilfsfunktionen
# ============================================================

section() {
  SECTION="$1"
  echo ""
  echo "━━━ $SECTION ━━━"
}

assert() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ FAIL: $name — expected='$expected' actual='$actual'"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q "$needle" 2>/dev/null; then
    echo "  ✅ $name"
    PASS=$((PASS+1))
  else
    echo "  ❌ FAIL: $name — '$needle' nicht in Output"
    FAIL=$((FAIL+1))
  fi
}

assert_not_contains() {
  local name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q "$needle" 2>/dev/null; then
    echo "  ❌ FAIL: $name — '$needle' unerwartet in Output"
    FAIL=$((FAIL+1))
  else
    echo "  ✅ $name"
    PASS=$((PASS+1))
  fi
}

# Hook-Runner mit isolierter Sandbox
run_wiki_guard() {
  echo "$1" | bash "$HOOK_A" 2>&1
  return $?
}

run_pipeline_guard() {
  echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_B" 2>/dev/null
  return $?
}

run_advance() {
  echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_C" 2>/dev/null
  return $?
}

run_lock_warning() {
  echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_D" 2>&1
  return $?
}

run_create_lock() {
  echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_E" 2>/dev/null
  return $?
}

# ============================================================
# Sandbox aufsetzen
# ============================================================

SANDBOX=$(mktemp -d)
T_DIR=$(mktemp -d)
cleanup() { rm -rf "$SANDBOX" "$T_DIR"; }
trap cleanup EXIT

mkdir -p "$SANDBOX/wiki/quellen" "$SANDBOX/wiki/konzepte" "$SANDBOX/wiki/normen" "$SANDBOX/wiki/_index"
PENDING="$SANDBOX/wiki/_pending.json"

# Mock-Transcripts
T_INGEST="$T_DIR/t_ingest.jsonl"
T_SYNTHESE="$T_DIR/t_synthese.jsonl"
T_NORMENUPDATE="$T_DIR/t_normenupdate.jsonl"
T_VOKABULAR="$T_DIR/t_vokabular.jsonl"
T_EMPTY="$T_DIR/t_empty.jsonl"
T_FALSE_POSITIVE="$T_DIR/t_false_positive.jsonl"
T_MULTI="$T_DIR/t_multi.jsonl"

echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"bibliothek:ingest"}}]}}' > "$T_INGEST"
echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"bibliothek:synthese"}}]}}' > "$T_SYNTHESE"
echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"normenupdate"}}]}}' > "$T_NORMENUPDATE"
echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"vokabular"}}]}}' > "$T_VOKABULAR"
echo '{"type":"user","message":{"content":[{"type":"text","text":"hello"}]}}' > "$T_EMPTY"
echo '{"type":"assistant","message":{"content":[{"type":"text","text":"Lass uns den /ingest Workflow besprechen und danach /synthese ausfuehren"}]}}' > "$T_FALSE_POSITIVE"

# Multi-Skill-Transcript: Ingest + Synthese in einer Session
echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"bibliothek:ingest"}}]}}' > "$T_MULTI"
echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"bibliothek:synthese"}}]}}' >> "$T_MULTI"

# JSON-Bausteine
AGENT_INGEST='{"tool_input":{"subagent_type":"bibliothek:ingest-worker","description":"Ingest: test-buch"},"hook_event_name":"PreToolUse","tool_name":"Agent"}'
AGENT_SYNTHESE='{"tool_input":{"subagent_type":"bibliothek:synthese-worker","description":"Synthese: querkraft"},"hook_event_name":"PreToolUse","tool_name":"Agent"}'
AGENT_GENERAL='{"tool_input":{"subagent_type":"general-purpose","description":"research task"},"hook_event_name":"PreToolUse","tool_name":"Agent"}'
AGENT_GATE='{"tool_input":{"subagent_type":"bibliothek:vollstaendigkeits-pruefer","description":"Gate 1"},"hook_event_name":"PreToolUse","tool_name":"Agent"}'
GATE_STOP='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop"}'
GATE_STOP_WITH_ID='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"Pruefung abgeschlossen. [INGEST-ID:test-buch-ec2]"}'
GATE_STOP_WRONG_ID='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"Pruefung abgeschlossen. [INGEST-ID:anderes-buch]"}'
GATE_STOP_SYNTHESE_ID='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"Pruefung abgeschlossen. [SYNTHESE-ID:querkraft-synthese]"}'
GATE_STOP_SYNTHESE_WRONG='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"Pruefung abgeschlossen. [SYNTHESE-ID:falsche-synthese]"}'
PROMPT_SUBMIT='{"prompt":"Was ist der Status?","hook_event_name":"UserPromptSubmit"}'

WORKER_INGEST_STOP='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":"Ingest fertig. [INGEST-ID:test-buch-ec2]"}'
WORKER_SYNTHESE_STOP='{"agent_type":"bibliothek:synthese-worker","hook_event_name":"SubagentStop","last_assistant_message":"Synthese fertig. [SYNTHESE-ID:querkraft-synthese]"}'
WORKER_INGEST_NO_ID='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":"Ingest fertig ohne Marker."}'

echo "╔══════════════════════════════════════════════════════╗"
echo "║  Integration-Test: Governance & Pipeline Lifecycle   ║"
echo "╚══════════════════════════════════════════════════════╝"

# ============================================================
# PHASE 0: Clean State
# ============================================================

section "Phase 0: Clean State — kein Lock, keine Skills"

# Hook A: Wiki-Writes ohne Skill-Marker blockiert
JSON_A='{"transcript_path":"'"$T_EMPTY"'","tool_input":{"file_path":"/Users/x/wiki/quellen/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_wiki_guard "$JSON_A" >/dev/null
assert "A: Wiki-Write ohne Skill → blockiert" "2" "$?"

# Hook A: Nicht-Wiki-Pfad durchgelassen
JSON_A2='{"transcript_path":"'"$T_EMPTY"'","tool_input":{"file_path":"/tmp/notes.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_wiki_guard "$JSON_A2" >/dev/null
assert "A: Nicht-Wiki-Pfad → erlaubt" "0" "$?"

# Hook B: Ingest-Worker ohne Lock erlaubt
run_pipeline_guard "$AGENT_INGEST"
assert "B: Ingest-Worker ohne Lock → erlaubt" "0" "$?"

# Hook B: General-Purpose Agent immer erlaubt
run_pipeline_guard "$AGENT_GENERAL"
assert "B: General-Purpose Agent → erlaubt" "0" "$?"

# Hook C: SubagentStop ohne Lock → silent
run_advance "$GATE_STOP"
assert "C: SubagentStop ohne Lock → silent exit 0" "0" "$?"
assert "C: Kein _pending.json erzeugt" "false" "$([ -f "$PENDING" ] && echo true || echo false)"

# Hook D: Keine Warnung ohne Lock
OUT_D=$(run_lock_warning "$PROMPT_SUBMIT")
RC_D=$?
assert "D: UserPromptSubmit ohne Lock → exit 0" "0" "$RC_D"
assert "D: Keine Ausgabe ohne Lock" "" "$OUT_D"

# ============================================================
# PHASE 1: Ingest gestartet — Skill-Marker vorhanden
# ============================================================

section "Phase 1: Ingest gestartet — Skill im Transcript"

# Hook A: Wiki-Write mit Ingest-Skill erlaubt
JSON_A_INGEST='{"transcript_path":"'"$T_INGEST"'","tool_input":{"file_path":"/Users/x/wiki/quellen/test-buch.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_wiki_guard "$JSON_A_INGEST" >/dev/null
assert "A: Wiki-Write mit /ingest Skill → erlaubt" "0" "$?"

# Hook A: Edit mit Ingest-Skill erlaubt
JSON_A_EDIT='{"transcript_path":"'"$T_INGEST"'","tool_input":{"file_path":"/Users/x/wiki/konzepte/beton.md"},"hook_event_name":"PreToolUse","tool_name":"Edit"}'
run_wiki_guard "$JSON_A_EDIT" >/dev/null
assert "A: Wiki-Edit mit /ingest Skill → erlaubt" "0" "$?"

# Hook A: False Positive — "ingest" im Text, aber kein Skill-Call
JSON_A_FP='{"transcript_path":"'"$T_FALSE_POSITIVE"'","tool_input":{"file_path":"/Users/x/wiki/quellen/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_wiki_guard "$JSON_A_FP" >/dev/null
assert "A: 'ingest' im Text (kein Skill-Call) → blockiert" "2" "$?"

# Hook B: Ingest-Worker noch erlaubt (kein Lock)
run_pipeline_guard "$AGENT_INGEST"
assert "B: Ingest-Worker vor Lock-Erstellung → erlaubt" "0" "$?"

# ============================================================
# PHASE 2: Lock angelegt (stufe=gates, gates_passed=0)
# ============================================================

section "Phase 2: Lock angelegt — stufe=gates"

echo '{"typ":"ingest","stufe":"gates","quelle":"test-buch-ec2","timestamp":"2026-04-11T10:00:00Z","gates_passed":0,"gates_total":4}' > "$PENDING"

# Hook B: Ingest-Worker jetzt blockiert
ERR_B=$(run_pipeline_guard "$AGENT_INGEST" 2>&1)
RC_B=$?
# Need to capture stderr separately
ERR_B2=$(echo "$AGENT_INGEST" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_B" 2>&1 >/dev/null)
RC_B2=$?
assert "B: Ingest-Worker mit Lock → blockiert (exit 2)" "2" "$RC_B2"
assert_contains "B: Fehlermeldung nennt Quelle" "test-buch-ec2" "$ERR_B2"
assert_contains "B: Fehlermeldung nennt Stufe" "gates" "$ERR_B2"
assert_contains "B: Fehlermeldung zeigt Gates-Zaehler" "0/4" "$ERR_B2"
assert_contains "B: Fehlermeldung zeigt Typ" "Typ:" "$ERR_B2"

# Hook B: Nicht-Ingest-Worker weiterhin erlaubt
run_pipeline_guard "$AGENT_GENERAL"
assert "B: General-Purpose trotz Lock → erlaubt" "0" "$?"

# Hook B: Gate-Agent-Dispatch erlaubt (ist kein ingest-worker)
run_pipeline_guard "$AGENT_GATE"
assert "B: Gate-Agent-Dispatch trotz Lock → erlaubt" "0" "$?"

# Hook B: Synthese-Worker ebenfalls blockiert (cross-block)
ERR_B_SYNTH=$(echo "$AGENT_SYNTHESE" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_B" 2>&1 >/dev/null)
RC_B_SYNTH=$?
assert "B: Synthese-Worker mit Ingest-Lock → blockiert" "2" "$RC_B_SYNTH"

# Hook D: Lock-Warnung wird injiziert
OUT_D2=$(run_lock_warning "$PROMPT_SUBMIT")
RC_D2=$?
assert "D: UserPromptSubmit mit Lock → exit 0" "0" "$RC_D2"
assert_contains "D: Warnung enthaelt Quellennamen" "test-buch-ec2" "$OUT_D2"
assert_contains "D: Warnung enthaelt Stufe" "gates" "$OUT_D2"
assert_contains "D: Warnung enthaelt Typ=" "Typ=" "$OUT_D2"
assert_contains "D: Warnung enthaelt Gates-Zaehler" "Gates=" "$OUT_D2"

# Valides JSON?
if echo "$OUT_D2" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
  echo "  ✅ D: Warnung ist valides JSON mit additionalContext"
  PASS=$((PASS+1))
else
  echo "  ❌ FAIL: D: Warnung ist kein valides JSON"
  FAIL=$((FAIL+1))
fi

# Hook A: Wiki-Writes mit Skill weiterhin erlaubt (Lock beeinflusst Write-Guard nicht)
run_wiki_guard "$JSON_A_INGEST" >/dev/null
assert "A: Wiki-Write mit Skill trotz Lock → erlaubt (unabhaengige Hooks)" "0" "$?"

# Hook A: Wiki-Writes ohne Skill weiterhin blockiert
run_wiki_guard "$JSON_A" >/dev/null
assert "A: Wiki-Write ohne Skill trotz Lock → blockiert" "2" "$?"

# ============================================================
# PHASE 3: Gate-Advancement (4 SubagentStops)
# ============================================================

section "Phase 3: Gate-Advancement — 4 SubagentStops"

# Gate 1
run_advance "$GATE_STOP"
assert "C: Gate 1 → exit 0" "0" "$?"
COUNT=$(jq -r '.gates_passed' "$PENDING")
STUFE=$(jq -r '.stufe' "$PENDING")
assert "C: Counter nach Gate 1 = 1" "1" "$COUNT"
assert "C: Stufe nach Gate 1 = gates" "gates" "$STUFE"

# Zwischenstand: Ingest-Worker noch blockiert
ERR_MID=$(echo "$AGENT_INGEST" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_B" 2>&1 >/dev/null)
RC_MID=$?
assert "B: Ingest-Worker bei gates_passed=1 → blockiert" "2" "$RC_MID"
assert_contains "B: Zaehler zeigt 1/4" "1/4" "$ERR_MID"

# Gate 2
run_advance "$GATE_STOP"
COUNT=$(jq -r '.gates_passed' "$PENDING")
assert "C: Counter nach Gate 2 = 2" "2" "$COUNT"

# Lock-Warnung waehrend Gates (sollte immer noch injiziert werden)
OUT_D3=$(run_lock_warning "$PROMPT_SUBMIT")
assert_contains "D: Warnung bei gates_passed=2 noch aktiv" "test-buch-ec2" "$OUT_D3"

# Gate 3
run_advance "$GATE_STOP"
COUNT=$(jq -r '.gates_passed' "$PENDING")
assert "C: Counter nach Gate 3 = 3" "3" "$COUNT"
STUFE=$(jq -r '.stufe' "$PENDING")
assert "C: Stufe nach Gate 3 = gates (noch nicht umgeschaltet)" "gates" "$STUFE"

# Gate 4 — Umschaltung!
run_advance "$GATE_STOP"
COUNT=$(jq -r '.gates_passed' "$PENDING")
STUFE=$(jq -r '.stufe' "$PENDING")
assert "C: Counter nach Gate 4 = 4" "4" "$COUNT"
assert "C: Stufe nach Gate 4 = sideeffects (umgeschaltet!)" "sideeffects" "$STUFE"

# ============================================================
# PHASE 4: Sideeffects-Phase — Lock noch aktiv
# ============================================================

section "Phase 4: Sideeffects-Phase — Lock aktiv, Gates durch"

# Hook B: Ingest-Worker immer noch blockiert
ERR_SE=$(echo "$AGENT_INGEST" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_B" 2>&1 >/dev/null)
RC_SE=$?
assert "B: Ingest-Worker bei sideeffects → blockiert" "2" "$RC_SE"
assert_contains "B: Fehlermeldung zeigt sideeffects" "sideeffects" "$ERR_SE"
assert_contains "B: Fehlermeldung zeigt 4/4" "4/4" "$ERR_SE"

# Hook C: Weitere SubagentStops aendern nichts mehr
run_advance "$GATE_STOP"
COUNT=$(jq -r '.gates_passed' "$PENDING")
STUFE=$(jq -r '.stufe' "$PENDING")
assert "C: Counter bleibt 4 nach Extra-Stop" "4" "$COUNT"
assert "C: Stufe bleibt sideeffects" "sideeffects" "$STUFE"

# Hook D: Warnung zeigt sideeffects
OUT_D4=$(run_lock_warning "$PROMPT_SUBMIT")
assert_contains "D: Warnung zeigt sideeffects-Stufe" "sideeffects" "$OUT_D4"

# ============================================================
# PHASE 5: Cleanup — Lock geloescht
# ============================================================

section "Phase 5: Cleanup — Lock geloescht"

rm -f "$PENDING"

# Hook B: Ingest-Worker wieder frei
run_pipeline_guard "$AGENT_INGEST"
assert "B: Ingest-Worker nach Cleanup → erlaubt" "0" "$?"

# Hook D: Keine Warnung mehr
OUT_D5=$(run_lock_warning "$PROMPT_SUBMIT")
assert "D: Keine Warnung nach Cleanup" "" "$OUT_D5"

# Hook C: SubagentStop ohne Lock → harmlos
run_advance "$GATE_STOP"
assert "C: SubagentStop nach Cleanup → silent" "0" "$?"
assert "C: Kein _pending.json nach Cleanup-Stop" "false" "$([ -f "$PENDING" ] && echo true || echo false)"

# ============================================================
# PHASE 6: Multi-Skill — andere Schreib-Skills
# ============================================================

section "Phase 6: Multi-Skill — synthese, normenupdate, vokabular"

# Synthese-Skill erlaubt Wiki-Writes
JSON_SYNTH='{"transcript_path":"'"$T_SYNTHESE"'","tool_input":{"file_path":"/Users/x/wiki/konzepte/querkraft.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_wiki_guard "$JSON_SYNTH" >/dev/null
assert "A: Wiki-Write mit /synthese → erlaubt" "0" "$?"

# Normenupdate-Skill erlaubt Wiki-Writes
JSON_NORM='{"transcript_path":"'"$T_NORMENUPDATE"'","tool_input":{"file_path":"/Users/x/wiki/normen/din-en-1992.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_wiki_guard "$JSON_NORM" >/dev/null
assert "A: Wiki-Write mit /normenupdate → erlaubt" "0" "$?"

# Vokabular-Skill erlaubt _vokabular.md
JSON_VOK='{"transcript_path":"'"$T_VOKABULAR"'","tool_input":{"file_path":"/Users/x/wiki/_vokabular.md"},"hook_event_name":"PreToolUse","tool_name":"Edit"}'
run_wiki_guard "$JSON_VOK" >/dev/null
assert "A: Wiki-Edit _vokabular.md mit /vokabular → erlaubt" "0" "$?"

# Multi-Skill-Transcript: beide Skills erkannt
JSON_MULTI='{"transcript_path":"'"$T_MULTI"'","tool_input":{"file_path":"/Users/x/wiki/konzepte/test.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_wiki_guard "$JSON_MULTI" >/dev/null
assert "A: Wiki-Write mit Multi-Skill-Transcript → erlaubt" "0" "$?"

# ============================================================
# PHASE 7: Edge Cases
# ============================================================

section "Phase 7: Edge Cases — korrupte Daten, Grenzfaelle"

# 7a: Korruptes _pending.json — alle Hooks defensiv
echo 'THIS IS NOT JSON' > "$PENDING"

run_pipeline_guard "$AGENT_INGEST"
assert "B: Korruptes Pending → defensiv erlaubt" "0" "$?"

run_advance "$GATE_STOP"
assert "C: Korruptes Pending → exit 0 ohne Crash" "0" "$?"

OUT_D6=$(run_lock_warning "$PROMPT_SUBMIT")
RC_D6=$?
assert "D: Korruptes Pending → exit 0" "0" "$RC_D6"
# Kein additionalContext bei kaputtem JSON
if echo "$OUT_D6" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
  echo "  ❌ FAIL: D: Sollte kein additionalContext bei kaputtem JSON ausgeben"
  FAIL=$((FAIL+1))
else
  echo "  ✅ D: Kein additionalContext bei kaputtem JSON"
  PASS=$((PASS+1))
fi

rm -f "$PENDING"

# 7b: Leeres _pending.json
echo '' > "$PENDING"
run_pipeline_guard "$AGENT_INGEST"
assert "B: Leeres Pending → defensiv erlaubt" "0" "$?"
run_advance "$GATE_STOP"
assert "C: Leeres Pending → exit 0" "0" "$?"
rm -f "$PENDING"

# 7c: Pending mit unbekannter Stufe
echo '{"typ":"ingest","stufe":"unknown","quelle":"test","gates_passed":2,"gates_total":4}' > "$PENDING"
run_advance "$GATE_STOP"
STUFE_UNK=$(jq -r '.stufe' "$PENDING" 2>/dev/null || echo "error")
assert "C: Unbekannte Stufe → nicht angefasst" "unknown" "$STUFE_UNK"
rm -f "$PENDING"

# 7d: Fehlender transcript_path → blockiert (defensiv)
JSON_NO_TP='{"tool_input":{"file_path":"/Users/x/wiki/quellen/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_wiki_guard "$JSON_NO_TP" >/dev/null
assert "A: Fehlender transcript_path → blockiert" "2" "$?"

# 7e: Legacy-Pending ohne gates_passed/gates_total
echo '{"typ":"ingest","stufe":"gates","quelle":"legacy-buch"}' > "$PENDING"
run_advance "$GATE_STOP"
COUNT_LEG=$(jq -r '.gates_passed' "$PENDING" 2>/dev/null || echo "error")
assert "C: Legacy-Pending → Counter auf 1 migriert" "1" "$COUNT_LEG"
rm -f "$PENDING"

# 7f: Doppelter Lifecycle — zweiter Ingest nach erstem Cleanup
echo '{"typ":"ingest","stufe":"gates","quelle":"buch-1","timestamp":"2026-04-11T10:00:00Z","gates_passed":0,"gates_total":4}' > "$PENDING"
for i in 1 2 3 4; do run_advance "$GATE_STOP"; done
STUFE_1=$(jq -r '.stufe' "$PENDING")
assert "C: Erster Lifecycle → sideeffects" "sideeffects" "$STUFE_1"
rm -f "$PENDING"
# Zweiter Ingest
run_pipeline_guard "$AGENT_INGEST"
assert "B: Zweiter Ingest nach Cleanup → erlaubt" "0" "$?"
echo '{"typ":"ingest","stufe":"gates","quelle":"buch-2","timestamp":"2026-04-11T11:00:00Z","gates_passed":0,"gates_total":4}' > "$PENDING"
ERR_2ND=$(echo "$AGENT_INGEST" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_B" 2>&1 >/dev/null)
assert_contains "B: Zweiter Lock nennt buch-2" "buch-2" "$ERR_2ND"
rm -f "$PENDING"

# 7g: Gates-Zahl groesser als gates_total (Overflow-Schutz)
echo '{"typ":"ingest","stufe":"gates","quelle":"test","gates_passed":3,"gates_total":4}' > "$PENDING"
run_advance "$GATE_STOP"   # → 4, sideeffects
run_advance "$GATE_STOP"   # → nochmal (stufe ist jetzt sideeffects)
COUNT_OVF=$(jq -r '.gates_passed' "$PENDING" 2>/dev/null)
assert "C: Kein Overflow ueber gates_total hinaus (bleibt 4)" "4" "$COUNT_OVF"
rm -f "$PENDING"

# 7h: Hook A — leerer file_path → nicht unser Fall, exit 0
JSON_EMPTY_FP='{"transcript_path":"'"$T_EMPTY"'","tool_input":{"file_path":""},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_wiki_guard "$JSON_EMPTY_FP" >/dev/null
assert "A: Leerer file_path → erlaubt (nicht unser Fall)" "0" "$?"

# 7i: Hook A — Nicht-.md Datei unter wiki/ → nicht gematcht (Pattern: */wiki/*.md)
JSON_NON_MD='{"transcript_path":"'"$T_EMPTY"'","tool_input":{"file_path":"/Users/x/wiki/image.png"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_wiki_guard "$JSON_NON_MD" >/dev/null
assert "A: wiki/image.png (kein .md) → erlaubt" "0" "$?"

# 7j: Hook A — Bare Skill-Name ohne bibliothek:-Prefix
T_BARE="$T_DIR/t_bare.jsonl"
echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"ingest"}}]}}' > "$T_BARE"
JSON_BARE='{"transcript_path":"'"$T_BARE"'","tool_input":{"file_path":"/Users/x/wiki/quellen/test.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_wiki_guard "$JSON_BARE" >/dev/null
assert "A: Bare Skill-Name 'ingest' (ohne Prefix) → erlaubt" "0" "$?"

# 7k: Hook A — Nicht-existente Transcript-Datei → blockiert
JSON_NOFILE='{"transcript_path":"/tmp/does-not-exist-12345.jsonl","tool_input":{"file_path":"/Users/x/wiki/quellen/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_wiki_guard "$JSON_NOFILE" >/dev/null
assert "A: Nicht-existente Transcript-Datei → blockiert" "2" "$?"

# 7l: Hook B — fehlendes subagent_type Feld → erlaubt (nicht ingest-worker)
AGENT_NO_TYPE='{"tool_input":{"description":"some task"},"hook_event_name":"PreToolUse","tool_name":"Agent"}'
run_pipeline_guard "$AGENT_NO_TYPE"
assert "B: Fehlendes subagent_type → erlaubt" "0" "$?"

# 7m: Hook B — Pending mit leerer quelle → defensiv erlaubt
echo '{"typ":"ingest","stufe":"gates","quelle":"","gates_passed":0,"gates_total":4}' > "$PENDING"
run_pipeline_guard "$AGENT_INGEST"
assert "B: Pending mit leerer quelle → defensiv erlaubt" "0" "$?"
rm -f "$PENDING"

# 7n: Hook B — Pending mit leerer stufe → defensiv erlaubt
echo '{"typ":"ingest","stufe":"","quelle":"test","gates_passed":0,"gates_total":4}' > "$PENDING"
run_pipeline_guard "$AGENT_INGEST"
assert "B: Pending mit leerer stufe → defensiv erlaubt" "0" "$?"
rm -f "$PENDING"

# 7o: Hook D — Pending mit leerer quelle → silent (kein Output)
echo '{"typ":"ingest","stufe":"gates","quelle":""}' > "$PENDING"
OUT_D_EMPTY_Q=$(run_lock_warning "$PROMPT_SUBMIT")
assert "D: Pending mit leerer quelle → silent" "" "$OUT_D_EMPTY_Q"
rm -f "$PENDING"

# 7p: Hook C — Nicht-Standard gates_total (z.B. 3 statt 4)
echo '{"typ":"ingest","stufe":"gates","quelle":"test","gates_passed":2,"gates_total":3}' > "$PENDING"
run_advance "$GATE_STOP"
STUFE_3=$(jq -r '.stufe' "$PENDING" 2>/dev/null)
COUNT_3=$(jq -r '.gates_passed' "$PENDING" 2>/dev/null)
assert "C: gates_total=3, nach 3. Gate → sideeffects" "sideeffects" "$STUFE_3"
assert "C: Counter bei custom gates_total = 3" "3" "$COUNT_3"
rm -f "$PENDING"

# ============================================================
# PHASE 8: check-wiki-output.sh — Seiten-Checks (12 Checks)
# ============================================================

section "Phase 8: check-wiki-output — deterministische Checks (12 Checks)"

# 8a: Wohlgeformte Quellenseite
VOKABULAR="$SANDBOX/wiki/_vokabular.md"
cat > "$VOKABULAR" << 'VOCAB_EOF'
# Kontrolliertes Vokabular

### Stahlbeton
Synonym: Eisenbeton

### Querkraft
Synonym: Schubkraft

### Biegung
VOCAB_EOF

GOOD_PAGE="$SANDBOX/wiki/quellen/test-buch-ec2.md"
cat > "$GOOD_PAGE" << 'PAGE_EOF'
---
type: quelle
title: "Stahlbetonbau nach EC2"
autor: Mustermann
ausgabe: 2022
schlagworte:
  - Stahlbeton
  - Querkraft
kapitel-index:
  - "1. Grundlagen"
  - "2. Bemessung"
reviewed: false
---

# Stahlbetonbau nach EC2

## Kapitel 1: Grundlagen

Die Mindestbewehrung beträgt 0,15 % (Mustermann 2022, S. 45).

Querverweise: [[Querkraft]], [[Biegung]]
PAGE_EOF

OUT_8A=$(bash "$CHECK_OUTPUT" "$GOOD_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
RC_8A=$?
assert "E: Wohlgeformte Quellenseite → exit 0" "0" "$RC_8A"
assert_not_contains "E: Keine FAILs bei wohlgeformter Seite" "❌ FAIL:" "$OUT_8A"

# 8b: Seite ohne Frontmatter-type → FAIL
BAD_PAGE="$SANDBOX/wiki/quellen/bad-page.md"
cat > "$BAD_PAGE" << 'BAD_EOF'
---
title: "Fehlerhaft"
schlagworte:
  - Stahlbeton
---

# Fehlerhaft

Kein type-Feld im Frontmatter.
BAD_EOF

OUT_8B=$(bash "$CHECK_OUTPUT" "$BAD_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
RC_8B=$?
assert "E: Seite ohne type → exit 1 (FAIL)" "1" "$RC_8B"
assert_contains "E: Check 01 meldet fehlendes type-Feld" "01-frontmatter-type" "$OUT_8B"

# 8c: Konzeptseite ohne Wikilinks → FAIL
NOLINK_PAGE="$SANDBOX/wiki/konzepte/kein-link.md"
cat > "$NOLINK_PAGE" << 'NOLINK_EOF'
---
type: konzept
title: "Ohne Querverweise"
schlagworte:
  - Biegung
reviewed: true
---

# Ohne Querverweise

Dieser Text hat keine Wikilinks.
NOLINK_EOF

OUT_8C=$(bash "$CHECK_OUTPUT" "$NOLINK_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
RC_8C=$?
assert "E: Konzeptseite ohne Wikilinks → exit 1" "1" "$RC_8C"
assert_contains "E: Check 07 meldet fehlende Querverweise" "07-querverweise" "$OUT_8C"

# 8d: Seite mit offenen Markern → FAIL
MARKER_PAGE="$SANDBOX/wiki/quellen/marker-page.md"
cat > "$MARKER_PAGE" << 'MARKER_EOF'
---
type: quelle
title: "Mit Markern"
schlagworte:
  - Stahlbeton
kapitel-index:
  - "1. Test"
reviewed: false
---

# Mit Markern

Hier fehlt eine Angabe [TODO] und hier ist etwas [UNSICHER].
MARKER_EOF

OUT_8D=$(bash "$CHECK_OUTPUT" "$MARKER_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
RC_8D=$?
assert "E: Seite mit [TODO]-Marker → exit 1" "1" "$RC_8D"
assert_contains "E: Check 08 meldet offene Marker" "08-offene-marker" "$OUT_8D"

# 8d2: Check 08 erkennt auch [SYNTHESE UNVOLLSTAENDIG]
SYNTH_MARKER_PAGE="$SANDBOX/wiki/quellen/synth-marker.md"
cat > "$SYNTH_MARKER_PAGE" << 'SYNTH_MARKER_EOF'
---
type: quelle
title: "Synthese Marker"
schlagworte:
  - Stahlbeton
kapitel-index:
  - "1. Test"
reviewed: false
---

# Synthese Marker

Hier ist noch [SYNTHESE UNVOLLSTAENDIG] zu bearbeiten.
SYNTH_MARKER_EOF

OUT_8D2=$(bash "$CHECK_OUTPUT" "$SYNTH_MARKER_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
RC_8D2=$?
assert "E: Seite mit [SYNTHESE UNVOLLSTAENDIG] → exit 1" "1" "$RC_8D2"
assert_contains "E: Check 08 erkennt SYNTHESE UNVOLLSTAENDIG" "08-offene-marker" "$OUT_8D2"

# 8e: Schlagworte nicht im Vokabular → FAIL
BAD_TAGS_PAGE="$SANDBOX/wiki/quellen/bad-tags.md"
cat > "$BAD_TAGS_PAGE" << 'TAGS_EOF'
---
type: quelle
title: "Unbekannte Tags"
schlagworte:
  - Stahlbeton
  - NichtImVokabular
kapitel-index:
  - "1. Test"
reviewed: false
---

# Unbekannte Tags
TAGS_EOF

OUT_8E=$(bash "$CHECK_OUTPUT" "$BAD_TAGS_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
RC_8E=$?
assert "E: Unbekanntes Schlagwort → exit 1" "1" "$RC_8E"
assert_contains "E: Check 03 meldet fehlendes Schlagwort" "NichtImVokabular" "$OUT_8E"

# 8f: Quellenseite ohne kapitel-index → FAIL
NOINDEX_PAGE="$SANDBOX/wiki/quellen/no-index.md"
cat > "$NOINDEX_PAGE" << 'NOINDEX_EOF'
---
type: quelle
title: "Ohne Index"
schlagworte:
  - Biegung
reviewed: false
---

# Ohne Index
NOINDEX_EOF

OUT_8F=$(bash "$CHECK_OUTPUT" "$NOINDEX_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
RC_8F=$?
assert "E: Quellenseite ohne kapitel-index → exit 1" "1" "$RC_8F"
assert_contains "E: Check 10 meldet fehlenden Index" "10-kapitelindex" "$OUT_8F"

# 8g: Ungueltiger Typ-Wert → FAIL auf Check 02
BADTYPE_PAGE="$SANDBOX/wiki/quellen/bad-type.md"
cat > "$BADTYPE_PAGE" << 'BADTYPE_EOF'
---
type: invalid
title: "Ungültiger Typ"
schlagworte:
  - Stahlbeton
kapitel-index:
  - "1. Test"
reviewed: false
---

# Ungültiger Typ
BADTYPE_EOF

OUT_8G=$(bash "$CHECK_OUTPUT" "$BADTYPE_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
RC_8G=$?
assert "E: Ungueltiger type-Wert → exit 1" "1" "$RC_8G"
assert_contains "E: Check 02 meldet ungueltigen Typ" "02-seitentyp-gueltig" "$OUT_8G"

# 8i: Duplikat-Quellenseite → FAIL auf Check 11
DUPE_PAGE="$SANDBOX/wiki/quellen/test-buch-ec2-copy.md"
cat > "$DUPE_PAGE" << 'DUPE_EOF'
---
type: quelle
title: "Stahlbetonbau nach EC2"
schlagworte:
  - Stahlbeton
kapitel-index:
  - "1. Test"
reviewed: false
---

# Duplikat
DUPE_EOF

OUT_8I=$(bash "$CHECK_OUTPUT" "$DUPE_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
RC_8I=$?
assert "E: Duplikat-Quellenseite → exit 1" "1" "$RC_8I"
assert_contains "E: Check 11 meldet Duplikat" "11-duplikat-quellen" "$OUT_8I"

# 8j: Wikilinks aufloesbar (mit vorhandenen Ziel-Dateien) → PASS auf Check 14
# querkraft.md existiert noch nicht als Datei → anlegen
cat > "$SANDBOX/wiki/konzepte/querkraft.md" << 'QK_EOF'
---
type: konzept
title: "Querkraft"
schlagworte:
  - Querkraft
reviewed: false
---

# Querkraft
QK_EOF
cat > "$SANDBOX/wiki/konzepte/biegung.md" << 'BG_EOF'
---
type: konzept
title: "Biegung"
schlagworte:
  - Biegung
reviewed: false
---

# Biegung
BG_EOF

# Teste die GOOD_PAGE nochmal — jetzt mit aufloesbaren Wikilinks
OUT_8J=$(bash "$CHECK_OUTPUT" "$GOOD_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
assert_not_contains "E: Check 14 findet keine unaufloesbaren Links" "14-wikilinks-aufloesbar.*Nicht" "$OUT_8J"

# 8k: Unvollstaendiger Widerspruch-Marker → FAIL auf Check 15
WIDERSPRUCH_PAGE="$SANDBOX/wiki/konzepte/widerspruch.md"
cat > "$WIDERSPRUCH_PAGE" << 'WS_EOF'
---
type: konzept
title: "Widerspruchstest"
schlagworte:
  - Stahlbeton
reviewed: false
---

# Widerspruchstest

[WIDERSPRUCH] Die Festigkeitswerte weichen ab.

Querverweise: [[Querkraft]]
WS_EOF

OUT_8K=$(bash "$CHECK_OUTPUT" "$WIDERSPRUCH_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
RC_8K=$?
assert "E: Unvollstaendiger Widerspruch-Marker → exit 1" "1" "$RC_8K"
assert_contains "E: Check 15 meldet unvollstaendigen Marker" "15-widerspruch-marker" "$OUT_8K"

# 8l: Inline-Schlagworte-Format [term1, term2] → PASS auf Check 03
INLINE_TAGS_PAGE="$SANDBOX/wiki/quellen/inline-tags.md"
cat > "$INLINE_TAGS_PAGE" << 'INLINE_EOF'
---
type: quelle
title: "Inline Tags"
schlagworte: [Stahlbeton, Querkraft]
kapitel-index:
  - "1. Test"
reviewed: false
---

# Inline Tags
INLINE_EOF

OUT_8L=$(bash "$CHECK_OUTPUT" "$INLINE_TAGS_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
RC_8L=$?
assert "E: Inline-Schlagworte (gueltig) → exit 0" "0" "$RC_8L"
assert_not_contains "E: Check 03 bei Inline-Format kein FAIL" "03-schlagworte.*FAIL" "$OUT_8L"

# 8o: Fehlende reviewed-Feld → WARN auf Check 16
NOREV_PAGE="$SANDBOX/wiki/quellen/no-review.md"
cat > "$NOREV_PAGE" << 'NOREV_EOF'
---
type: quelle
title: "Ohne Review"
schlagworte:
  - Biegung
kapitel-index:
  - "1. Test"
---

# Ohne Review
NOREV_EOF

OUT_8O=$(bash "$CHECK_OUTPUT" "$NOREV_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
assert_contains "E: Check 16 erkennt fehlendes reviewed-Feld (WARN)" "16-review-status" "$OUT_8O"

# 8q: Check 14 negativ — unaufloesbarer Wikilink → WARN
BROKEN_LINK_PAGE="$SANDBOX/wiki/konzepte/broken-link.md"
cat > "$BROKEN_LINK_PAGE" << 'BL_EOF'
---
type: konzept
title: "Broken Link"
schlagworte:
  - Stahlbeton
reviewed: false
---

# Broken Link

Verweis auf [[NichtExistierendeSeite]] und [[Querkraft]].
BL_EOF

OUT_8Q_BL=$(bash "$CHECK_OUTPUT" "$BROKEN_LINK_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
assert_contains "E: Check 14 meldet unaufloesbaren Wikilink (WARN)" "NichtExistierendeSeite" "$OUT_8Q_BL"

# 8r: Check 12 + 13 (deferred) — immer WARN
OUT_8R=$(bash "$CHECK_OUTPUT" "$GOOD_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
assert_contains "E: Check 12 (deferred) gibt WARN" "12-index-eintrag" "$OUT_8R"
assert_contains "E: Check 13 (deferred) gibt WARN" "13-log-eintrag" "$OUT_8R"

# 8s: Single-Quoted Schlagworte → PASS (Bug I-2 Fix)
SQ_PAGE="$SANDBOX/wiki/quellen/single-quote.md"
cat > "$SQ_PAGE" << 'SQ_EOF'
---
type: quelle
title: "Single Quote Tags"
schlagworte:
  - 'Stahlbeton'
  - 'Querkraft'
kapitel-index:
  - "1. Test"
reviewed: false
---

# Single Quote Tags
SQ_EOF

OUT_8S=$(bash "$CHECK_OUTPUT" "$SQ_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
assert_not_contains "E: Single-Quoted Schlagworte → kein FAIL auf Check 03" "03-schlagworte.*FAIL" "$OUT_8S"

# 8t: Duplikat-Substring — kein False Positive (Bug I-1 Fix)
# "Betonbau nach EC2" darf NICHT als Duplikat von "Stahlbetonbau nach EC2" gemeldet werden
SHORT_PAGE="$SANDBOX/wiki/quellen/beton-kurz.md"
cat > "$SHORT_PAGE" << 'SHORT_EOF'
---
type: quelle
title: "Beton"
schlagworte:
  - Stahlbeton
kapitel-index:
  - "1. Test"
reviewed: false
---

# Beton
SHORT_EOF

OUT_8T=$(bash "$CHECK_OUTPUT" "$SHORT_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
assert_not_contains "E: Check 11 kein Substring-False-Positive ('Beton' vs 'Stahlbetonbau')" "11-duplikat.*FAIL" "$OUT_8T"

# 8u: Alle 6 gültigen Seitentypen akzeptiert (Check 02)
for VALID_TYPE in quelle konzept norm baustoff verfahren moc; do
  TYPTEST_PAGE="$SANDBOX/wiki/konzepte/typtest-${VALID_TYPE}.md"
  cat > "$TYPTEST_PAGE" << TYPTEST_EOF
---
type: ${VALID_TYPE}
title: "Typtest ${VALID_TYPE}"
schlagworte:
  - Stahlbeton
reviewed: false
---

# Typtest ${VALID_TYPE}

Querverweise: [[Querkraft]]
TYPTEST_EOF
  OUT_TT=$(bash "$CHECK_OUTPUT" "$TYPTEST_PAGE" "$VOKABULAR" "$SANDBOX/wiki/" 2>&1)
  assert_not_contains "E: Typ '${VALID_TYPE}' → Check 02 kein FAIL" "02-seitentyp-gueltig.*FAIL" "$OUT_TT"
done

# ============================================================
# PHASE 9: Synthese-Pipeline-Lifecycle
# ============================================================

section "Phase 9: Synthese-Pipeline-Lifecycle"

rm -f "$PENDING"

# 9a: Synthese-Worker ohne Lock → erlaubt
run_pipeline_guard "$AGENT_SYNTHESE"
assert "B: Synthese-Worker ohne Lock → erlaubt" "0" "$?"

# 9b: Synthese-Lock anlegen (typ=synthese, gates_total=3)
echo '{"typ":"synthese","stufe":"gates","quelle":"querkraft-synthese","timestamp":"2026-04-11T15:00:00Z","gates_passed":0,"gates_total":3}' > "$PENDING"

# 9c: Ingest-Worker waehrend Synthese → blockiert (cross-block)
ERR_9C=$(echo "$AGENT_INGEST" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_B" 2>&1 >/dev/null)
RC_9C=$?
assert "B: Ingest-Worker waehrend Synthese-Lock → blockiert (cross-block)" "2" "$RC_9C"
assert_contains "B: Cross-Block nennt Synthese-Quelle" "querkraft-synthese" "$ERR_9C"

# 9d: Synthese-Worker waehrend Synthese → blockiert
ERR_9D=$(echo "$AGENT_SYNTHESE" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_B" 2>&1 >/dev/null)
RC_9D=$?
assert "B: Synthese-Worker waehrend Synthese-Lock → blockiert" "2" "$RC_9D"
assert_contains "B: Synthese-Block zeigt Typ" "synthese" "$ERR_9D"

# 9e: 3 Gate-Stops → stufe wechselt zu sideeffects
for G in 1 2 3; do run_advance "$GATE_STOP"; done
STUFE_9E=$(jq -r '.stufe' "$PENDING")
COUNT_9E=$(jq -r '.gates_passed' "$PENDING")
assert "C: 3 Gates bei Synthese → sideeffects" "sideeffects" "$STUFE_9E"
assert "C: Counter bei Synthese = 3" "3" "$COUNT_9E"

# 9f: Warnung zeigt "synthese" als Typ und Gates 3/3
OUT_9F=$(run_lock_warning "$PROMPT_SUBMIT")
assert_contains "D: Warnung zeigt Typ=synthese" "Typ=synthese" "$OUT_9F"
assert_contains "D: Warnung zeigt Gates=3/3" "Gates=3/3" "$OUT_9F"

# 9g: Cleanup → naechster Ingest wieder frei
rm -f "$PENDING"
run_pipeline_guard "$AGENT_INGEST"
assert "B: Ingest-Worker nach Synthese-Cleanup → frei" "0" "$?"
run_pipeline_guard "$AGENT_SYNTHESE"
assert "B: Synthese-Worker nach Cleanup → frei" "0" "$?"

# ============================================================
# PHASE 10: INGEST-ID-Matching
# ============================================================

section "Phase 10: INGEST-ID-Matching"

# 10a: Gate-Stop mit passendem INGEST-ID → Counter steigt
echo '{"typ":"ingest","stufe":"gates","quelle":"test-buch-ec2","timestamp":"2026-04-11T16:00:00Z","gates_passed":0,"gates_total":4}' > "$PENDING"
run_advance "$GATE_STOP_WITH_ID"
COUNT_10A=$(jq -r '.gates_passed' "$PENDING")
assert "C: Gate-Stop mit passendem INGEST-ID → Counter steigt auf 1" "1" "$COUNT_10A"

# 10b: Gate-Stop mit nicht-passendem INGEST-ID → Counter bleibt
run_advance "$GATE_STOP_WRONG_ID"
COUNT_10B=$(jq -r '.gates_passed' "$PENDING")
assert "C: Gate-Stop mit falschem INGEST-ID → Counter bleibt 1" "1" "$COUNT_10B"

# 10c: Gate-Stop ohne INGEST-ID → Counter steigt (Rueckwaertskompatibilitaet)
run_advance "$GATE_STOP"
COUNT_10C=$(jq -r '.gates_passed' "$PENDING")
assert "C: Gate-Stop ohne ID-Marker → Counter steigt auf 2 (Kompatibilitaet)" "2" "$COUNT_10C"

rm -f "$PENDING"

# 10d: SYNTHESE-ID-Matching analog
echo '{"typ":"synthese","stufe":"gates","quelle":"querkraft-synthese","timestamp":"2026-04-11T17:00:00Z","gates_passed":0,"gates_total":3}' > "$PENDING"

# Passende SYNTHESE-ID → zaehlt
run_advance "$GATE_STOP_SYNTHESE_ID"
COUNT_10D1=$(jq -r '.gates_passed' "$PENDING")
assert "C: Gate-Stop mit passendem SYNTHESE-ID → Counter steigt auf 1" "1" "$COUNT_10D1"

# Falsche SYNTHESE-ID → zaehlt nicht
run_advance "$GATE_STOP_SYNTHESE_WRONG"
COUNT_10D2=$(jq -r '.gates_passed' "$PENDING")
assert "C: Gate-Stop mit falschem SYNTHESE-ID → Counter bleibt 1" "1" "$COUNT_10D2"

# Ohne ID → zaehlt (Kompatibilitaet)
run_advance "$GATE_STOP"
COUNT_10D3=$(jq -r '.gates_passed' "$PENDING")
assert "C: Gate-Stop ohne ID bei Synthese → Counter steigt auf 2" "2" "$COUNT_10D3"

rm -f "$PENDING"

# ============================================================
# PHASE 11: Vollstaendiger Lifecycle (End-to-End Replay)
# ============================================================

section "Phase 11: Vollstaendiger Lifecycle — E2E Replay"

# Simuliere: Ingest-Start → Worker → Lock → 4 Gates → Sideeffects → Cleanup → neuer Ingest frei
# Jeder Schritt: ALLE relevanten Hooks pruefen

# Schritt 1: Vor Ingest — System sauber
run_pipeline_guard "$AGENT_INGEST" >/dev/null
S1_B=$?
OUT_S1_D=$(run_lock_warning "$PROMPT_SUBMIT")
assert "E2E-1: Ingest-Worker erlaubt (kein Lock)" "0" "$S1_B"
assert "E2E-1: Keine Warnung (kein Lock)" "" "$OUT_S1_D"

# Schritt 2: Lock anlegen (simuliert Phase 3 des Ingest-Skills)
echo '{"typ":"ingest","stufe":"gates","quelle":"e2e-test-buch","timestamp":"2026-04-11T14:00:00Z","gates_passed":0,"gates_total":4}' > "$PENDING"

# Schritt 3: Sofort pruefen — alles blockiert/warnt
ERR_S3=$(echo "$AGENT_INGEST" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_B" 2>&1 >/dev/null); RC_S3=$?
OUT_S3_D=$(run_lock_warning "$PROMPT_SUBMIT")
assert "E2E-3: Ingest-Worker blockiert" "2" "$RC_S3"
assert_contains "E2E-3: Warnung aktiv" "e2e-test-buch" "$OUT_S3_D"

# Schritt 4: 4 Gate-Agents durchlaufen
for G in 1 2 3 4; do
  run_advance "$GATE_STOP" >/dev/null
done
FINAL_STUFE=$(jq -r '.stufe' "$PENDING")
FINAL_COUNT=$(jq -r '.gates_passed' "$PENDING")
assert "E2E-4: Alle Gates durch → sideeffects" "sideeffects" "$FINAL_STUFE"
assert "E2E-4: Counter = 4" "4" "$FINAL_COUNT"

# Schritt 5: Sideeffects — Ingest noch blockiert
ERR_S5=$(echo "$AGENT_INGEST" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_B" 2>&1 >/dev/null); RC_S5=$?
assert "E2E-5: Ingest-Worker bei sideeffects → blockiert" "2" "$RC_S5"

# Schritt 6: Cleanup (Phase 4 des Ingest-Skills)
rm -f "$PENDING"

# Schritt 7: System wieder frei
run_pipeline_guard "$AGENT_INGEST" >/dev/null; RC_S7=$?
OUT_S7_D=$(run_lock_warning "$PROMPT_SUBMIT")
assert "E2E-7: Ingest-Worker nach Cleanup → frei" "0" "$RC_S7"
assert "E2E-7: Keine Warnung nach Cleanup" "" "$OUT_S7_D"

# ============================================================
# PHASE 12: Auto-Lock nach Worker-Stop (Hook E)
# ============================================================

section "Phase 12: Auto-Lock — create-pipeline-lock.sh"
rm -f "$PENDING"

# 12a: Ingest-Worker-Stop → _pending.json entsteht automatisch
run_create_lock "$WORKER_INGEST_STOP"
assert "E: Ingest-Worker-Stop → exit 0" "0" "$?"
assert "E: _pending.json existiert" "true" "$([ -f "$PENDING" ] && echo true || echo false)"
TYP_12=$(jq -r '.typ' "$PENDING" 2>/dev/null || echo "")
assert "E: typ = ingest" "ingest" "$TYP_12"
QUELLE_12=$(jq -r '.quelle' "$PENDING" 2>/dev/null || echo "")
assert "E: quelle = test-buch-ec2" "test-buch-ec2" "$QUELLE_12"

# 12b: Nach Auto-Lock → guard-pipeline-lock blockiert naechsten Ingest
run_pipeline_guard "$AGENT_INGEST"
assert "B+E: Auto-Lock → naechster Ingest blockiert" "2" "$?"

# 12c: inject-lock-warning zeigt Auto-Lock
OUT_12C=$(run_lock_warning "$PROMPT_SUBMIT")
assert_contains "D+E: Lock-Warning zeigt Auto-Lock-Quelle" "test-buch-ec2" "$OUT_12C"

# 12d: Gate-Advancement funktioniert auf Auto-Lock
for i in 1 2 3 4; do
  GATE_12='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"[INGEST-ID:test-buch-ec2] PASS"}'
  run_advance "$GATE_12"
done
STUFE_12=$(jq -r '.stufe' "$PENDING" 2>/dev/null)
assert "C+E: Auto-Lock → Gates → sideeffects" "sideeffects" "$STUFE_12"
rm -f "$PENDING"

# 12e: Synthese-Worker-Stop → Auto-Lock mit gates_total=3
run_create_lock "$WORKER_SYNTHESE_STOP"
TOTAL_12E=$(jq -r '.gates_total' "$PENDING" 2>/dev/null)
assert "E: Synthese → gates_total=3" "3" "$TOTAL_12E"
TYP_12E=$(jq -r '.typ' "$PENDING" 2>/dev/null)
assert "E: Synthese → typ=synthese" "synthese" "$TYP_12E"
rm -f "$PENDING"

# 12f: Worker-Stop ohne ID-Marker → Lock mit quelle=unbekannt
run_create_lock "$WORKER_INGEST_NO_ID"
QUELLE_12F=$(jq -r '.quelle' "$PENDING" 2>/dev/null)
assert "E: Kein Marker → quelle=unbekannt" "unbekannt" "$QUELLE_12F"
rm -f "$PENDING"

# 12g: Zweiter Worker-Stop → bestehender Lock nicht ueberschrieben
echo '{"typ":"ingest","stufe":"gates","quelle":"erstes-buch","gates_passed":2,"gates_total":4}' > "$PENDING"
run_create_lock "$WORKER_INGEST_STOP"
QUELLE_12G=$(jq -r '.quelle' "$PENDING" 2>/dev/null)
assert "E: Bestehender Lock → nicht ueberschrieben" "erstes-buch" "$QUELLE_12G"
PASSED_12G=$(jq -r '.gates_passed' "$PENDING" 2>/dev/null)
assert "E: Bestehender Counter → unveraendert" "2" "$PASSED_12G"
rm -f "$PENDING"

# 12h: Vollstaendiger Lifecycle mit Auto-Lock
run_create_lock "$WORKER_INGEST_STOP"
assert "E: Lifecycle Start" "true" "$([ -f "$PENDING" ] && echo true || echo false)"
for i in 1 2 3 4; do
  G='{"agent_type":"bibliothek:quellen-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"[INGEST-ID:test-buch-ec2] PASS"}'
  run_advance "$G"
done
STUFE_12H=$(jq -r '.stufe' "$PENDING" 2>/dev/null)
assert "E: Lifecycle → sideeffects" "sideeffects" "$STUFE_12H"
rm -f "$PENDING"
run_pipeline_guard "$AGENT_INGEST"
assert "B: Nach Cleanup → Ingest erlaubt" "0" "$?"

# ============================================================
# Aufraeumen + Ergebnis
# ============================================================

# Cleanup via trap EXIT (oben definiert)

echo ""
echo "╔══════════════════════════════════════════════════════╗"
printf "║  Ergebnis: %2d PASS, %2d FAIL %27s║\n" "$PASS" "$FAIL" ""
echo "╚══════════════════════════════════════════════════════╝"
echo ""

[ "$FAIL" -eq 0 ]
