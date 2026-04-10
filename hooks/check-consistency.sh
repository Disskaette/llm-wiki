#!/usr/bin/env bash
# check-consistency.sh — 16 Plugin-interne Konsistenzpruefungen
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

# --- Ergebnis ---
echo ""
echo "=== Ergebnis: $PASS PASS, $FAIL FAIL ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
