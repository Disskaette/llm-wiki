#!/usr/bin/env bash
# inject-lock-warning.sh — UserPromptSubmit Hook
# Wenn wiki/_pending.json existiert: injiziere Lock-Hinweis als additionalContext.
# Blockiert nie. Exit 0 immer.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PENDING="${PROJECT_DIR}/wiki/_pending.json"

# Kein Lock? Silent.
if [ ! -f "$PENDING" ]; then
  exit 0
fi

# Lock lesen — defensiv, bei kaputtem JSON exit 0 ohne Output
QUELLE=$(jq -r '.quelle // "unbekannt"' "$PENDING" 2>/dev/null || echo "")
STUFE=$(jq -r '.stufe // "unbekannt"' "$PENDING" 2>/dev/null || echo "")

if [ -z "$QUELLE" ] || [ -z "$STUFE" ]; then
  # Kaputtes JSON — nicht crashen, einfach schweigen
  exit 0
fi

# additionalContext zurueckgeben
jq -n --arg q "$QUELLE" --arg s "$STUFE" '
{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: ("⚠️ Pipeline-Lock offen: Quelle=" + $q + ", Stufe=" + $s + ". Bevor du einen neuen Ingest startest, schliesse die offenen Gates bzw. Nebeneffekte fuer diese Quelle ab.")
  }
}'

exit 0
