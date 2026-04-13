#!/usr/bin/env bash
# check-consistency.sh — 22 Plugin-interne Konsistenzpruefungen
# Aufruf: ./check-consistency.sh [plugin-root]
#
# Exit 0 = alles konsistent
# Exit 1 = Inkonsistenzen gefunden

set -uo pipefail

PLUGIN_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

PASS=0; FAIL=0

check() {
    local status="$1" name="$2" detail="$3"
    case "$status" in
        PASS) echo "  ✅ $name"; PASS=$((PASS + 1)) ;;
        FAIL) echo "  ❌ FAIL: $name — $detail"; FAIL=$((FAIL + 1)) ;;
    esac
}

echo "=== Bibliothek-Plugin Konsistenzpruefung ==="
echo "    Plugin-Root: $PLUGIN_ROOT"
echo ""

# --- Check 1: Governance-Sync (hard-gates.md ↔ using-bibliothek Inline-Kopie) ---
HG_FILE="${PLUGIN_ROOT}/governance/hard-gates.md"
UB_FILE="${PLUGIN_ROOT}/skills/using-bibliothek/SKILL.md"
if [ -f "$HG_FILE" ] && [ -f "$UB_FILE" ]; then
    # Extract content between BEGIN/END HARD-GATES markers
    HG_INLINE=$(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' "$UB_FILE" 2>/dev/null | sed '1d;$d')
    HG_SOURCE=$(cat "$HG_FILE")
    if [ -z "$HG_INLINE" ]; then
        check FAIL "01-governance-sync" "Keine <!-- BEGIN HARD-GATES --> Marker in using-bibliothek"
    elif diff -qb <(echo "$HG_INLINE") <(echo "$HG_SOURCE") > /dev/null 2>&1; then
        check PASS "01-governance-sync" ""
    else
        check FAIL "01-governance-sync" "hard-gates.md und using-bibliothek Inline-Kopie sind nicht synchron"
    fi
else
    check FAIL "01-governance-sync" "Dateien nicht gefunden"
fi

# --- Check 2: Verarbeitungsstatus-Werte gueltig ---
VALID_STATUS="vollstaendig gesplittet nur-katalog fehlerhaft"
BAD_STATUS=$(grep -rh '^verarbeitung:' "${PLUGIN_ROOT}/skills/" "${PLUGIN_ROOT}/governance/" 2>/dev/null | while IFS= read -r line; do
    val=$(echo "$line" | sed 's/^verarbeitung: *//;s/ *#.*//')
    if [ -n "$val" ] && ! echo "$VALID_STATUS" | grep -qw "$val"; then
        echo "$val"
    fi
done || true)
if [ -n "$BAD_STATUS" ]; then
    check FAIL "02-verarbeitungsstatus" "Ungueltiger Status: $BAD_STATUS"
else
    check PASS "02-verarbeitungsstatus" ""
fi

# --- Check 3: Agent-Count (Dateien ↔ naming-konvention Tabelle "Bestehende Agents") ---
# Zaehle .md-Dateien im agents/ Verzeichnis
AGENT_FILES=$(find "${PLUGIN_ROOT}/agents/" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
# Zaehle Zeilen in der "Bestehende Agents"-Tabelle: Format "| agentname | Typ | Dispatcht von |"
# Erkennung: Tabellenzeilen die mit | beginnen, einen bekannten Agent-Typ enthalten,
# und NICHT die Header-Zeile sind
NK_FILE="${PLUGIN_ROOT}/governance/naming-konvention.md"
if [ -f "$NK_FILE" ]; then
    # Zaehle Datenzeilen der Tabelle "Bestehende Agents" — erkennbar an "| ... | /ingest\|/wiki-lint\|/normenupdate"
    AGENT_TABLE=$(awk '
        /^## Bestehende Agents/ { in_section = 1; next }
        in_section && /^\|---/ { in_table = 1; next }
        in_section && /^\| Agent/ { next }
        in_table && /^\| / { count++ }
        in_table && !/^\|/ { exit }
        END { print count+0 }
    ' "$NK_FILE")
else
    AGENT_TABLE=0
fi
if [ "$AGENT_FILES" -eq "$AGENT_TABLE" ]; then
    check PASS "03-agent-count" ""
else
    check FAIL "03-agent-count" "Agent-Dateien: $AGENT_FILES, Tabelle 'Bestehende Agents': $AGENT_TABLE"
fi

# --- Check 4: Command-Count (Dateien ↔ tatsaechliche Skills) ---
CMD_FILES=$(find "${PLUGIN_ROOT}/commands/" -name "*.md" -type f ! -name "using-bibliothek.md" 2>/dev/null | wc -l | tr -d ' ')
SKILL_DIRS=$(find "${PLUGIN_ROOT}/skills/" -mindepth 1 -maxdepth 1 -type d ! -name "using-bibliothek" 2>/dev/null | wc -l | tr -d ' ')
if [ "$CMD_FILES" -eq "$SKILL_DIRS" ]; then
    check PASS "04-command-count" ""
else
    check FAIL "04-command-count" "Commands: $CMD_FILES, Skills (ohne using-bibliothek): $SKILL_DIRS"
fi

# --- Check 5: Gate-Count pro Skill ---
GATE_COUNT=10
SKILLS_WITH_BAD_GATES=""
for skill_file in "${PLUGIN_ROOT}/skills/"*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    skill_name=$(basename "$(dirname "$skill_file")")
    table_rows=$(grep -c '| KEIN\|| KEINE\|| KORREKTE' "$skill_file" 2>/dev/null || echo 0)
    table_rows=$(echo "$table_rows" | tr -dc '0-9')
    [ -z "$table_rows" ] && table_rows=0
    if [ "$table_rows" -gt 0 ] && [ "$table_rows" -lt "$GATE_COUNT" ]; then
        SKILLS_WITH_BAD_GATES="${SKILLS_WITH_BAD_GATES}${skill_name}(${table_rows}/${GATE_COUNT}), "
    fi
done
if [ -n "$SKILLS_WITH_BAD_GATES" ]; then
    check FAIL "05-gate-count" "Unvollstaendige Governance-Tabellen: ${SKILLS_WITH_BAD_GATES%, }"
else
    check PASS "05-gate-count" ""
fi

# --- Check 6: Agent-Governance-Tabellen vorhanden ---
AGENTS_NO_GOV=""
for agent_file in "${PLUGIN_ROOT}/agents/"*.md; do
    [ -f "$agent_file" ] || continue
    if ! grep -q "Governance-Zuständigkeit\|Governance-Zustaendigkeit" "$agent_file" 2>/dev/null; then
        AGENTS_NO_GOV="${AGENTS_NO_GOV}$(basename "$agent_file"), "
    fi
done
if [ -n "$AGENTS_NO_GOV" ]; then
    check FAIL "06-agent-governance" "Agents ohne Governance-Tabelle: ${AGENTS_NO_GOV%, }"
else
    check PASS "06-agent-governance" ""
fi

# --- Check 7: Re-Review-Limit in allen Agents ---
AGENTS_NO_LIMIT=""
for agent_file in "${PLUGIN_ROOT}/agents/"*.md; do
    [ -f "$agent_file" ] || continue
    if ! grep -q "Re-Review-Limit" "$agent_file" 2>/dev/null; then
        AGENTS_NO_LIMIT="${AGENTS_NO_LIMIT}$(basename "$agent_file"), "
    fi
done
if [ -n "$AGENTS_NO_LIMIT" ]; then
    check FAIL "07-re-review-limit" "Agents ohne Re-Review-Limit: ${AGENTS_NO_LIMIT%, }"
else
    check PASS "07-re-review-limit" ""
fi

# --- Check 8: EXTERNER-INHALT Marker in lesenden Skills ---
READING_SKILLS="ingest synthese normenupdate"
SKILLS_NO_MARKER=""
for skill in $READING_SKILLS; do
    skill_file="${PLUGIN_ROOT}/skills/${skill}/SKILL.md"
    if [ -f "$skill_file" ] && ! grep -q "EXTERNER-INHALT" "$skill_file" 2>/dev/null; then
        SKILLS_NO_MARKER="${SKILLS_NO_MARKER}${skill}, "
    fi
done
if [ -n "$SKILLS_NO_MARKER" ]; then
    check FAIL "08-externer-inhalt" "Skills ohne EXTERNER-INHALT Marker: ${SKILLS_NO_MARKER%, }"
else
    check PASS "08-externer-inhalt" ""
fi

# --- Check 9: Seitentypen-Datei vorhanden und vollstaendig ---
ST_FILE="${PLUGIN_ROOT}/governance/seitentypen.md"
if [ -f "$ST_FILE" ]; then
    TYPES_DEFINED=$(grep -c '^### ' "$ST_FILE" 2>/dev/null || echo 0)
    if [ "$TYPES_DEFINED" -ge 6 ]; then
        check PASS "09-seitentypen" ""
    else
        check FAIL "09-seitentypen" "Nur $TYPES_DEFINED Seitentypen definiert (erwartet: 6)"
    fi
else
    check FAIL "09-seitentypen" "Datei nicht gefunden"
fi

# --- Check 10: Vokabular-Regeln vorhanden ---
if [ -f "${PLUGIN_ROOT}/governance/vokabular-regeln.md" ]; then
    check PASS "10-vokabular-regeln" ""
else
    check FAIL "10-vokabular-regeln" "vokabular-regeln.md nicht gefunden"
fi

# --- Check 11: Qualitaetsstufen-Datei vorhanden ---
if [ -f "${PLUGIN_ROOT}/governance/qualitaetsstufen.md" ]; then
    check PASS "11-qualitaetsstufen" ""
else
    check FAIL "11-qualitaetsstufen" "qualitaetsstufen.md nicht gefunden"
fi

# --- Check 12: Template-Dateien vorhanden ---
MISSING_TEMPLATES=""
for tmpl in TEMPLATE-skill.md TEMPLATE-agent.md; do
    if [ ! -f "${PLUGIN_ROOT}/governance/${tmpl}" ]; then
        MISSING_TEMPLATES="${MISSING_TEMPLATES}${tmpl}, "
    fi
done
if [ -n "$MISSING_TEMPLATES" ]; then
    check FAIL "12-templates" "Fehlende Templates: ${MISSING_TEMPLATES%, }"
else
    check PASS "12-templates" ""
fi

# --- Check 13: Ingest-Dispatch-Template existiert ---
ROOT="$PLUGIN_ROOT"
if [ -f "$ROOT/governance/ingest-dispatch-template.md" ]; then
    check PASS "13-ingest-template" ""
else
    check FAIL "13-ingest-template" "governance/ingest-dispatch-template.md fehlt"
fi

# --- Check 14: Synthese-Dispatch-Template existiert ---
if [ -f "$ROOT/governance/synthese-dispatch-template.md" ]; then
    check PASS "14-synthese-template" ""
else
    check FAIL "14-synthese-template" "governance/synthese-dispatch-template.md fehlt"
fi

# --- Check 15: Templates enthalten Platzhalter ---
INGEST_PH=$(grep -c '{{' "$ROOT/governance/ingest-dispatch-template.md" 2>/dev/null || echo 0)
SYNTHESE_PH=$(grep -c '{{' "$ROOT/governance/synthese-dispatch-template.md" 2>/dev/null || echo 0)
if [ "$INGEST_PH" -ge 5 ] && [ "$SYNTHESE_PH" -ge 5 ]; then
    check PASS "15-template-platzhalter" ""
else
    check FAIL "15-template-platzhalter" "Ingest: $INGEST_PH (min 5), Synthese: $SYNTHESE_PH (min 5)"
fi

# --- Check 16: Skills referenzieren Templates ---
INGEST_REF=$(grep -c 'ingest-dispatch-template' "$ROOT/skills/ingest/SKILL.md" 2>/dev/null || echo 0)
SYNTHESE_REF=$(grep -c 'synthese-dispatch-template' "$ROOT/skills/synthese/SKILL.md" 2>/dev/null || echo 0)
if [ "$INGEST_REF" -ge 1 ] && [ "$SYNTHESE_REF" -ge 1 ]; then
    check PASS "16-skill-template-referenz" ""
else
    check FAIL "16-skill-template-referenz" "Ingest-Ref: $INGEST_REF, Synthese-Ref: $SYNTHESE_REF"
fi

# --- Check 17: Gate-Dispatch-Template existiert ---
if [ -f "$ROOT/governance/gate-dispatch-template.md" ]; then
    check PASS "17-gate-template" ""
else
    check FAIL "17-gate-template" "governance/gate-dispatch-template.md fehlt"
fi

# --- Check 18: Gate-Template hat alle 4 Gates ---
if [ -f "$ROOT/governance/gate-dispatch-template.md" ]; then
    GATE_AGENTS=0
    grep -q 'vollstaendigkeits-pruefer' "$ROOT/governance/gate-dispatch-template.md" && GATE_AGENTS=$((GATE_AGENTS+1))
    grep -q 'quellen-pruefer' "$ROOT/governance/gate-dispatch-template.md" && GATE_AGENTS=$((GATE_AGENTS+1))
    grep -q 'konsistenz-pruefer' "$ROOT/governance/gate-dispatch-template.md" && GATE_AGENTS=$((GATE_AGENTS+1))
    grep -q 'vokabular-pruefer' "$ROOT/governance/gate-dispatch-template.md" && GATE_AGENTS=$((GATE_AGENTS+1))
    if [ "$GATE_AGENTS" -ge 4 ]; then
        check PASS "18-gate-template-vollstaendig" ""
    else
        check FAIL "18-gate-template-vollstaendig" "Nur $GATE_AGENTS von 4 Gate-Agents im Template"
    fi
else
    check FAIL "18-gate-template-vollstaendig" "Gate-Template fehlt"
fi

# --- Check 19: Ingest-Skill referenziert Gate-Template ---
GATE_REF=$(grep -c 'gate-dispatch-template' "$ROOT/skills/ingest/SKILL.md" 2>/dev/null || echo 0)
if [ "$GATE_REF" -ge 1 ]; then
    check PASS "19-skill-gate-referenz" ""
else
    check FAIL "19-skill-gate-referenz" "/ingest SKILL.md referenziert gate-dispatch-template nicht"
fi

# --- Check 20: valid-types.txt ↔ seitentypen.md Sync ---
VT_FILE="${PLUGIN_ROOT}/hooks/config/valid-types.txt"
ST_FILE2="${PLUGIN_ROOT}/governance/seitentypen.md"
if [ -f "$VT_FILE" ] && [ -f "$ST_FILE2" ]; then
    # Extract types from valid-types.txt (skip comments and blank lines)
    VT_TYPES=$(grep -v '^#' "$VT_FILE" | grep -v '^$' | sort)
    # Extract types from seitentypen.md: lines matching "| **typename** |"
    ST_TYPES=$(grep '^| \*\*' "$ST_FILE2" | sed 's/^| \*\*\([a-z]*\)\*\*.*/\1/' | sort)
    if [ -z "$VT_TYPES" ] || [ -z "$ST_TYPES" ]; then
        check FAIL "20-valid-types-sync" "Konnte Typen nicht extrahieren (valid-types: $(echo "$VT_TYPES" | wc -l | tr -d ' '), seitentypen: $(echo "$ST_TYPES" | wc -l | tr -d ' '))"
    elif diff -q <(echo "$VT_TYPES") <(echo "$ST_TYPES") > /dev/null 2>&1; then
        check PASS "20-valid-types-sync" ""
    else
        ONLY_VT=$(comm -23 <(echo "$VT_TYPES") <(echo "$ST_TYPES") | tr '\n' ',' | sed 's/,$//')
        ONLY_ST=$(comm -13 <(echo "$VT_TYPES") <(echo "$ST_TYPES") | tr '\n' ',' | sed 's/,$//')
        DETAIL=""
        [ -n "$ONLY_VT" ] && DETAIL="Nur in valid-types.txt: $ONLY_VT. "
        [ -n "$ONLY_ST" ] && DETAIL="${DETAIL}Nur in seitentypen.md: $ONLY_ST."
        check FAIL "20-valid-types-sync" "$DETAIL"
    fi
else
    check FAIL "20-valid-types-sync" "Dateien nicht gefunden"
fi

# --- Check 21: domain-gates.txt ↔ hard-gates.md Validierung ---
DG_FILE="${PLUGIN_ROOT}/hooks/config/domain-gates.txt"
if [ -f "$DG_FILE" ] && [ -f "$HG_FILE" ]; then
    DG_INVALID=""
    while IFS= read -r line; do
        # Skip comments and blank lines
        case "$line" in
            \#*|"") continue ;;
        esac
        GATE_NAME="${line%%:*}"
        if ! grep -q "HARD-GATE: ${GATE_NAME}" "$HG_FILE" 2>/dev/null; then
            DG_INVALID="${DG_INVALID}${GATE_NAME}, "
        fi
    done < "$DG_FILE"
    if [ -n "$DG_INVALID" ]; then
        check FAIL "21-domain-gates-valid" "Gate nicht in hard-gates.md: ${DG_INVALID%, }"
    else
        check PASS "21-domain-gates-valid" ""
    fi
else
    check FAIL "21-domain-gates-valid" "Dateien nicht gefunden (domain-gates: $([ -f "$DG_FILE" ] && echo ja || echo nein), hard-gates: $([ -f "$HG_FILE" ] && echo ja || echo nein))"
fi

# --- Check 22: Synthese-Template hat Discovery-Platzhalter ---
if [ -f "$ROOT/governance/synthese-dispatch-template.md" ]; then
    DISC_PH=0
    grep -q '{{KONZEPT_REIFE_INHALT}}' "$ROOT/governance/synthese-dispatch-template.md" && DISC_PH=$((DISC_PH+1))
    grep -q '{{SCHLAGWORT_VORSCHLAEGE_INHALT}}' "$ROOT/governance/synthese-dispatch-template.md" && DISC_PH=$((DISC_PH+1))
    grep -q '\[DISCOVERY\]' "$ROOT/governance/synthese-dispatch-template.md" && DISC_PH=$((DISC_PH+1))
    if [ "$DISC_PH" -ge 3 ]; then
        check PASS "22-discovery-template" ""
    else
        check FAIL "22-discovery-template" "Synthese-Template: nur $DISC_PH/3 Discovery-Elemente (Platzhalter + Block)"
    fi
else
    check FAIL "22-discovery-template" "Synthese-Template fehlt"
fi

# --- Ergebnis ---
echo ""
echo "=== Ergebnis: $PASS PASS, $FAIL FAIL ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
