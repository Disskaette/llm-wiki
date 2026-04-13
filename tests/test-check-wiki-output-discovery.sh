#!/usr/bin/env bash
# Tests fuer Check 18 (Discovery-Dateien) in check-wiki-output.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK_OUTPUT="$SCRIPT_DIR/../plugin/hooks/check-wiki-output.sh"

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

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q "$needle" 2>/dev/null; then
    echo "  PASS: $name"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $name — '$needle' nicht in Output"
    FAIL=$((FAIL+1))
  fi
}

assert_not_contains() {
  local name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q "$needle" 2>/dev/null; then
    echo "  FAIL: $name — '$needle' unerwartet in Output"
    FAIL=$((FAIL+1))
  else
    echo "  PASS: $name"
    PASS=$((PASS+1))
  fi
}

# --- Setup ---
SANDBOX=$(mktemp -d)
WIKI_DIR="$SANDBOX/wiki"
mkdir -p "$WIKI_DIR/konzepte" "$WIKI_DIR/quellen"

# Vokabular with matching terms
VOKABULAR="$WIKI_DIR/_vokabular.md"
cat > "$VOKABULAR" << 'VOCAB_EOF'
# Kontrolliertes Vokabular

### Stahlbeton
Bewehrter Beton

### Querkraft
Scherkraft
VOCAB_EOF

echo ""
echo "=== Tests: Check 18 (Discovery-Dateien) ==="
echo ""

# --- Test 1: Konzeptseite + beide Discovery-Dateien vorhanden → PASS ---
KONZEPT_OK="$WIKI_DIR/konzepte/querkraft.md"
cat > "$KONZEPT_OK" << 'EOF'
---
type: konzept
title: "Querkraft"
synonyme:
  - Scherkraft
schlagworte:
  - Stahlbeton
  - Querkraft
materialgruppe: Beton
versagensart: Schub
mocs:
  - "[[MOC Tragwerk]]"
quellen-anzahl: 2
created: 2026-04-13
updated: 2026-04-13
synth-datum: 2026-04-13
reviewed: false
---

# Querkraft

Die Querkraft ist eine wesentliche Schnittgroesse im Stahlbetonbau.

Querverweise: [[Stahlbeton]]
EOF

touch "$WIKI_DIR/_konzept-reife.md"
touch "$WIKI_DIR/_schlagwort-vorschlaege.md"
# Create wikilink target
cat > "$WIKI_DIR/konzepte/stahlbeton.md" << 'EOF'
---
type: konzept
title: "Stahlbeton"
---

# Stahlbeton
EOF

OUT_1=$(bash "$CHECK_OUTPUT" "$KONZEPT_OK" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC_1=$?
assert "Test 1: Konzeptseite + beide Discovery-Dateien → exit 0" "0" "$RC_1"
assert_contains "Test 1: Check 18 PASS" "18-discovery-dateien" "$OUT_1"
assert_not_contains "Test 1: Kein FAIL bei Check 18" "FAIL.*18-discovery-dateien" "$OUT_1"

# --- Test 2: Konzeptseite + Discovery-Dateien fehlen → FAIL ---
rm -f "$WIKI_DIR/_konzept-reife.md" "$WIKI_DIR/_schlagwort-vorschlaege.md"

OUT_2=$(bash "$CHECK_OUTPUT" "$KONZEPT_OK" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC_2=$?
assert "Test 2: Konzeptseite ohne Discovery-Dateien → exit 1" "1" "$RC_2"
assert_contains "Test 2: Check 18 FAIL" "FAIL.*18-discovery-dateien" "$OUT_2"
assert_contains "Test 2: Nennt _konzept-reife.md" "_konzept-reife.md" "$OUT_2"
assert_contains "Test 2: Nennt _schlagwort-vorschlaege.md" "_schlagwort-vorschlaege.md" "$OUT_2"

# --- Test 3: Konzeptseite + nur _konzept-reife.md → FAIL (beide muessen existieren) ---
touch "$WIKI_DIR/_konzept-reife.md"
rm -f "$WIKI_DIR/_schlagwort-vorschlaege.md"

OUT_3=$(bash "$CHECK_OUTPUT" "$KONZEPT_OK" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC_3=$?
assert "Test 3: Nur _konzept-reife.md → exit 1" "1" "$RC_3"
assert_contains "Test 3: Check 18 FAIL" "FAIL.*18-discovery-dateien" "$OUT_3"
assert_contains "Test 3: Nennt _schlagwort-vorschlaege.md" "_schlagwort-vorschlaege.md" "$OUT_3"
assert_not_contains "Test 3: Nennt NICHT _konzept-reife.md" "_konzept-reife.md.*," "$OUT_3"

# --- Test 4: Quellenseite → Check 18 skipped (nicht erforderlich) → PASS ---
touch "$WIKI_DIR/_konzept-reife.md"
touch "$WIKI_DIR/_schlagwort-vorschlaege.md"
QUELLE_PAGE="$WIKI_DIR/quellen/mustermann-2022.md"
cat > "$QUELLE_PAGE" << 'EOF'
---
type: quelle
title: "Stahlbetonbau nach EC2"
autor: Mustermann
jahr: 2022
verlag: Springer
seiten: 450
kategorie: Fachbuch
verarbeitung: vollstaendig
pdf: quellen-pdfs/mustermann-2022.pdf
reviewed: false
ingest-datum: 2026-04-13
schlagworte:
  - Stahlbeton
kapitel-index:
  - "1. Grundlagen"
---

# Stahlbetonbau nach EC2
EOF

OUT_4=$(bash "$CHECK_OUTPUT" "$QUELLE_PAGE" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC_4=$?
assert "Test 4: Quellenseite → exit 0" "0" "$RC_4"
assert_contains "Test 4: Check 18 PASS (skipped)" "18-discovery-dateien" "$OUT_4"
assert_not_contains "Test 4: Kein FAIL bei Check 18 fuer Quellenseite" "FAIL.*18-discovery-dateien" "$OUT_4"

# --- Test 5: Konzeptseite + leere Discovery-Dateien → PASS (Existenz reicht) ---
rm -f "$WIKI_DIR/_konzept-reife.md" "$WIKI_DIR/_schlagwort-vorschlaege.md"
: > "$WIKI_DIR/_konzept-reife.md"
: > "$WIKI_DIR/_schlagwort-vorschlaege.md"

OUT_5=$(bash "$CHECK_OUTPUT" "$KONZEPT_OK" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC_5=$?
assert "Test 5: Leere Discovery-Dateien → exit 0" "0" "$RC_5"
assert_contains "Test 5: Check 18 PASS" "18-discovery-dateien" "$OUT_5"
assert_not_contains "Test 5: Kein FAIL bei Check 18" "FAIL.*18-discovery-dateien" "$OUT_5"

# --- Cleanup ---
rm -rf "$SANDBOX"

echo ""
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
