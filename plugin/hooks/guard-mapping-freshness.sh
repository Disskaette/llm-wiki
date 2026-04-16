#!/usr/bin/env bash
# guard-mapping-freshness.sh — PreToolUse Hook auf Agent-Dispatch
# Blockiert Synthese-Worker wenn _quellen-mapping.md veraltet ist.
# Exit 0 = allow, Exit 2 = deny + stderr.

set -euo pipefail

INPUT=$(cat)

SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')

# Nur Synthese-Worker betrachten
case "$SUBAGENT_TYPE" in
  bibliothek:synthese-worker) ;;
  *) exit 0 ;;
esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
WIKI_DIR="${PROJECT_DIR}/wiki"
MAPPING="${WIKI_DIR}/_quellen-mapping.md"

# Kein wiki/ → durchlassen (Bootstrap noch nicht gelaufen)
if [ ! -d "$WIKI_DIR" ]; then
  exit 0
fi

# Kein Mapping → blockieren
if [ ! -f "$MAPPING" ]; then
  echo "MAPPING-GATE: Kein Quellen-Mapping vorhanden. Erst /zuordnung ausfuehren." >&2
  exit 2
fi

# Quellen zaehlen
QUELLEN_AKTUELL=$(find "$WIKI_DIR/quellen" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
QUELLEN_MAPPING=$(awk '/^---$/{n++; next} n==1 && /^quellen-stand:/{gsub(/^quellen-stand: */,""); print; exit}' "$MAPPING")
QUELLEN_MAPPING="${QUELLEN_MAPPING:-0}"

# Konzepte zaehlen
KONZEPTE_AKTUELL=$(find "$WIKI_DIR/konzepte" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
KONZEPTE_MAPPING=$(awk '/^---$/{n++; next} n==1 && /^konzepte-stand:/{gsub(/^konzepte-stand: */,""); print; exit}' "$MAPPING")
KONZEPTE_MAPPING="${KONZEPTE_MAPPING:-0}"

DELTA_Q=$((QUELLEN_AKTUELL - QUELLEN_MAPPING))
DELTA_K=$((KONZEPTE_AKTUELL - KONZEPTE_MAPPING))

if [ "$DELTA_Q" -gt 0 ] || [ "$DELTA_K" -gt 0 ]; then
  cat >&2 << BLOCK_MSG
MAPPING-GATE: Quellen-Zuordnung veraltet.

Quellen:  $QUELLEN_AKTUELL aktuell, $QUELLEN_MAPPING im Mapping (+$DELTA_Q)
Konzepte: $KONZEPTE_AKTUELL aktuell, $KONZEPTE_MAPPING im Mapping (+$DELTA_K)

Erst /zuordnung ausfuehren, dann /synthese.
BLOCK_MSG
  exit 2
fi

exit 0
