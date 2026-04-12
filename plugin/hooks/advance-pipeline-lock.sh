#!/usr/bin/env bash
# advance-pipeline-lock.sh — SubagentStop Hook
# Inkrementiert gates_passed-Counter in wiki/_pending.json nach jedem Gate-Agent.
# Bei gates_passed >= gates_total: wechselt stufe auf "sideeffects".
# Optional: INGEST-ID/SYNTHESE-ID Matching gegen _pending.json.quelle.
# Bei Gate-FAIL (Ergebnis: FAIL im Output): Counter wird NICHT inkrementiert.
# Erst Re-Gate mit PASS inkrementiert. Erzwingt Gate-Redispatch maschinell.
# Blockiert nie. Exit 0 immer.

set -euo pipefail

# stdin einmalig lesen (SubagentStop-Event-Daten)
INPUT=$(cat)

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

# PIPELINE-ID-Matching: [INGEST-ID:xxx] oder [SYNTHESE-ID:xxx] im Agent-Output
QUELLE=$(jq -r '.quelle // empty' "$PENDING" 2>/dev/null || echo "")
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")

if [ -n "$LAST_MSG" ]; then
  AGENT_ID=$(echo "$LAST_MSG" | grep -oE '\[(INGEST|SYNTHESE)-ID:[^]]+\]' | head -1 | sed 's/\[.*-ID://;s/\]//' || echo "")
  # Wenn eine ID gefunden wurde UND sie nicht zur offenen Quelle passt: nicht zaehlen
  if [ -n "$AGENT_ID" ] && [ -n "$QUELLE" ] && [ "$AGENT_ID" != "$QUELLE" ]; then
    exit 0
  fi
  # Gate-FAIL-Check: Wenn das Gate FAIL als Ergebnis meldet, Counter NICHT inkrementieren.
  # Erzwingt Re-Gate-Dispatch nach Korrektur. "PASS MIT HINWEISEN" matcht nicht.
  if echo "$LAST_MSG" | grep -q 'Ergebnis:.*FAIL'; then
    exit 0
  fi
fi

PASSED=$(jq -r '.gates_passed // 0' "$PENDING" 2>/dev/null || echo "0")
TOTAL=$(jq -r '.gates_total // 4' "$PENDING" 2>/dev/null || echo "4")

# Defensiv: bei nicht-ganzzahligen Werten abbrechen statt crashen
[[ "$PASSED" =~ ^[0-9]+$ ]] || exit 0
[[ "$TOTAL" =~ ^[0-9]+$ ]] || exit 0

NEW_PASSED=$((PASSED + 1))

TMP="${PENDING}.tmp.$$"

if [ "$NEW_PASSED" -ge "$TOTAL" ]; then
  jq --argjson n "$NEW_PASSED" '.gates_passed = $n | .stufe = "sideeffects"' "$PENDING" > "$TMP" && mv "$TMP" "$PENDING"
else
  jq --argjson n "$NEW_PASSED" '.gates_passed = $n' "$PENDING" > "$TMP" && mv "$TMP" "$PENDING"
fi

exit 0
