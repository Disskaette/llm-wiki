#!/usr/bin/env bash
# guard-pipeline-lock.sh — PreToolUse Hook auf Agent-Dispatches
# Blockiert neue Ingest-Worker-Dispatches solange wiki/_pending.json existiert.
#
# Exit 0 = allow, Exit 2 = deny + stderr.

set -euo pipefail

INPUT=$(cat)

SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')

# Nur Ingest-Worker-Dispatches betrachten
if [ "$SUBAGENT_TYPE" != "bibliothek:ingest-worker" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PENDING="${PROJECT_DIR}/wiki/_pending.json"

# Kein Lock → allow
if [ ! -f "$PENDING" ]; then
  exit 0
fi

# Defensiv parsen — bei kaputtem JSON: durchlassen (lieber laufen als tot sein)
QUELLE=$(jq -r '.quelle // empty' "$PENDING" 2>/dev/null || echo "")
STUFE=$(jq -r '.stufe // empty' "$PENDING" 2>/dev/null || echo "")
PASSED=$(jq -r '.gates_passed // 0' "$PENDING" 2>/dev/null || echo "0")
TOTAL=$(jq -r '.gates_total // 4' "$PENDING" 2>/dev/null || echo "4")

if [ -z "$QUELLE" ] || [ -z "$STUFE" ]; then
  exit 0
fi

cat >&2 << BLOCK_MSG
PIPELINE-LOCK: Neuer Ingest blockiert.

Offene Quelle: ${QUELLE}
Stufe:          ${STUFE}
Gates:          ${PASSED}/${TOTAL}

Handlungsoptionen:
  1. Wenn stufe=gates: laufende Gate-Agents abwarten / fehlende nachdispatchen
  2. Wenn stufe=sideeffects: Phase 4 des /ingest Skills abschliessen
     (PDF sortieren, _index aktualisieren, _log Eintrag, _pending.json loeschen)
  3. Im Notfall: haendisch 'rm wiki/_pending.json' — nur wenn der vorherige
     Ingest abgebrochen wurde und nicht fortgefuehrt wird.
BLOCK_MSG
exit 2
