#!/usr/bin/env bash
# create-pipeline-lock.sh — SubagentStop Hook fuer Pipeline-Worker
# Erzeugt wiki/_pending.json automatisch nach Worker-Ende.
# Schliesst die Enforcement-Luecke: auch wenn der Orchestrator Phase 3
# ueberspringt, blockiert guard-pipeline-lock.sh den naechsten Dispatch.
#
# Blockiert nie. Exit 0 immer.

set -euo pipefail

INPUT=$(cat)

AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null || echo "")

# Nur Pipeline-Worker betrachten
case "$AGENT_TYPE" in
  bibliothek:ingest-worker)  TYP="ingest";  GATES_TOTAL=4 ;;
  bibliothek:synthese-worker) TYP="synthese"; GATES_TOTAL=3 ;;
  *) exit 0 ;;
esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
WIKI_DIR="${PROJECT_DIR}/wiki"
PENDING="${WIKI_DIR}/_pending.json"

# Kein wiki/ Verzeichnis → nichts tun (Bootstrap noch nicht gelaufen)
if [ ! -d "$WIKI_DIR" ]; then
  exit 0
fi

# Lock existiert bereits → nicht ueberschreiben (defensiv)
if [ -f "$PENDING" ]; then
  exit 0
fi

# Quelle aus Worker-Output extrahieren: [INGEST-ID:xxx] oder [SYNTHESE-ID:xxx]
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")
QUELLE=""

if [ -n "$LAST_MSG" ]; then
  QUELLE=$(echo "$LAST_MSG" | grep -oE '\[(INGEST|SYNTHESE)-ID:[^]]+\]' | head -1 | sed 's/\[.*-ID://;s/\]//' || echo "")
  # .md Suffix entfernen falls vorhanden
  QUELLE="${QUELLE%.md}"
fi

# Fallback wenn kein Marker gefunden
if [ -z "$QUELLE" ]; then
  QUELLE="unbekannt"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -n \
  --arg typ "$TYP" \
  --arg quelle "$QUELLE" \
  --arg ts "$TIMESTAMP" \
  --argjson total "$GATES_TOTAL" \
  '{typ: $typ, stufe: "gates", quelle: $quelle, timestamp: $ts, gates_passed: 0, gates_total: $total}' \
  > "$PENDING"

exit 0
