#!/usr/bin/env bash
# check-wiki-output.sh — 16 deterministische Checks fuer Wiki-Seiten
# Aufruf: ./check-wiki-output.sh <wiki-datei.md> [vokabular-datei.md] [wiki-verzeichnis]
#
# Exit 0 = nur PASS/WARN
# Exit 1 = mindestens ein FAIL

set -euo pipefail

FILE="${1:?Nutzung: check-wiki-output.sh <wiki-datei.md>}"
VOKABULAR="${2:-wiki/_vokabular.md}"
WIKI_DIR="${3:-wiki/}"

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
FM_TYPE=$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$FILE" | grep '^type:' | sed 's/type: *//')
if [ -z "$FM_TYPE" ]; then
    check FAIL "01-frontmatter-type" "Feld 'type:' fehlt im Frontmatter"
else
    check PASS "01-frontmatter-type" ""
fi

# --- Check 2: Seitentyp gueltig ---
VALID_TYPES="quelle konzept norm baustoff verfahren moc"
if echo "$VALID_TYPES" | grep -qw "$FM_TYPE" 2>/dev/null; then
    check PASS "02-seitentyp-gueltig" ""
else
    check FAIL "02-seitentyp-gueltig" "Typ '$FM_TYPE' ist keiner der 6 definierten Typen"
fi

# --- Check 3: Schlagworte im Vokabular ---
# Unterstuetzt sowohl YAML-Listen (  - term) als auch Inline-Arrays ([term1, term2])
if [ -f "$VOKABULAR" ]; then
    MISSING_TAGS=""
    # Extrahiere Schlagworte aus Frontmatter — beide Formate
    TAGS=$(awk '
        /^---$/ { n++; next }
        n >= 2 { exit }
        n == 1 && /^schlagworte:/ {
            # Inline-Array: schlagworte: [term1, term2]
            if ($0 ~ /\[/) {
                gsub(/^schlagworte: *\[/, "")
                gsub(/\] *$/, "")
                gsub(/, */, "\n")
                gsub(/"/, "")
                print
                next
            }
            found = 1
            next
        }
        n == 1 && found && /^  - / {
            gsub(/^  - */, "")
            gsub(/^ *"/, "")
            gsub(/" *$/, "")
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

# --- Check 4: Zahlenwert mit Quelle (ADVISORY — Gate-Agent prueft) ---
# Heuristische Pruefung: kann Kontext nicht bewerten (LaTeX, Tabellen, Norm-Nummern).
# Daher nur WARN, nicht FAIL. Echte Pruefung durch quellen-pruefer Agent.
ZAHLENWERT_ISSUES=$(awk '
    BEGIN { RS=""; FS="\n" }
    /^---$/ { next }
    /^```/ { next }
    {
        has_number = 0; has_source = 0
        for (i=1; i<=NF; i++) {
            # Ueberspringe: LaTeX-Formeln, Tabellen, Formelzeilen, Norm-Nummern, bibliogr. Daten
            if ($i ~ /\$/) continue
            if ($i ~ /\|/) continue
            if ($i ~ /^[[:space:]]*[-*].*=/) continue
            if ($i ~ /DIN EN [0-9]/) continue
            if ($i ~ /\*\*Norm:\*\*/) continue
            if ($i ~ /\*\*Titel:\*\*/) continue
            if ($i ~ /^- \*\*/) continue
            # Erweiterte Einheitenliste: Laengen, Kraefte, Spannungen, Flaecheneinheiten, Streckenlasten
            if ($i ~ /[0-9]+[.,]?[0-9]*[ ]*(mm²|cm²|m²|mm|cm|m|kN\/m²|kN\/m|kNm|kN|MN|N\/mm²|N\/mm|N|MPa|GPa|%|°|kg\/m³|kg|t)/) has_number = 1
            # Dimensionslose Koeffizienten: k_def = 0,6 oder gamma_M = 1,25
            # Aber NICHT Formel-Variablen ($\alpha = 45°$)
            if ($i ~ /= [0-9]+[.,][0-9]/ && $i !~ /\$/ && $i !~ /[a-zA-Z]+ = /) has_number = 1
            # Quellenangabe-Patterns (erweitert um Pandoc-Citations + Kapitel-Header)
            if ($i ~ /\[@/) has_source = 1
            if ($i ~ /\(.*[0-9]{4}/) has_source = 1
            if ($i ~ /S\. [0-9]/) has_source = 1
            if ($i ~ /Kap\. [0-9]/) has_source = 1
            if ($i ~ /Tab\. [0-9]/) has_source = 1
            if ($i ~ /Abb\. [0-9]/) has_source = 1
            if ($i ~ /Gl\. \(/) has_source = 1
            if ($i ~ /Seite [0-9]/) has_source = 1
            if ($i ~ /\(S\.[0-9]/) has_source = 1
        }
        if (has_number && !has_source) {
            for (i=1; i<=NF; i++) {
                if ($i ~ /^\$/ || $i ~ /\$\$/) continue
                if ($i ~ /^\|/) continue
                if ($i ~ /[0-9]+[.,]?[0-9]*[ ]*(mm|cm|m|kN|MN|N|MPa|GPa|%|°|kg|t)/ || ($i ~ /= [0-9]+[.,][0-9]/ && $i !~ /\$/ && $i !~ /[a-zA-Z]+ = /)) {
                    gsub(/^[ \t]+/, "", $i)
                    print "  → " substr($i, 1, 80)
                    break
                }
            }
        }
    }
' "$FILE")
if [ -n "$ZAHLENWERT_ISSUES" ]; then
    check WARN "04-zahlenwert-quelle" "(Advisory — Gate-Agent prueft Kontext)"
else
    check PASS "04-zahlenwert-quelle" ""
fi

# --- Check 5: Normverweis mit Abschnitt ---
# Erkennt normative Verweise (nach EC2, gemäß DIN EN...) ohne Abschnittsnummer.
# Ignoriert: reine Namensnennungen in Titeln, Frontmatter, Ueberschriften
NORM_ISSUES=$(awk '
    /^---$/ { in_fm = !in_fm; next }
    in_fm { next }
    /^#/ { next }
    /^```/ { in_code = !in_code; next }
    in_code { next }
    /EC[0-9]|DIN EN|CEN\/TS|EN [0-9]/ {
        # Hat bereits einen Abschnittsverweis? → OK
        if ($0 ~ /§[0-9]/ || $0 ~ /Abschnitt [0-9]/ || $0 ~ /Gl\. \(/ || $0 ~ /Tab\. [0-9]/ || $0 ~ /Anhang [A-Z]/ || $0 ~ /[0-9]+\.[0-9]+/) next
        # Buchtitel, Wikilinks, bibliografische Daten ausschliessen
        if ($0 ~ /\*\*Titel:\*\*/ || $0 ~ /\[\[.*EC[0-9]/ || $0 ~ /\[\[.*DIN/ || $0 ~ /\[\[.*din_en/) next
        if ($0 ~ /^- \*\*/ && $0 ~ /:\*\*/) next
        # Ist es ein normativer Kontext? (nach, gemäß, gem., laut, fordert, gilt, muss, soll)
        if ($0 ~ /[Nn]ach EC/ || $0 ~ /[Gg]em[aä][sß] EC/ || $0 ~ /[Gg]em\. EC/ || $0 ~ /[Ll]aut EC/ || $0 ~ /[Nn]ach DIN/ || $0 ~ /[Gg]em[aä][sß] DIN/ || $0 ~ /[Nn]ach CEN/ || $0 ~ /[Gg]em[aä][sß] CEN/ || $0 ~ /fordert/ || $0 ~ /gilt nach/ || $0 ~ /muss nach/) {
            gsub(/^[ \t]+/, "")
            print "  Z." NR ": " substr($0, 1, 80)
        }
    }
' "$FILE")
if [ -n "$NORM_ISSUES" ]; then
    check WARN "05-normbezug-abschnitt" "(Advisory — Gate-Agent prueft Kontext)"
else
    check PASS "05-normbezug-abschnitt" ""
fi

# --- Check 6: Seitenangabe bei Fakten ---
# Quellenseiten-Kapitelindex ist davon ausgenommen
if [ "$FM_TYPE" != "moc" ]; then
    SOURCE_NO_PAGE=$(awk '
        /^---$/ { in_fm = !in_fm; next }
        in_fm { next }
        /^#/ { next }
        /kapitel-index:/ { next }
        /\(.*[A-Z][a-z]+ [0-9]{4}/ || /\[@/ || /DIN EN.*[0-9]{4}/ || /et al\..*[0-9]{4}/ {
            # Wikilinks, Norm-Kurznamen, bibliogr. Daten, Tabellen sind keine Buchzitate
            if ($0 ~ /\[\[.*[0-9]{4}/) next
            if ($0 ~ /^- \[\[/) next
            if ($0 ~ /Neuer Entwurf/) next
            if ($0 ~ /Verweise:/) next
            if ($0 ~ /\*\*Norm:\*\*/) next
            if ($0 ~ /\*\*Titel:\*\*/) next
            if ($0 ~ /\*\*Ausgabe:\*\*/) next
            if ($0 ~ /^\|/) next
            if ($0 ~ /^- \*\*/) next
            if ($0 !~ /S\. [0-9]/ && $0 !~ /Kap\. [0-9]/ && $0 !~ /Tab\. [0-9]/ && $0 !~ /Abb\. [0-9]/ && $0 !~ /Gl\. \(/ && $0 !~ /Anhang/ && $0 !~ /\[@[^,]+, S\. [0-9]/ && $0 !~ /Seite [0-9]/) {
                gsub(/^[ \t]+/, "")
                print "  Z." NR ": " substr($0, 1, 80)
            }
        }
    ' "$FILE")
    if [ -n "$SOURCE_NO_PAGE" ]; then
        check WARN "06-seitenangabe" "(Advisory — Gate-Agent prueft Kontext)"
    else
        check PASS "06-seitenangabe" ""
    fi
else
    check PASS "06-seitenangabe" "(MOC — ausgenommen)"
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
MARKER_ISSUES=$(grep -nE '\[(TODO|UNSICHER|PRUEFEN|QUELLE BENOETIGT|INGEST UNVOLLSTAENDIG)\]' "$FILE" 2>/dev/null || true)
if [ -n "$MARKER_ISSUES" ]; then
    check FAIL "08-offene-marker" "Offene Marker gefunden:\n$MARKER_ISSUES"
else
    check PASS "08-offene-marker" ""
fi

# --- Check 9: Korrekte Umlaute ---
# Systematische Erkennung von ASCII-Umlaut-Ersetzungen.
# Sucht nach deutschen Woertern die ae/oe/ue enthalten statt ä/ö/ü.
# Reine ASCII-Patterns fuer macOS awk Kompatibilitaet.
UMLAUT_ISSUES=$(awk '
    /^---$/ { in_fm = !in_fm; next }
    in_fm { next }
    /^```/ { in_code = !in_code; next }
    in_code { next }
    {
        line = $0
        # Split auf Nicht-Buchstaben (ASCII-only fuer Kompatibilitaet)
        n = split(line, words, /[^a-zA-Z]+/)
        for (i = 1; i <= n; i++) {
            w = words[i]
            if (length(w) < 4) continue

            # Bekannte Ausnahmen (deutsche+englische Woerter mit ae/oe/ue)
            # tolower() statt /i-Flag (macOS awk hat kein /i)
            wl = tolower(w)
            if (wl ~ /^(israel|maestro|mauer|bauer|lauer|dauer|sauer|genauer|aue|laue|schauer|blauer|grauer|manoeuvre|route|roulette|suede|queue|tissue|venue|avenue|issue|rescue|statue|continue|value|league|vogue|plague|tongue|fugue|unique|antique|technique|boutique|critique|risque|mosque|cheque|true|blue|glue|clue|fuel|duel|cruel|hue|sue|rue|due|cue|aloe|poet|poem|does|goes|toes|foes|woes|hoes|roes|shoes|canoe|manuell|manueller|manuellen|manuelles|aktuell|aktuelle|aktuellen|aktueller|aktuelles|virtuell|virtuelle|eventuell|eventuelle|individuell|individuelle|strukturell|strukturelle|strukturellen|struktureller|prozentuel|textuell|konzeptuell|intellektuell|neuer|neues|neuen|neue|neuem|neuerer|neueres|neueren|coefficient|coefficients|frequenz|eigenfrequenz|steuern|steuert|gesteuert|feuer|feuerwiderstand|feuerwiderstandsdauer|abenteuer|ungeheuer|ungeheuerlich|teuer|teure|teures|teuren|heuern|anheuern|beteuern|geheuer|kreuel|kreueln)$/) continue

            found = 0

            # ae-Erkennung (ä-Ersatz)
            if (w ~ /[Aa]e[a-z]/ && w !~ /^[Mm]ae/ && w !~ /^[Ii]srae/ && w !~ /aero/ && w !~ /^[Pp]hae/) found = 1

            # oe-Erkennung (ö-Ersatz)
            if (w ~ /[Oo]e[a-z]/ && w !~ /^[Pp]oet/ && w !~ /^[Cc]oe/ && w !~ /^[Dd]oe/ && w !~ /^[Ff]oe/ && w !~ /^[Hh]oe/ && w !~ /^[Jj]oe/ && w !~ /^[Rr]oe/ && w !~ /^[Tt]oe/ && w !~ /^[Ww]oe/ && w !~ /^[Ss]hoe/ && w !~ /^[Aa]loe/ && w !~ /^[Cc]anoe/) found = 1

            # ue-Erkennung (ü-Ersatz) — nur wenn ue NICHT am Wortende
            if (w ~ /[Uu]e[a-z]/ && w !~ /[Qq]ue/ && w !~ /^[Dd]ue[lt]/ && w !~ /^[Ss]ue/ && w !~ /^[Cc]ue/ && w !~ /^[Hh]ue/ && w !~ /^[Rr]ue/ && w !~ /^[Tt]rue/ && w !~ /^[Bb]lue/ && w !~ /^[Gg]lue/ && w !~ /^[Cc]lue/ && w !~ /^[Vv]alue/ && w !~ /[Ff]uel/ && w !~ /[Cc]ruel/ && w !~ /[Dd]uel/) found = 1

            if (found) {
                printf "  Z.%d: \"%s\" in: %s\n", NR, w, substr(line, 1, 60)
            }
        }
    }
' "$FILE")
if [ -n "$UMLAUT_ISSUES" ]; then
    check WARN "09-umlaute" "(Advisory — Gate-Agent prueft Kontext)"
else
    check PASS "09-umlaute" ""
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
    DUPES=$(grep -rl "title:.*${TITLE}" "${WIKI_DIR}/quellen/" 2>/dev/null | grep -v "$BASENAME" || true)
    if [ -n "$DUPES" ]; then
        check FAIL "11-duplikat-quellen" "Moegliches Duplikat: $DUPES"
    else
        check PASS "11-duplikat-quellen" ""
    fi
else
    check PASS "11-duplikat-quellen" "(Typ $FM_TYPE oder Verzeichnis nicht vorhanden)"
fi

# --- Check 12: Index-Eintrag vorhanden (deferred) ---
# Wird nach Ingest separat geprueft — Index wird erst in Phase 4 (Nebeneffekte) aktualisiert.
# Dieser Check ist absichtlich deferred und wird bei /wiki-lint nachgeholt.
check WARN "12-index-eintrag" "(Deferred — wird bei /wiki-lint geprueft, nicht bei Einzel-Check)"

# --- Check 13: Log-Eintrag vorhanden (deferred) ---
# Wird nach Ingest separat geprueft — Log wird erst in Phase 4 (Nebeneffekte) geschrieben.
# Dieser Check ist absichtlich deferred und wird bei /wiki-lint nachgeholt.
check WARN "13-log-eintrag" "(Deferred — wird bei /wiki-lint geprueft, nicht bei Einzel-Check)"

# --- Check 14: Wikilinks aufloesbar ---
# Performance-optimiert: baut einmal eine Dateiliste, prueft dann alle Links dagegen.
# Beruecksichtigt Umlaut→ASCII-Mapping in Dateinamen (ä→ae, ö→oe, ü→ue, ß→ss).
if [ -d "$WIKI_DIR" ]; then
    # Einmalig alle .md-Dateien im Wiki auflisten (Basename ohne .md, lowercase)
    WIKI_FILES_LIST=$(find "$WIKI_DIR" -name "*.md" -type f 2>/dev/null | while read -r f; do
        basename "$f" .md | tr '[:upper:]' '[:lower:]'
    done | sort -u)

    # Hilfsfunktion: Wikilink-Text → Dateiname-Kandidat (Umlaut-Mapping + Lowercase)
    normalize_link() {
        echo "$1" | tr '[:upper:]' '[:lower:]' | \
            sed 's/ä/ae/g; s/ö/oe/g; s/ü/ue/g; s/ß/ss/g; s/Ä/ae/g; s/Ö/oe/g; s/Ü/ue/g' | \
            sed 's/ /-/g'
    }

    BROKEN_LINKS=""
    while IFS= read -r link; do
        [ -z "$link" ] && continue
        # Extrahiere Link-Ziel (ohne Alias nach |)
        LINK_FILE=$(echo "$link" | sed 's/\[\[//;s/\]\]//;s/|.*//')
        # Versuche direkten Match (lowercase)
        LINK_LOWER=$(echo "$LINK_FILE" | tr '[:upper:]' '[:lower:]')
        if echo "$WIKI_FILES_LIST" | grep -qx "$LINK_LOWER" 2>/dev/null; then
            continue
        fi
        # Versuche mit Umlaut-Mapping
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

# --- Ergebnis ---
echo ""
echo "=== Ergebnis: $PASS PASS, $FAIL FAIL, $WARN WARN ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
