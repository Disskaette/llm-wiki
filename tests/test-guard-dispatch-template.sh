#!/usr/bin/env bash
# Tests fuer guard-dispatch-template.sh
set -euo pipefail

SCRIPT="plugin/hooks/guard-dispatch-template.sh"
PASS=0; FAIL=0; TOTAL=0

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

run_test() {
    local name="$1" input="$2" expected_exit="$3"
    TOTAL=$((TOTAL + 1))
    local actual_exit=0
    echo "$input" | bash "$SCRIPT" >/dev/null 2>&1 || actual_exit=$?
    if [ "$actual_exit" -eq "$expected_exit" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (expected exit $expected_exit, got $actual_exit)"
        FAIL=$((FAIL + 1))
    fi
}

# Transcript mit Template-Read
TRANSCRIPT_WITH="$TMPDIR/transcript_with.txt"
echo '{"role":"assistant","content":"Read governance/synthese-dispatch-template.md"}' > "$TRANSCRIPT_WITH"

# Transcript ohne Template-Read
TRANSCRIPT_WITHOUT="$TMPDIR/transcript_without.txt"
echo '{"role":"assistant","content":"Lets dispatch the worker"}' > "$TRANSCRIPT_WITHOUT"

# Test 1: Nicht-Worker-Agent → durchlassen (exit 0)
run_test "non-worker-agent" \
  "{\"tool_input\":{\"subagent_type\":\"bibliothek:quellen-pruefer\"},\"transcript_path\":\"$TRANSCRIPT_WITHOUT\"}" 0

# Test 2: Synthese-Worker mit Template gelesen → durchlassen (exit 0)
run_test "synthese-worker-template-read" \
  "{\"tool_input\":{\"subagent_type\":\"bibliothek:synthese-worker\"},\"transcript_path\":\"$TRANSCRIPT_WITH\"}" 0

# Test 3: Synthese-Worker ohne Template → blockieren (exit 2)
run_test "synthese-worker-no-template" \
  "{\"tool_input\":{\"subagent_type\":\"bibliothek:synthese-worker\"},\"transcript_path\":\"$TRANSCRIPT_WITHOUT\"}" 2

# Test 4: Ingest-Worker mit passendem Template → durchlassen (exit 0)
TRANSCRIPT_INGEST="$TMPDIR/transcript_ingest.txt"
echo '{"role":"assistant","content":"Read governance/ingest-dispatch-template.md"}' > "$TRANSCRIPT_INGEST"
run_test "ingest-worker-template-read" \
  "{\"tool_input\":{\"subagent_type\":\"bibliothek:ingest-worker\"},\"transcript_path\":\"$TRANSCRIPT_INGEST\"}" 0

# Test 5: Ingest-Worker mit FALSCHEM Template → blockieren
run_test "ingest-worker-wrong-template" \
  "{\"tool_input\":{\"subagent_type\":\"bibliothek:ingest-worker\"},\"transcript_path\":\"$TRANSCRIPT_WITH\"}" 2

# Test 6: Zuordnung-Worker ohne Template → blockieren (exit 2)
run_test "zuordnung-worker-no-template" \
  "{\"tool_input\":{\"subagent_type\":\"bibliothek:zuordnung-worker\"},\"transcript_path\":\"$TRANSCRIPT_WITHOUT\"}" 2

# Test 7: Zuordnung-Worker mit Template → durchlassen
TRANSCRIPT_ZUORDNUNG="$TMPDIR/transcript_zuordnung.txt"
echo '{"role":"assistant","content":"Read governance/zuordnung-dispatch-template.md"}' > "$TRANSCRIPT_ZUORDNUNG"
run_test "zuordnung-worker-template-read" \
  "{\"tool_input\":{\"subagent_type\":\"bibliothek:zuordnung-worker\"},\"transcript_path\":\"$TRANSCRIPT_ZUORDNUNG\"}" 0

# Test 8: Kein subagent_type → durchlassen (exit 0)
run_test "no-subagent-type" \
  "{\"tool_input\":{},\"transcript_path\":\"$TRANSCRIPT_WITHOUT\"}" 0

# Test 9: Kein Transcript → blockieren (exit 2)
run_test "no-transcript" \
  "{\"tool_input\":{\"subagent_type\":\"bibliothek:synthese-worker\"}}" 2

# Test 10: Leerer subagent_type → durchlassen (exit 0)
run_test "empty-subagent-type" \
  "{\"tool_input\":{\"subagent_type\":\"\"},\"transcript_path\":\"$TRANSCRIPT_WITHOUT\"}" 0

echo ""
echo "=== Ergebnis: $PASS/$TOTAL PASS, $FAIL FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
