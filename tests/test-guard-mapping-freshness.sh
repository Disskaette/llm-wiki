#!/usr/bin/env bash
# Tests fuer guard-mapping-freshness.sh
set -euo pipefail

SCRIPT="plugin/hooks/guard-mapping-freshness.sh"
PASS=0; FAIL=0; TOTAL=0

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Override PROJECT_DIR for tests
export CLAUDE_PROJECT_DIR="$TMPDIR"

run_test() {
    local name="$1" expected_exit="$2"
    TOTAL=$((TOTAL + 1))
    local actual_exit=0
    echo "$INPUT_JSON" | bash "$SCRIPT" >/dev/null 2>&1 || actual_exit=$?
    if [ "$actual_exit" -eq "$expected_exit" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (expected exit $expected_exit, got $actual_exit)"
        FAIL=$((FAIL + 1))
    fi
}

# Input JSON templates
SYNTHESE_INPUT='{"tool_input":{"subagent_type":"bibliothek:synthese-worker"}}'
INGEST_INPUT='{"tool_input":{"subagent_type":"bibliothek:ingest-worker"}}'
ZUORDNUNG_INPUT='{"tool_input":{"subagent_type":"bibliothek:zuordnung-worker"}}'

create_mapping() {
    local quellen_stand="$1" konzepte_stand="$2"
    mkdir -p "$TMPDIR/wiki"
    cat > "$TMPDIR/wiki/_quellen-mapping.md" << EOF
---
type: meta
quellen-stand: $quellen_stand
konzepte-stand: $konzepte_stand
---
# Mapping
EOF
}

create_quellen() {
    local count="$1"
    mkdir -p "$TMPDIR/wiki/quellen"
    rm -f "$TMPDIR/wiki/quellen/"*.md
    for i in $(seq 1 "$count"); do
        touch "$TMPDIR/wiki/quellen/q$i.md"
    done
}

create_konzepte() {
    local count="$1"
    mkdir -p "$TMPDIR/wiki/konzepte"
    rm -f "$TMPDIR/wiki/konzepte/"*.md
    for i in $(seq 1 "$count"); do
        touch "$TMPDIR/wiki/konzepte/k$i.md"
    done
}

reset_wiki() {
    rm -rf "$TMPDIR/wiki"
}

# Test 1: Nicht-Synthese-Worker → durchlassen
reset_wiki
INPUT_JSON="$INGEST_INPUT"
run_test "non-synthese-worker-passthrough" 0

# Test 2: Kein wiki/ → durchlassen
reset_wiki
INPUT_JSON="$SYNTHESE_INPUT"
run_test "no-wiki-dir-passthrough" 0

# Test 3: Kein _quellen-mapping.md → blockieren
mkdir -p "$TMPDIR/wiki"
INPUT_JSON="$SYNTHESE_INPUT"
run_test "no-mapping-file-blocks" 2

# Test 4: Mapping aktuell (gleiche Zahlen) → durchlassen
create_mapping 3 2
create_quellen 3
create_konzepte 2
INPUT_JSON="$SYNTHESE_INPUT"
run_test "mapping-current-passthrough" 0

# Test 5: Neue Quelle seit Mapping → blockieren
create_mapping 3 2
create_quellen 4
create_konzepte 2
INPUT_JSON="$SYNTHESE_INPUT"
run_test "new-source-blocks" 2

# Test 6: Neues Konzept seit Mapping → blockieren
create_mapping 3 2
create_quellen 3
create_konzepte 3
INPUT_JSON="$SYNTHESE_INPUT"
run_test "new-concept-blocks" 2

# Test 7: Beides neu → blockieren
create_mapping 3 2
create_quellen 5
create_konzepte 4
INPUT_JSON="$SYNTHESE_INPUT"
run_test "both-new-blocks" 2

# Test 8: Ingest-Worker → durchlassen (nur Synthese wird blockiert)
create_mapping 3 2
create_quellen 5
create_konzepte 4
INPUT_JSON="$INGEST_INPUT"
run_test "ingest-worker-passthrough" 0

# Test 9: Zuordnung-Worker → durchlassen
INPUT_JSON="$ZUORDNUNG_INPUT"
run_test "zuordnung-worker-passthrough" 0

# Test 10: Leeres quellen/ → durchlassen (0 == 0)
reset_wiki
create_mapping 0 0
mkdir -p "$TMPDIR/wiki/quellen"
mkdir -p "$TMPDIR/wiki/konzepte"
INPUT_JSON="$SYNTHESE_INPUT"
run_test "empty-dirs-passthrough" 0

echo ""
echo "=== Ergebnis: $PASS/$TOTAL PASS, $FAIL FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
