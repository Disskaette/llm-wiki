#!/usr/bin/env bash
# check-wiki-write.sh — PostToolUse Hook fuer Write/Edit/Bash auf wiki/**/*.md
# Wird automatisch nach jedem Write/Edit auf Wiki-Dateien ausgefuehrt.
# Ruft check-wiki-output.sh auf die betroffene Datei auf.
#
# Input: JSON auf stdin mit tool_input.file_path (Write/Edit) oder tool_input.command (Bash)
# Output: JSON mit "decision": "block"/"allow" + "reason"

# KEIN set -uo pipefail — Hook muss IMMER gueltige JSON-Antwort liefern.
# Bei jedem Crash: default ALLOW (lieber durchlassen als false-positive blocken).
trap 'echo "{\"decision\": \"allow\", \"reason\": \"Hook-Fehler — default allow\"}"; exit 0' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="${SCRIPT_DIR}/check-wiki-output.sh"

# Lese stdin (PostToolUse bekommt tool_input als JSON)
INPUT=$(cat || true)

# Extrahiere Dateipfad — pure shell, kein python3 noetig
# Versuche file_path (Write/Edit) — escaped quotes temporaer ersetzen
FILE_PATH=$(echo "$INPUT" | sed 's/\\"/DBLQUOTE/g' | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed 's/DBLQUOTE/"/g' | head -1)

# Falls leer: versuche filePath (camelCase-Variante)
if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$INPUT" | sed 's/\\"/DBLQUOTE/g' | sed -n 's/.*"filePath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed 's/DBLQUOTE/"/g' | head -1)
fi

# Falls Bash-Tool: pruefe ob command SCHREIBEND auf wiki/ zugreift
# Nur blocken wenn ein Schreiboperator DIREKT auf einen wiki/-Pfad zeigt.
# Lesende Befehle (ls, cat, wc, grep, head, tail) werden NICHT geprueft.
if [ -z "$FILE_PATH" ]; then
    COMMAND=$(echo "$INPUT" | sed 's/\\"/DBLQUOTE/g' | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed 's/DBLQUOTE/"/g' | head -1)
    # Bestimme bekannte Wiki-Pfade fuer praeziseres Matching
    PROJ_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
    PROJ_WIKI="${PROJ_ROOT}/wiki/"
    CWD_WIKI="${PWD}/wiki/"
    # Entferne harmlose Umleitungen
    CLEAN_CMD=$(echo "$COMMAND" | sed 's/2>\/dev\/null//g; s/>\/dev\/null//g; s/2>&1//g; s/1>\/dev\/null//g')
    # Pruefe ob ein Schreiboperator auf einen bekannten Wiki-Pfad zielt
    # Fallback wiki/[a-z] fangt relative Pfade (z.B. wiki/quellen/test.md)
    if echo "$CLEAN_CMD" | grep -qE "(>[^&]|>>|tee ).*(${PROJ_WIKI}|${CWD_WIKI}|wiki/[a-z])" 2>/dev/null || \
       echo "$CLEAN_CMD" | grep -qE "sed -i.*(${PROJ_WIKI}|${CWD_WIKI}|wiki/[a-z])" 2>/dev/null || \
       echo "$CLEAN_CMD" | grep -qE "(^| )(mv|cp|rm) .*(${PROJ_WIKI}|${CWD_WIKI}|wiki/[a-z])" 2>/dev/null; then
        echo '{"decision": "block", "reason": "Bash-Schreibzugriff auf wiki/ erkannt. Wiki-Seiten nur ueber /ingest, /synthese, /normenupdate, /vokabular aendern."}'
        exit 0
    fi
    echo '{"decision": "allow", "reason": "Kein Wiki-Schreibzugriff"}'
    exit 0
fi

# Pruefe ob die Datei unter wiki/ liegt
case "$FILE_PATH" in
    */wiki/*.md|wiki/*.md)
        # Wiki-Datei erkannt — pruefe!
        ;;
    *)
        # Keine Wiki-Datei — durchlassen
        echo '{"decision": "allow", "reason": "Keine Wiki-Datei"}'
        exit 0
        ;;
esac

# Bestimme Wiki-Root, Vokabular-Pfad und Pending-Pfad FRUEH
# (wird von _log.md Transition und Quellenseiten-Erstellung benoetigt)
WIKI_DIR=$(echo "$FILE_PATH" | sed 's|/wiki/.*|/wiki/|')
VOKAB="${WIKI_DIR}_vokabular.md"
PENDING="${WIKI_DIR}_pending.json"

# Sonderdateien die KEINE Wiki-Seiten sind (kein Frontmatter noetig)
BASENAME=$(basename "$FILE_PATH")
case "$BASENAME" in
    CLAUDE.md|_vokabular.md|*.json)
        echo '{"decision": "allow", "reason": "Sonderdatei — kein Wiki-Seiten-Check"}'
        exit 0
        ;;
    _log.md)
        # --- _pending.json Stufen-Transition ---
        if [ -f "$PENDING" ]; then
            P_STUFE=$(sed -n 's/.*"stufe"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PENDING" | head -1)
            P_QUELLE=$(sed -n 's/.*"quelle"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PENDING" | head -1)

            if [ "$P_STUFE" = "gates" ]; then
                # Check if gate results are in the last 20 lines of the log
                LAST_LINES=$(tail -20 "$FILE_PATH" 2>/dev/null || true)
                if echo "$LAST_LINES" | grep -q "Gates:.*PASS" 2>/dev/null && echo "$LAST_LINES" | grep -q "$P_QUELLE" 2>/dev/null; then
                    sed -i '' 's/"stufe"[[:space:]]*:[[:space:]]*"gates"/"stufe":"sideeffects"/' "$PENDING"
                fi
            elif [ "$P_STUFE" = "sideeffects" ]; then
                # Check if complete log entry exists (has Gates + Verarbeitung lines)
                LAST_ENTRY=$(tail -20 "$FILE_PATH")
                HAS_GATES=$(echo "$LAST_ENTRY" | grep -c "Gates:" 2>/dev/null || true)
                HAS_VERARBEITUNG=$(echo "$LAST_ENTRY" | grep -c "Verarbeitung:" 2>/dev/null || true)
                if [ "$HAS_GATES" -gt 0 ] && [ "$HAS_VERARBEITUNG" -gt 0 ]; then
                    rm -f "$PENDING"
                fi
            fi
        fi
        echo '{"decision": "allow", "reason": "Log-Update erlaubt"}'
        exit 0
        ;;
esac

# Index-Dateien brauchen auch keinen Wiki-Seiten-Check
case "$FILE_PATH" in
    */_index/*.md)
        echo '{"decision": "allow", "reason": "Index-Datei — kein Wiki-Seiten-Check"}'
        exit 0
        ;;
esac

# Pruefe ob die Datei existiert
if [ ! -f "$FILE_PATH" ]; then
    echo '{"decision": "allow", "reason": "Datei existiert (noch) nicht"}'
    exit 0
fi

# Fuehre check-wiki-output.sh aus — Exit-Code VOR || true erfassen!
set +e
CHECK_OUTPUT=$("$CHECK_SCRIPT" "$FILE_PATH" "$VOKAB" "$WIKI_DIR" 2>&1)
CHECK_RC=$?
set -e

if [ "$CHECK_RC" -eq 0 ]; then
    echo "{\"decision\": \"allow\", \"reason\": \"Wiki-Check bestanden\"}"
    # --- _pending.json Erstellung bei neuen Quellenseiten ---
    case "$FILE_PATH" in
        */wiki/quellen/*.md)
            if [ ! -f "$PENDING" ]; then
                QUELLE_BASENAME=$(basename "$FILE_PATH" .md)
                printf '{"typ":"ingest","stufe":"gates","quelle":"%s","timestamp":"%s"}' \
                    "$QUELLE_BASENAME" "$(date -u +%FT%T)" > "$PENDING"
            fi
            ;;
    esac
else
    # Extrahiere FAIL-Zeilen fuer die Fehlermeldung
    FAILS=$(echo "$CHECK_OUTPUT" | grep "FAIL" | head -5 | tr '\n' ' ' | sed 's/"/\\"/g')
    echo "{\"decision\": \"block\", \"reason\": \"Wiki-Check FAIL: ${FAILS}\"}"
fi

exit 0
