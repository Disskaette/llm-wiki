#!/usr/bin/env bash
#
# =============================================================================
# STATUS (Stand 2026-04-11): ORPHANED PREVIEW — NICHT REGISTRIERT
#
# Diese Datei ist KEIN aktiver Hook mehr. Sie ist weder in plugin/hooks/hooks.json
# registriert noch laeuft sie bei Tool-Calls. Sie wird aus zwei Gruenden behalten:
#
# 1. Referenz-Implementierung fuer SPEC-002. Die Pipeline-Lock-Logik hier wird
#    in SPEC-002 durch zwei neue Hooks ersetzt:
#      - plugin/hooks/guard-pipeline-lock.sh  (Block-Gate, exit-code-basiert)
#      - plugin/hooks/advance-pipeline-lock.sh (SubagentStop State-Machine)
#    Beide folgen dem Website_v2-Pattern mit jq und exit 2, nicht dem hier
#    verwendeten veralteten JSON-Response-Schema.
#
# 2. Funktional erprobt bis SPEC-002 Done. Die 12 Tests in
#    tests/test-gates-pending-hook.sh laufen weiterhin gruen als isolierte
#    Funktionsverifikation. Atomischer Switch: alte Datei + alte Tests weg,
#    sobald SPEC-002 Hook B + Hook C committed und verifiziert sind.
#
# KEINESFALLS DIESE DATEI WIEDER IN hooks.json REGISTRIEREN — das alte
# JSON-Response-Schema '{"decision":"block"}' wird von der Claude Code Hooks
# API 2026 nicht mehr akzeptiert und produziert "JSON validation failed" bei
# jedem Call (siehe Commits 12e8a3c + 19e23c7 fuer die Historie).
# =============================================================================
#
# check-gates-pending.sh — PreToolUse Hook auf Agent-Tool (ORPHANED)
# Blockiert neue Ingest/Synthese-Agents wenn Gates oder Nebeneffekte ausstehen.
# Gate-Agents (pruefer/reviewer/validator) werden IMMER durchgelassen.
#
# Input: JSON auf stdin mit subagent_type und prompt
# Output: JSON mit "decision": "block"/"allow" + "reason"  (VERALTETES SCHEMA)
# Env: WIKI_DIR (optional, fuer Tests; sonst aus Projekt-Root abgeleitet)

# KEIN set -uo pipefail — Hook muss IMMER gueltige JSON-Antwort liefern.
trap 'echo "{\"decision\": \"allow\", \"reason\": \"Hook-Fehler — default allow\"}"; exit 0' ERR

INPUT=$(cat)

# Wiki-Verzeichnis bestimmen
if [ -z "${WIKI_DIR:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    for CANDIDATE in "$PROJECT_ROOT/wiki" "$PWD/wiki"; do
        if [ -d "$CANDIDATE" ]; then
            WIKI_DIR="$CANDIDATE"
            break
        fi
    done
fi

# Kein Wiki-Verzeichnis gefunden → durchlassen
if [ -z "${WIKI_DIR:-}" ] || [ ! -d "${WIKI_DIR:-}" ]; then
    echo '{"decision": "allow", "reason": "Kein Wiki-Verzeichnis gefunden"}'
    exit 0
fi

PENDING="$WIKI_DIR/_pending.json"

# Kein Pending-File → alles frei
if [ ! -f "$PENDING" ]; then
    echo '{"decision": "allow", "reason": "Kein offener Durchlauf"}'
    exit 0
fi

# Subagent-Typ extrahieren
SUBAGENT=$(echo "$INPUT" | sed -n 's/.*"subagent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

# Gate-Agents immer durchlassen (pruefer, reviewer, validator)
case "${SUBAGENT:-}" in
    *pruefer*|*reviewer*|*validator*)
        echo '{"decision": "allow", "reason": "Gate-Agent durchgelassen"}'
        exit 0
        ;;
esac

# Alle anderen Agents blockieren
PENDING_CONTENT=$(cat "$PENDING")
STUFE=$(echo "$PENDING_CONTENT" | sed -n 's/.*"stufe"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
QUELLE=$(echo "$PENDING_CONTENT" | sed -n 's/.*"quelle"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

case "$STUFE" in
    gates)
        echo "{\"decision\": \"block\", \"reason\": \"Gate-Review fuer '${QUELLE}' steht aus. Dispatche zuerst die Gate-Agents (vollstaendigkeits-pruefer, quellen-pruefer, konsistenz-pruefer, vokabular-pruefer).\"}"
        ;;
    sideeffects)
        echo "{\"decision\": \"block\", \"reason\": \"Nebeneffekte fuer '${QUELLE}' stehen aus (_log.md, _index, MOC, PDF sortieren). Erst abschliessen, dann naechster Ingest.\"}"
        ;;
    *)
        echo "{\"decision\": \"block\", \"reason\": \"Unbekannter Pending-Status: '${STUFE}'. Datei ${PENDING} manuell pruefen oder loeschen um fortzufahren.\"}"
        ;;
esac
exit 0
