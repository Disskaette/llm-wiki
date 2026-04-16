#!/usr/bin/env bash
# guard-dispatch-template.sh — PreToolUse Hook fuer Agent-Dispatches
# Blockiert bibliothek:*-worker Dispatches wenn das zugehoerige
# Dispatch-Template nicht im Transcript gelesen wurde.
# Exit 0 = allow, Exit 2 = deny + stderr.

set -euo pipefail

INPUT=$(cat)

SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')

# Nur Worker-Dispatches betrachten
case "$SUBAGENT_TYPE" in
  bibliothek:ingest-worker)    TEMPLATE="governance/ingest-dispatch-template.md" ;;
  bibliothek:synthese-worker)  TEMPLATE="governance/synthese-dispatch-template.md" ;;
  bibliothek:zuordnung-worker) TEMPLATE="governance/zuordnung-dispatch-template.md" ;;
  *) exit 0 ;;
esac

# Transcript laden
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "DISPATCH-GATE: Transcript nicht lesbar — Template-Pruefung nicht moeglich." >&2
  exit 2
fi

# Pruefe ob das Template in dieser Session gelesen wurde (Read-Tool-Call)
if grep -q "$TEMPLATE" "$TRANSCRIPT_PATH" 2>/dev/null; then
  exit 0
fi

cat >&2 << BLOCK_MSG
DISPATCH-GATE: Template nicht gelesen.

Du dispatcht $SUBAGENT_TYPE ohne vorher das Dispatch-Template zu lesen.
Lies zuerst: $TEMPLATE
Dann fuelle die Platzhalter aus und dispatche erneut.
BLOCK_MSG
exit 2
