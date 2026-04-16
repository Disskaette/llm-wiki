#!/usr/bin/env bash
# Tests fuer check-zuordnung-output.sh
set -euo pipefail

SCRIPT="plugin/hooks/check-zuordnung-output.sh"
PASS=0; FAIL=0; TOTAL=0

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

run_test() {
    local name="$1" expected_exit="$2"
    TOTAL=$((TOTAL + 1))
    local actual_exit=0
    bash "$SCRIPT" "$TMPDIR/wiki" >/dev/null 2>&1 || actual_exit=$?
    if [ "$actual_exit" -eq "$expected_exit" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (expected exit $expected_exit, got $actual_exit)"
        FAIL=$((FAIL + 1))
    fi
}

reset_wiki() {
    rm -rf "$TMPDIR/wiki"
    mkdir -p "$TMPDIR/wiki/quellen" "$TMPDIR/wiki/konzepte"
}

create_mapping() {
    local quellen_stand="$1" konzepte_stand="$2" body="$3"
    cat > "$TMPDIR/wiki/_quellen-mapping.md" << EOF
---
type: meta
title: "Quellen-Zuordnung"
updated: 2026-04-16
mapping-version: 1
quellen-stand: $quellen_stand
konzepte-stand: $konzepte_stand
kandidaten-stand: 0
letzter-log-hash: "test"
---

# Quellen-Zuordnung

$body
EOF
}

create_quelle() {
    local name="$1" relevant_fuer="${2:-}"
    local content="---\ntype: quelle\ntitel: Test $name\nschlagworte: [Test]"
    if [ -n "$relevant_fuer" ]; then
        content="${content}\nrelevant-fuer: [$relevant_fuer]"
    fi
    content="${content}\n---\n\n## Zusammenfassung\nTest-Quelle $name"
    printf '%b' "$content" > "$TMPDIR/wiki/quellen/${name}.md"
}

create_konzept() {
    local name="$1"
    cat > "$TMPDIR/wiki/konzepte/${name}.md" << EOF
---
type: konzept
title: $name
---

## Zusammenfassung
Test-Konzept $name
EOF
}

create_vokabular() {
    cat > "$TMPDIR/wiki/_vokabular.md" << EOF
# Vokabular

### Querkraft
- Transversalkraft

### Biegung
EOF
}

echo "=== Tests: check-zuordnung-output.sh ==="
echo ""

# --- Test 1: Kein Mapping → FAIL ---
reset_wiki
run_test "01-kein-mapping" 1

# --- Test 2: Vollstaendiges Mapping, alles korrekt → PASS ---
reset_wiki
create_quelle "quelle-a" "konzept-x"
create_quelle "quelle-b" "konzept-x"
create_konzept "konzept-x"
create_vokabular
MATRIX="## Zuordnungs-Matrix

| Quelle | Konzepte | Kandidaten | Begruendung |
|--------|----------|------------|-------------|
| [[quelle-a]] | [[konzept-x]] | — | Test |
| [[quelle-b]] | [[konzept-x]] | — | Test |"
create_mapping 2 1 "$MATRIX"
run_test "02-alles-korrekt" 0

# --- Test 3: quellen-stand falsch → FAIL ---
reset_wiki
create_quelle "quelle-a" "konzept-x"
create_quelle "quelle-b" "konzept-x"
create_konzept "konzept-x"
create_vokabular
create_mapping 3 1 "$MATRIX"
run_test "03-quellen-stand-falsch" 1

# --- Test 4: konzepte-stand falsch → FAIL ---
reset_wiki
create_quelle "quelle-a" "konzept-x"
create_quelle "quelle-b" "konzept-x"
create_konzept "konzept-x"
create_vokabular
create_mapping 2 5 "$MATRIX"
run_test "04-konzepte-stand-falsch" 1

# --- Test 5: Orphan-Quelle (Datei existiert, nicht in Matrix) → FAIL ---
reset_wiki
create_quelle "quelle-a" "konzept-x"
create_quelle "quelle-b" "konzept-x"
create_quelle "quelle-c" ""
create_konzept "konzept-x"
create_vokabular
# Matrix hat nur a und b, nicht c
create_mapping 3 1 "$MATRIX"
run_test "05-orphan-quelle" 1

# --- Test 6: _-Prefix-Dateien werden ignoriert ---
reset_wiki
create_quelle "quelle-a" "konzept-x"
create_konzept "konzept-x"
create_vokabular
printf '%b' "---\ntype: meta\n---\nIndex" > "$TMPDIR/wiki/quellen/_index.md"
MATRIX_SINGLE="## Zuordnungs-Matrix

| Quelle | Konzepte | Kandidaten | Begruendung |
|--------|----------|------------|-------------|
| [[quelle-a]] | [[konzept-x]] | — | Test |"
create_mapping 1 1 "$MATRIX_SINGLE"
run_test "06-underscore-prefix-ignoriert" 0

# --- Test 7: Fehlende Frontmatter-Felder → FAIL ---
reset_wiki
create_vokabular
cat > "$TMPDIR/wiki/_quellen-mapping.md" << 'EOF'
---
type: meta
title: "Test"
---

# Mapping
EOF
run_test "07-fehlende-frontmatter-felder" 1

# --- Test 8: Quelle in Matrix ohne relevant-fuer: → FAIL ---
reset_wiki
create_quelle "quelle-a" ""
create_konzept "konzept-x"
create_vokabular
create_mapping 1 1 "$MATRIX_SINGLE"
run_test "08-fehlende-rueckverweise" 1

# --- Test 9: Leere Matrix → FAIL ---
reset_wiki
create_vokabular
EMPTY_BODY="## Zuordnungs-Matrix

| Quelle | Konzepte | Kandidaten | Begruendung |
|--------|----------|------------|-------------|"
create_mapping 0 0 "$EMPTY_BODY"
run_test "09-leere-matrix" 1

# --- Test 10: Nicht zugeordnete Quelle korrekt gelistet → PASS ---
reset_wiki
create_quelle "quelle-a" "konzept-x"
create_quelle "quelle-b" ""
create_konzept "konzept-x"
create_vokabular
MATRIX_WITH_UNASSIGNED="## Zuordnungs-Matrix

| Quelle | Konzepte | Kandidaten | Begruendung |
|--------|----------|------------|-------------|
| [[quelle-a]] | [[konzept-x]] | — | Test |

## Nicht zugeordnete Quellen

- [[quelle-b]] — Thematisch ausserhalb"
# quelle-b hat kein relevant-fuer aber ist als "nicht zugeordnet" korrekt
# Allerdings Check 6 prueft nur Matrix-Quellen, nicht die nicht-zugeordneten
create_mapping 2 1 "$MATRIX_WITH_UNASSIGNED"
run_test "10-nicht-zugeordnet-korrekt" 0

# --- Test 11: Off-by-one Schutz (quellen-stand 94 statt 93) ---
reset_wiki
for i in $(seq 1 5); do
    create_quelle "quelle-$i" "konzept-x"
done
create_konzept "konzept-x"
create_vokabular
MATRIX_5="## Zuordnungs-Matrix

| Quelle | Konzepte | Kandidaten | Begruendung |
|--------|----------|------------|-------------|
| [[quelle-1]] | [[konzept-x]] | — | Test |
| [[quelle-2]] | [[konzept-x]] | — | Test |
| [[quelle-3]] | [[konzept-x]] | — | Test |
| [[quelle-4]] | [[konzept-x]] | — | Test |
| [[quelle-5]] | [[konzept-x]] | — | Test |"
create_mapping 6 1 "$MATRIX_5"
run_test "11-off-by-one-stand" 1

# --- Test 12: Korrekter Stand bei 5 Quellen ---
reset_wiki
for i in $(seq 1 5); do
    create_quelle "quelle-$i" "konzept-x"
done
create_konzept "konzept-x"
create_vokabular
create_mapping 5 1 "$MATRIX_5"
run_test "12-korrekter-stand-5" 0

echo ""
echo "=== Ergebnis: $PASS/$TOTAL PASS, $FAIL FAIL ==="
[ "$FAIL" -eq 0 ] || exit 1
