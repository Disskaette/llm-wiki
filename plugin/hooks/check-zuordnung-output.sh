#!/usr/bin/env bash
# check-zuordnung-output.sh — Deterministische Checks fuer Zuordnungs-Output
# Aufruf: ./check-zuordnung-output.sh <wiki-verzeichnis>
#
# Prueft _quellen-mapping.md nach Worker-Rueckkehr:
#   1. Datei-Existenz + Frontmatter
#   2. Orphan-Erkennung (Quellen ohne Matrix-Eintrag)
#   3. Zaehler-Konsistenz (quellen-stand == tatsaechliche Dateien)
#   4. Rueckverweis-Konsistenz (relevant-fuer: ↔ Mapping)
#   5. Vokabular-Check (gepatchte Schlagworte im Vokabular?)
#
# Exit 0 = nur PASS/WARN
# Exit 1 = mindestens ein FAIL

set -euo pipefail

WIKI_DIR="${1:?Nutzung: check-zuordnung-output.sh <wiki-verzeichnis>}"
MAPPING="${WIKI_DIR}/_quellen-mapping.md"
VOKABULAR="${WIKI_DIR}/_vokabular.md"

PASS=0; FAIL=0; WARN=0

check() {
    local status="$1" name="$2" detail="$3"
    case "$status" in
        PASS) echo "  ✅ Check $name"; PASS=$((PASS + 1)) ;;
        FAIL) echo "  ❌ FAIL: $name — $detail"; FAIL=$((FAIL + 1)) ;;
        WARN) echo "  ⚠️  WARN: $name — $detail"; WARN=$((WARN + 1)) ;;
    esac
}

echo "=== Zuordnung-Output-Pruefung: ${WIKI_DIR} ==="

# --- Check 1: _quellen-mapping.md existiert ---
if [ ! -f "$MAPPING" ]; then
    check FAIL "01-mapping-existiert" "_quellen-mapping.md nicht gefunden"
    echo ""
    echo "=== Ergebnis: $PASS PASS, $FAIL FAIL, $WARN WARN ==="
    exit 1
fi
check PASS "01-mapping-existiert" ""

# --- Check 2: Frontmatter-Pflichtfelder ---
FM=$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$MAPPING")
MISSING_FIELDS=""
for field in type title updated mapping-version quellen-stand konzepte-stand; do
    if ! echo "$FM" | grep -q "^${field}:"; then
        MISSING_FIELDS="${MISSING_FIELDS}${field}, "
    fi
done
if [ -n "$MISSING_FIELDS" ]; then
    check FAIL "02-frontmatter-felder" "Fehlende Felder: ${MISSING_FIELDS%, }"
else
    check PASS "02-frontmatter-felder" ""
fi

# --- Check 3: quellen-stand == tatsaechliche Dateien ---
QUELLEN_STAND=$(echo "$FM" | awk '/^quellen-stand:/{gsub(/^quellen-stand: */,""); print; exit}')
QUELLEN_STAND="${QUELLEN_STAND:-0}"
# Zaehle nur .md-Dateien ohne _-Prefix
QUELLEN_DATEIEN=0
if [ -d "${WIKI_DIR}/quellen" ]; then
    for f in "${WIKI_DIR}"/quellen/*.md; do
        [ -f "$f" ] || continue
        bname=$(basename "$f")
        [[ "$bname" == _* ]] && continue
        QUELLEN_DATEIEN=$((QUELLEN_DATEIEN + 1))
    done
fi
if [ "$QUELLEN_STAND" -ne "$QUELLEN_DATEIEN" ]; then
    check FAIL "03-quellen-stand" "quellen-stand: $QUELLEN_STAND, tatsaechlich: $QUELLEN_DATEIEN"
else
    check PASS "03-quellen-stand" ""
fi

# --- Check 4: konzepte-stand == tatsaechliche Dateien ---
KONZEPTE_STAND=$(echo "$FM" | awk '/^konzepte-stand:/{gsub(/^konzepte-stand: */,""); print; exit}')
KONZEPTE_STAND="${KONZEPTE_STAND:-0}"
KONZEPTE_DATEIEN=0
if [ -d "${WIKI_DIR}/konzepte" ]; then
    for f in "${WIKI_DIR}"/konzepte/*.md; do
        [ -f "$f" ] || continue
        bname=$(basename "$f")
        [[ "$bname" == _* ]] && continue
        KONZEPTE_DATEIEN=$((KONZEPTE_DATEIEN + 1))
    done
fi
if [ "$KONZEPTE_STAND" -ne "$KONZEPTE_DATEIEN" ]; then
    check FAIL "04-konzepte-stand" "konzepte-stand: $KONZEPTE_STAND, tatsaechlich: $KONZEPTE_DATEIEN"
else
    check PASS "04-konzepte-stand" ""
fi

# --- Check 5: Orphan-Erkennung (Quellen ohne Matrix-Eintrag) ---
BODY=$(awk '/^---$/{n++; next} n>=2{print}' "$MAPPING")
ORPHANS=""
if [ -d "${WIKI_DIR}/quellen" ]; then
    for f in "${WIKI_DIR}"/quellen/*.md; do
        [ -f "$f" ] || continue
        bname=$(basename "$f" .md)
        [[ "$bname" == _* ]] && continue
        if ! echo "$BODY" | grep -q "\[\[${bname}\]\]"; then
            ORPHANS="${ORPHANS}${bname}, "
        fi
    done
fi
if [ -n "$ORPHANS" ]; then
    check FAIL "05-orphan-quellen" "Quellen nicht im Mapping: ${ORPHANS%, }"
else
    check PASS "05-orphan-quellen" ""
fi

# --- Check 6: Rueckverweis-Konsistenz (Stichprobe) ---
# Fuer jede Quelle in der Matrix: hat die Quelldatei relevant-fuer: im Frontmatter?
MISSING_RELVFUER=""
CHECKED=0
MISSING_COUNT=0
if [ -d "${WIKI_DIR}/quellen" ]; then
    # Extrahiere Quellen aus der Matrix (erste Spalte mit [[key]])
    MATRIX_KEYS=$(echo "$BODY" | grep -oE '^\| \[\[[a-z_0-9-]+\]\]' | sed 's/| \[\[//;s/\]\]//' | head -200)
    for key in $MATRIX_KEYS; do
        qfile="${WIKI_DIR}/quellen/${key}.md"
        [ -f "$qfile" ] || continue
        CHECKED=$((CHECKED + 1))
        QFM=$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$qfile")
        if ! echo "$QFM" | grep -q "^relevant-fuer:"; then
            MISSING_COUNT=$((MISSING_COUNT + 1))
            # Nur erste 5 melden
            if [ "$MISSING_COUNT" -le 5 ]; then
                MISSING_RELVFUER="${MISSING_RELVFUER}${key}, "
            fi
        fi
    done
fi
if [ "$MISSING_COUNT" -gt 0 ]; then
    DETAIL="$MISSING_COUNT von $CHECKED Quellen ohne relevant-fuer:"
    if [ "$MISSING_COUNT" -gt 5 ]; then
        DETAIL="${DETAIL} (erste 5: ${MISSING_RELVFUER%, })"
    else
        DETAIL="${DETAIL} (${MISSING_RELVFUER%, })"
    fi
    check FAIL "06-rueckverweis" "$DETAIL"
else
    if [ "$CHECKED" -gt 0 ]; then
        check PASS "06-rueckverweis" "($CHECKED Quellen geprueft)"
    else
        check WARN "06-rueckverweis" "Keine Quellen in Matrix gefunden"
    fi
fi

# --- Check 7: Vokabular-Check (gepatchte Schlagworte) ---
# Pruefe ob die im Schlagwort-Audit vorgeschlagenen Patches im Vokabular sind
if [ -f "$VOKABULAR" ]; then
    # Extrahiere gepatchte Terme aus der Audit-Tabelle
    AUDIT_SECTION=$(echo "$BODY" | awk '/^### Fehlende Zuordnungen/{found=1; next} /^###? /{if(found) exit} found{print}')
    if [ -n "$AUDIT_SECTION" ]; then
        # Spalte 2 der Tabelle = Schlagwort
        PATCH_TERMS=$(echo "$AUDIT_SECTION" | grep '^|' | grep -v '^| Quelle\|^|---' | awk -F'|' '{gsub(/^ +| +$/,"",$3); print $3}')
        INVALID_TERMS=""
        for term in $PATCH_TERMS; do
            [ -z "$term" ] && continue
            if ! grep -qi "### ${term}" "$VOKABULAR" 2>/dev/null; then
                # Auch unter Synonymen suchen
                if ! grep -qi "^- ${term}" "$VOKABULAR" 2>/dev/null; then
                    INVALID_TERMS="${INVALID_TERMS}${term}, "
                fi
            fi
        done
        if [ -n "$INVALID_TERMS" ]; then
            check FAIL "07-vokabular-patch" "Gepatchte Terme nicht im Vokabular: ${INVALID_TERMS%, }"
        else
            check PASS "07-vokabular-patch" ""
        fi
    else
        check PASS "07-vokabular-patch" "(Kein Schlagwort-Audit-Abschnitt)"
    fi
else
    check WARN "07-vokabular-patch" "Vokabular nicht gefunden: $VOKABULAR"
fi

# --- Check 8: Matrix nicht leer ---
MATRIX_ROWS=$(echo "$BODY" | grep -c '^\| \[\[' 2>/dev/null) || MATRIX_ROWS=0
if [ "$MATRIX_ROWS" -eq 0 ]; then
    check FAIL "08-matrix-nicht-leer" "Zuordnungs-Matrix hat keine Eintraege"
else
    check PASS "08-matrix-nicht-leer" "($MATRIX_ROWS Eintraege)"
fi

echo ""
echo "=== Ergebnis: $PASS PASS, $FAIL FAIL, $WARN WARN ==="
[ "$FAIL" -eq 0 ] || exit 1
