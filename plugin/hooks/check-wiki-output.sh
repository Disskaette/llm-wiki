#!/usr/bin/env bash
# check-wiki-output.sh — 14 deterministische Checks fuer Wiki-Seiten
# Aufruf: ./check-wiki-output.sh <wiki-datei.md> [vokabular-datei.md] [wiki-verzeichnis]
#
# Exit 0 = nur PASS/WARN
# Exit 1 = mindestens ein FAIL
#
# Heuristische Checks (Zahlenwerte, Normbezuege, Seitenangaben, Umlaute)
# wurden entfernt — sie brauchen Kontext den Shell nicht liefern kann.
# Die Gate-Agents (quellen-pruefer, konsistenz-pruefer) pruefen das kontextuell.

set -euo pipefail

FILE="${1:?Nutzung: check-wiki-output.sh <wiki-datei.md>}"
VOKABULAR="${2:-wiki/_vokabular.md}"
WIKI_DIR="${3:-wiki/}"

# Config-Verzeichnis (Typen-Whitelist)
CONFIG_DIR="$(dirname "$0")/config"

PASS=0; FAIL=0; WARN=0

check() {
    local status="$1" name="$2" detail="$3"
    case "$status" in
        PASS) echo "  ✅ Check $name"; PASS=$((PASS + 1)) ;;
        FAIL) echo "  ❌ FAIL: $name — $detail"; FAIL=$((FAIL + 1)) ;;
        WARN) echo "  ⚠️  WARN: $name — $detail"; WARN=$((WARN + 1)) ;;
    esac
}

echo "=== Wiki-Output-Pruefung: $(basename "$FILE") ==="

# --- Check 1: Frontmatter vollstaendig ---
FM_TYPE=$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$FILE" | grep '^type:' | sed 's/type: *//' || true)
if [ -z "$FM_TYPE" ]; then
    check FAIL "01-frontmatter-type" "Feld 'type:' fehlt im Frontmatter"
else
    check PASS "01-frontmatter-type" ""
fi

# --- Check 2: Seitentyp gueltig ---
if [ -f "$CONFIG_DIR/valid-types.txt" ]; then
    VALID_TYPES=$(grep -v '^#' "$CONFIG_DIR/valid-types.txt" | grep -v '^$' | tr '\n' ' ')
else
    VALID_TYPES="quelle konzept norm baustoff verfahren moc"
fi
if echo "$VALID_TYPES" | grep -qw "$FM_TYPE" 2>/dev/null; then
    check PASS "02-seitentyp-gueltig" ""
else
    check FAIL "02-seitentyp-gueltig" "Typ '$FM_TYPE' ist keiner der definierten Typen"
fi

# --- Check 3: Schlagworte im Vokabular ---
if [ -f "$VOKABULAR" ]; then
    MISSING_TAGS=""
    TAGS=$(awk '
        /^---$/ { n++; next }
        n >= 2 { exit }
        n == 1 && /^schlagworte:/ {
            if ($0 ~ /\[/) {
                gsub(/^schlagworte: *\[/, "")
                gsub(/\] *$/, "")
                gsub(/, */, "\n")
                gsub(/"/, "")
                gsub(/\047/, "")
                print
                next
            }
            found = 1
            next
        }
        n == 1 && found && /^  - / {
            gsub(/^  - */, "")
            gsub(/^ *["\047]/, "")
            gsub(/["\047] *$/, "")
            print
            next
        }
        found && !/^  -/ { found = 0 }
    ' "$FILE")
    while IFS= read -r tag; do
        [ -z "$tag" ] && continue
        if ! grep -qi "^### ${tag}$" "$VOKABULAR" 2>/dev/null; then
            MISSING_TAGS="${MISSING_TAGS}${tag}, "
        fi
    done <<< "$TAGS"
    if [ -n "$MISSING_TAGS" ]; then
        check FAIL "03-schlagworte-vokabular" "Nicht im Vokabular: ${MISSING_TAGS%, }"
    else
        check PASS "03-schlagworte-vokabular" ""
    fi
else
    check WARN "03-schlagworte-vokabular" "Vokabular-Datei nicht gefunden: $VOKABULAR"
fi

# --- Check 7: Konzeptseite hat Querverweise ---
if [ "$FM_TYPE" = "konzept" ] || [ "$FM_TYPE" = "verfahren" ] || [ "$FM_TYPE" = "baustoff" ]; then
    WIKILINKS=$(grep -c '\[\[.*\]\]' "$FILE" 2>/dev/null) || WIKILINKS=0
    if [ "$WIKILINKS" -lt 1 ]; then
        check FAIL "07-querverweise" "Keine Wikilinks [[...]] gefunden"
    else
        check PASS "07-querverweise" ""
    fi
else
    check PASS "07-querverweise" "(Typ $FM_TYPE — nicht erforderlich)"
fi

# --- Check 8: Keine offenen Marker ---
MARKER_ISSUES=$(grep -nE '\[(TODO|UNSICHER|PRUEFEN|QUELLE BENOETIGT|INGEST UNVOLLSTAENDIG|SYNTHESE UNVOLLSTAENDIG)\]' "$FILE" 2>/dev/null || true)
if [ -n "$MARKER_ISSUES" ]; then
    check FAIL "08-offene-marker" "Offene Marker gefunden:\n$MARKER_ISSUES"
else
    check PASS "08-offene-marker" ""
fi

# --- Check 10: Quellenseite hat Kapitelindex ---
if [ "$FM_TYPE" = "quelle" ]; then
    if grep -q 'kapitel-index:' "$FILE" 2>/dev/null; then
        check PASS "10-kapitelindex" ""
    else
        check FAIL "10-kapitelindex" "Quellenseite ohne kapitel-index im Frontmatter"
    fi
else
    check PASS "10-kapitelindex" "(Typ $FM_TYPE — nicht erforderlich)"
fi

# --- Check 11: Keine Duplikat-Quellenseiten ---
if [ "$FM_TYPE" = "quelle" ] && [ -d "${WIKI_DIR}/quellen" ]; then
    TITLE=$(awk '/^---$/{n++; next} n==1 && /^title:/{gsub(/^title: *"?/,""); gsub(/"$/,""); print; exit}' "$FILE")
    BASENAME=$(basename "$FILE")
    DUPES=$(grep -rl "^title:" "${WIKI_DIR}/quellen/" 2>/dev/null | while read -r f; do
        [ "$(basename "$f")" = "$BASENAME" ] && continue
        T=$(awk '/^---$/{n++; next} n==1 && /^title:/{gsub(/^title: *"?/,""); gsub(/"$/,""); print; exit}' "$f")
        [ "$T" = "$TITLE" ] && echo "$f"
    done || true)
    if [ -n "$DUPES" ]; then
        check FAIL "11-duplikat-quellen" "Moegliches Duplikat: $DUPES"
    else
        check PASS "11-duplikat-quellen" ""
    fi
else
    check PASS "11-duplikat-quellen" "(Typ $FM_TYPE oder Verzeichnis nicht vorhanden)"
fi

# --- Check 12: Index-Eintrag vorhanden (deferred) ---
check WARN "12-index-eintrag" "(Deferred — wird bei /wiki-lint geprueft)"

# --- Check 13: Log-Eintrag vorhanden (deferred) ---
check WARN "13-log-eintrag" "(Deferred — wird bei /wiki-lint geprueft)"

# --- Check 14: Wikilinks aufloesbar ---
if [ -d "$WIKI_DIR" ]; then
    WIKI_FILES_LIST=$(find "$WIKI_DIR" -name "*.md" -type f 2>/dev/null | while read -r f; do
        basename "$f" .md | tr '[:upper:]' '[:lower:]'
    done | sort -u)

    normalize_link() {
        echo "$1" | tr '[:upper:]' '[:lower:]' | \
            sed 's/ä/ae/g; s/ö/oe/g; s/ü/ue/g; s/ß/ss/g; s/Ä/ae/g; s/Ö/oe/g; s/Ü/ue/g' | \
            sed 's/ /-/g'
    }

    BROKEN_LINKS=""
    while IFS= read -r link; do
        [ -z "$link" ] && continue
        LINK_FILE=$(echo "$link" | sed 's/\[\[//;s/\]\]//;s/|.*//')
        LINK_LOWER=$(echo "$LINK_FILE" | tr '[:upper:]' '[:lower:]')
        if echo "$WIKI_FILES_LIST" | grep -qx "$LINK_LOWER" 2>/dev/null; then
            continue
        fi
        LINK_ASCII=$(normalize_link "$LINK_FILE")
        if echo "$WIKI_FILES_LIST" | grep -qx "$LINK_ASCII" 2>/dev/null; then
            continue
        fi
        BROKEN_LINKS="${BROKEN_LINKS}[[${LINK_FILE}]], "
    done < <(grep -oE '\[\[[^]]+\]\]' "$FILE" 2>/dev/null || true)
    if [ -n "$BROKEN_LINKS" ]; then
        check WARN "14-wikilinks-aufloesbar" "Nicht aufloesbare Links: ${BROKEN_LINKS%, }"
    else
        check PASS "14-wikilinks-aufloesbar" ""
    fi
else
    check WARN "14-wikilinks-aufloesbar" "Wiki-Verzeichnis nicht gefunden"
fi

# --- Check 15: Widerspruchs-Marker vollstaendig ---
WIDERSPRUCH_INCOMPLETE=$(awk '
    /\[WIDERSPRUCH/ {
        if ($0 !~ /Quelle [AB]/ && $0 !~ /[A-Z][a-z]+ [0-9]{4}.*[A-Z][a-z]+ [0-9]{4}/) {
            print "  Z." NR ": Unvollstaendiger WIDERSPRUCH-Marker"
        }
    }
' "$FILE")
if [ -n "$WIDERSPRUCH_INCOMPLETE" ]; then
    check FAIL "15-widerspruch-marker" "$WIDERSPRUCH_INCOMPLETE"
else
    check PASS "15-widerspruch-marker" ""
fi

# --- Check 16: Review-Status ---
if grep -q '^reviewed:' "$FILE" 2>/dev/null; then
    check PASS "16-review-status" ""
else
    check WARN "16-review-status" "Feld 'reviewed:' fehlt im Frontmatter"
fi

# --- Check 17: Quellpfad vorhanden (nur type: quelle) ---
if [ "$FM_TYPE" = "quelle" ]; then
    HAS_PDF=$(grep -c '^pdf:' "$FILE" 2>/dev/null) || HAS_PDF=0
    HAS_DATEI=$(grep -c '^quelle-datei:' "$FILE" 2>/dev/null) || HAS_DATEI=0
    HAS_URL=$(grep -c '^url:' "$FILE" 2>/dev/null) || HAS_URL=0
    if [ "$HAS_PDF" -eq 0 ] && [ "$HAS_DATEI" -eq 0 ] && [ "$HAS_URL" -eq 0 ]; then
        check FAIL "17-quellpfad" "Weder pdf:, quelle-datei: noch url: im Frontmatter"
    else
        check PASS "17-quellpfad" ""
    fi
    # URL-Quellen muessen ein Abrufdatum haben
    if [ "$HAS_URL" -gt 0 ]; then
        HAS_ABGERUFEN=$(grep -c '^abgerufen:' "$FILE" 2>/dev/null) || HAS_ABGERUFEN=0
        if [ "$HAS_ABGERUFEN" -eq 0 ]; then
            check WARN "17-url-abgerufen" "url: ohne abgerufen:-Datum"
        else
            check PASS "17-url-abgerufen" ""
        fi
    fi
else
    check PASS "17-quellpfad" "(Typ $FM_TYPE — nicht erforderlich)"
fi

# --- Check 18: Discovery-Dateien existieren (nur bei Konzeptseiten) ---
if [ "$FM_TYPE" = "konzept" ]; then
    DISCOVERY_MISSING=""
    [ ! -f "${WIKI_DIR}/_konzept-reife.md" ] && DISCOVERY_MISSING="${DISCOVERY_MISSING}_konzept-reife.md, "
    [ ! -f "${WIKI_DIR}/_schlagwort-vorschlaege.md" ] && DISCOVERY_MISSING="${DISCOVERY_MISSING}_schlagwort-vorschlaege.md, "
    if [ -n "$DISCOVERY_MISSING" ]; then
        check FAIL "18-discovery-dateien" "Discovery-Dateien fehlen: ${DISCOVERY_MISSING%, }"
    else
        check PASS "18-discovery-dateien" ""
    fi
else
    check PASS "18-discovery-dateien" "(Typ $FM_TYPE — nicht erforderlich)"
fi

# --- Ergebnis ---
echo ""
echo "=== Ergebnis: $PASS PASS, $FAIL FAIL, $WARN WARN ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
