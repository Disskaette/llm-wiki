#!/usr/bin/env bash
# Tests fuer Check 15 Regex-Fix, Check 19 (Pandoc-Syntax) und Check 20 (Umlaute)
# in check-wiki-output.sh
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
touch "$WIKI_DIR/_konzept-reife.md"
touch "$WIKI_DIR/_schlagwort-vorschlaege.md"

VOKABULAR="$WIKI_DIR/_vokabular.md"
cat > "$VOKABULAR" << 'VOCAB_EOF'
# Kontrolliertes Vokabular

### Stahlbeton
Bewehrter Beton

### Querkraft
Scherkraft

### Verbundtraeger
HBV-Traeger
VOCAB_EOF

# Helper: Basisseite Konzept (alle Pflichtfelder, kein Pandoc, korrekte Umlaute)
make_konzept() {
    local file="$1"
    local body="${2:-Die Querkraft ist eine wesentliche Schnittgröße im Stahlbetonbau.\n\nQuerverweise: [[Stahlbeton]]}"
    cat > "$file" << EOF
---
type: konzept
title: "Querkraft"
schlagworte:
  - Stahlbeton
  - Querkraft
mocs:
  - "[[MOC Tragwerk]]"
quellen-anzahl: 2
created: 2026-04-13
updated: 2026-04-13
synth-datum: 2026-04-13
reviewed: false
---

$(printf "%b" "$body")
EOF
}

# Helper: Basisseite Quellenseite
make_quelle() {
    local file="$1"
    local body="${2:-Inhalt der Quellenseite.}"
    cat > "$file" << EOF
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

$(printf "%b" "$body")
EOF
}

# Wikilink-Ziel anlegen
cat > "$WIKI_DIR/konzepte/stahlbeton.md" << 'EOF'
---
type: konzept
title: "Stahlbeton"
---

# Stahlbeton
EOF

# =====================================================================
echo ""
echo "=== Tests: Check 19 (Pandoc-Syntax) ==="
echo ""

# --- Test C19-1: Pandoc-Zitat auf Konzeptseite → FAIL ---
KONZEPT_PANDOC="$WIKI_DIR/konzepte/querkraft-pandoc.md"
make_konzept "$KONZEPT_PANDOC" "Laut [@mustermann2022] ist Querkraft wichtig.\n\nQuerverweise: [[Stahlbeton]]"

OUT=$(bash "$CHECK_OUTPUT" "$KONZEPT_PANDOC" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC=$?
assert "C19-1: Pandoc auf Konzeptseite → exit 1" "1" "$RC"
assert_contains "C19-1: FAIL 19-kein-pandoc" "FAIL.*19-kein-pandoc" "$OUT"
assert_contains "C19-1: Nennt Pandoc-Zitate" "Pandoc-Zitate" "$OUT"

# --- Test C19-2: Kein Pandoc auf Konzeptseite → PASS ---
KONZEPT_OK="$WIKI_DIR/konzepte/querkraft-ok.md"
make_konzept "$KONZEPT_OK" "Die Querkraft ist eine wesentliche Schnittgröße.\n\nQuerverweise: [[Stahlbeton]]"

OUT=$(bash "$CHECK_OUTPUT" "$KONZEPT_OK" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC=$?
assert_not_contains "C19-2: Kein FAIL 19-kein-pandoc" "FAIL.*19-kein-pandoc" "$OUT"
assert_contains "C19-2: Check 19 PASS" "19-kein-pandoc" "$OUT"

# --- Test C19-3: Pandoc auf Quellenseite → kein FAIL (nur Konzeptseiten betroffen) ---
QUELLE_PANDOC="$WIKI_DIR/quellen/mustermann-pandoc.md"
make_quelle "$QUELLE_PANDOC" "Laut [@mustermann2022] ist Querkraft wichtig."

OUT=$(bash "$CHECK_OUTPUT" "$QUELLE_PANDOC" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC=$?
assert_not_contains "C19-3: Kein FAIL 19 bei Quellenseite" "FAIL.*19-kein-pandoc" "$OUT"
assert_contains "C19-3: Check 19 PASS (nicht erforderlich)" "19-kein-pandoc" "$OUT"

# --- Test C19-4: [WIDERSPRUCH] ist kein False Positive (kein @ Zeichen) ---
KONZEPT_WIDERSPRUCH="$WIKI_DIR/konzepte/querkraft-widerspruch.md"
make_konzept "$KONZEPT_WIDERSPRUCH" "[WIDERSPRUCH: Mustermann 2022 vs. Schmidt 2020]\n\nQuerverweise: [[Stahlbeton]]"

OUT=$(bash "$CHECK_OUTPUT" "$KONZEPT_WIDERSPRUCH" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
assert_not_contains "C19-4: WIDERSPRUCH kein False Positive fuer Pandoc" "FAIL.*19-kein-pandoc" "$OUT"

# --- Test C19-5: Mehrere Pandoc-Zitate → FAIL mit Anzahl ---
KONZEPT_MULTI_PANDOC="$WIKI_DIR/konzepte/querkraft-multi.md"
make_konzept "$KONZEPT_MULTI_PANDOC" "Laut [@mustermann2022] und [@schmidt2020] wichtig.\n\nQuerverweise: [[Stahlbeton]]"

OUT=$(bash "$CHECK_OUTPUT" "$KONZEPT_MULTI_PANDOC" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC=$?
assert "C19-5: Mehrere Pandoc → exit 1" "1" "$RC"
assert_contains "C19-5: FAIL 19-kein-pandoc" "FAIL.*19-kein-pandoc" "$OUT"

# =====================================================================
echo ""
echo "=== Tests: Check 20 (Umlaute im Body) ==="
echo ""

# --- Test C20-1: ASCII-Umlaut 'fuer' im Body → FAIL ---
KONZEPT_UMLAUT="$WIKI_DIR/konzepte/querkraft-umlaut.md"
make_konzept "$KONZEPT_UMLAUT" "Dies ist fuer den Nachweis wichtig.\n\nQuerverweise: [[Stahlbeton]]"

OUT=$(bash "$CHECK_OUTPUT" "$KONZEPT_UMLAUT" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC=$?
assert "C20-1: ASCII-Umlaut 'fuer' → exit 1" "1" "$RC"
assert_contains "C20-1: FAIL 20-umlaute-body" "FAIL.*20-umlaute-body" "$OUT"
assert_contains "C20-1: Nennt 'fuer'" "fuer" "$OUT"

# --- Test C20-2: Korrekte Umlaute → PASS ---
KONZEPT_KORREKT="$WIKI_DIR/konzepte/querkraft-korrekt.md"
make_konzept "$KONZEPT_KORREKT" "Dies ist für den Nachweis wichtig.\n\nQuerverweise: [[Stahlbeton]]"

OUT=$(bash "$CHECK_OUTPUT" "$KONZEPT_KORREKT" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
assert_not_contains "C20-2: Kein FAIL 20 bei korrekten Umlauten" "FAIL.*20-umlaute-body" "$OUT"
assert_contains "C20-2: Check 20 PASS" "20-umlaute-body" "$OUT"

# --- Test C20-3: ASCII-Umlaut nur im Frontmatter → PASS (Body ist sauber) ---
# Frontmatter darf ASCII-Escapes enthalten (YAML-Kompatibilitaet)
cat > "$WIKI_DIR/konzepte/querkraft-fm-only.md" << 'EOF'
---
type: konzept
title: "Pruefung Querkraft"
schlagworte:
  - Stahlbeton
  - Querkraft
reviewed: false
created: 2026-04-13
updated: 2026-04-13
synth-datum: 2026-04-13
quellen-anzahl: 1
---

# Prüfung

Die Querkraft wird für den Nachweis verwendet.

Querverweise: [[Stahlbeton]]
EOF

OUT=$(bash "$CHECK_OUTPUT" "$WIKI_DIR/konzepte/querkraft-fm-only.md" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
assert_not_contains "C20-3: ASCII im Frontmatter kein FAIL" "FAIL.*20-umlaute-body" "$OUT"

# --- Test C20-4: ASCII-Umlaut 'Pruefung' im Body → FAIL ---
KONZEPT_PRUEFUNG="$WIKI_DIR/konzepte/querkraft-pruefung.md"
make_konzept "$KONZEPT_PRUEFUNG" "Die Pruefung erfolgt nach EC2.\n\nQuerverweise: [[Stahlbeton]]"

OUT=$(bash "$CHECK_OUTPUT" "$KONZEPT_PRUEFUNG" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC=$?
assert "C20-4: ASCII-Umlaut 'Pruefung' → exit 1" "1" "$RC"
assert_contains "C20-4: FAIL 20-umlaute-body" "FAIL.*20-umlaute-body" "$OUT"

# --- Test C20-5: Quelle-Seite mit ASCII-Umlaut → FAIL (gilt fuer alle Typen) ---
QUELLE_UMLAUT="$WIKI_DIR/quellen/mustermann-umlaut.md"
make_quelle "$QUELLE_UMLAUT" "Dies ist fuer den Nachweis wichtig."

OUT=$(bash "$CHECK_OUTPUT" "$QUELLE_UMLAUT" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC=$?
assert "C20-5: ASCII-Umlaut auf Quellenseite → exit 1" "1" "$RC"
assert_contains "C20-5: FAIL 20-umlaute-body" "FAIL.*20-umlaute-body" "$OUT"

# =====================================================================
echo ""
echo "=== Tests: Check 15 (WIDERSPRUCH-Marker Regex-Fix) ==="
echo ""

# --- Test C15-1: ISB 2013 matched jetzt (Abkuerzung ohne Kleinbuchstaben) ---
KONZEPT_ISB="$WIKI_DIR/konzepte/isb-check.md"
make_konzept "$KONZEPT_ISB" "[WIDERSPRUCH: ISB 2013 widerspricht ISB 2018 hinsichtlich Mindestbewehrung]\n\nQuerverweise: [[Stahlbeton]]"

OUT=$(bash "$CHECK_OUTPUT" "$KONZEPT_ISB" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
assert_not_contains "C15-1: ISB 2013 kein FAIL 15" "FAIL.*15-widerspruch-marker" "$OUT"

# --- Test C15-2: CEN/TS matched (Slash im Autorennamen) ---
KONZEPT_CENTS="$WIKI_DIR/konzepte/cents-check.md"
make_konzept "$KONZEPT_CENTS" "[WIDERSPRUCH: CEN/TS 2019 widerspricht CEN/TS 2023 bei Klassifizierung]\n\nQuerverweise: [[Stahlbeton]]"

OUT=$(bash "$CHECK_OUTPUT" "$KONZEPT_CENTS" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
assert_not_contains "C15-2: CEN/TS kein FAIL 15" "FAIL.*15-widerspruch-marker" "$OUT"

# --- Test C15-3: Zilch/Zehetmaier matched (Slash + gemischter Name) ---
KONZEPT_ZILCH="$WIKI_DIR/konzepte/zilch-check.md"
make_konzept "$KONZEPT_ZILCH" "[WIDERSPRUCH: Zilch/Zehetmaier 2010 widerspricht Zilch/Zehetmaier 2018 bei Biegebemessung]\n\nQuerverweise: [[Stahlbeton]]"

OUT=$(bash "$CHECK_OUTPUT" "$KONZEPT_ZILCH" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
assert_not_contains "C15-3: Zilch/Zehetmaier kein FAIL 15" "FAIL.*15-widerspruch-marker" "$OUT"

# --- Test C15-4: Vollstaendig unvollstaendiger WIDERSPRUCH → FAIL (Kontrolle) ---
KONZEPT_WIDERSPRUCH_FAIL="$WIKI_DIR/konzepte/widerspruch-fail.md"
make_konzept "$KONZEPT_WIDERSPRUCH_FAIL" "[WIDERSPRUCH]\n\nQuerverweise: [[Stahlbeton]]"

OUT=$(bash "$CHECK_OUTPUT" "$KONZEPT_WIDERSPRUCH_FAIL" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
RC=$?
assert "C15-4: Leerer WIDERSPRUCH → exit 1" "1" "$RC"
assert_contains "C15-4: FAIL 15-widerspruch-marker" "FAIL.*15-widerspruch-marker" "$OUT"

# --- Test C15-5: Quelle A/B Format weiterhin erlaubt ---
KONZEPT_QUELLE_AB="$WIKI_DIR/konzepte/quelleab-check.md"
make_konzept "$KONZEPT_QUELLE_AB" "[WIDERSPRUCH: Quelle A vs. Quelle B bei Mindestbewehrung]\n\nQuerverweise: [[Stahlbeton]]"

OUT=$(bash "$CHECK_OUTPUT" "$KONZEPT_QUELLE_AB" "$VOKABULAR" "$WIKI_DIR/" 2>&1)
assert_not_contains "C15-5: Quelle A/B kein FAIL 15" "FAIL.*15-widerspruch-marker" "$OUT"

# =====================================================================
# --- Cleanup ---
rm -rf "$SANDBOX"

echo ""
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
