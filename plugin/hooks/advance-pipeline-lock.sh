#!/usr/bin/env bash
# advance-pipeline-lock.sh — SubagentStop Hook
# Inkrementiert gates_passed-Counter in wiki/_pending.json nach jedem Gate-Agent.
# Bei gates_passed >= gates_total: wechselt stufe auf "sideeffects".
# Blockiert nie. Exit 0 immer.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PENDING="${PROJECT_DIR}/wiki/_pending.json"

# Kein Lock → nichts zu tun
if [ ! -f "$PENDING" ]; then
  exit 0
fi

# Defensiv lesen — bei kaputtem JSON: nichts machen
if ! jq -e . "$PENDING" >/dev/null 2>&1; then
  exit 0
fi

STUFE=$(jq -r '.stufe // empty' "$PENDING" 2>/dev/null || echo "")
if [ "$STUFE" != "gates" ]; then
  # Lock ist schon in sideeffects oder unbekanntem Zustand — nicht anfassen
  exit 0
fi

PASSED=$(jq -r '.gates_passed // 0' "$PENDING" 2>/dev/null || echo "0")
TOTAL=$(jq -r '.gates_total // 4' "$PENDING" 2>/dev/null || echo "4")
NEW_PASSED=$((PASSED + 1))

TMP="${PENDING}.tmp.$$"

if [ "$NEW_PASSED" -ge "$TOTAL" ]; then
  jq --argjson n "$NEW_PASSED" '.gates_passed = $n | .stufe = "sideeffects"' "$PENDING" > "$TMP" && mv "$TMP" "$PENDING"
else
  jq --argjson n "$NEW_PASSED" '.gates_passed = $n' "$PENDING" > "$TMP" && mv "$TMP" "$PENDING"
fi

exit 0
