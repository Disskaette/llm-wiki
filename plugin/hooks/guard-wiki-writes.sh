#!/usr/bin/env bash
# guard-wiki-writes.sh — PreToolUse Hook fuer Edit|Write
# Blockiert Writes auf wiki/**/*.md wenn kein Bibliothek-Skill in der Session geladen wurde.
# Exit 0 = allow, Exit 2 = deny + stderr.
#
# Pattern orientiert an Website_v2/.claude/hooks/enforce-design-plugin.sh

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Keine Datei? Nicht unser Fall.
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Nicht unter wiki/? Durchlassen.
case "$FILE_PATH" in
  */wiki/*.md) ;;  # weiter
  *) exit 0 ;;
esac

# Transcript laden
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "WIKI-GATE: Transcript nicht lesbar — Wiki-Schutz aktiv. Starte mit /ingest, /synthese, /normenupdate oder /vokabular." >&2
  exit 2
fi

# Wurde ein Bibliothek-Skill in dieser Session via Skill-Tool geladen?
# Zwei-stufig: erst Zeilen mit Skill-Tool-Calls filtern, dann Skill-Name pruefen.
# Verhindert False-Positives wenn "ingest" in Gespraechen/File-Reads vorkommt.
if grep '"name":"Skill"' "$TRANSCRIPT_PATH" 2>/dev/null | grep -qE '"skill":"(bibliothek:)?(ingest|synthese|normenupdate|vokabular|wiki-review)"'; then
  exit 0
fi

cat >&2 << 'BLOCK_MSG'
WIKI-GATE: Direkte Wiki-Writes sind nicht erlaubt.

Wiki-Dateien (wiki/**/*.md) duerfen nur innerhalb eines der vier Schreib-Skills
geaendert werden:

  /ingest          — Neue Quellenseiten aus PDFs
  /synthese        — Konzeptseiten vertiefen
  /normenupdate    — Normseiten aktualisieren
  /vokabular       — _vokabular.md pflegen

Rufe zuerst eines davon auf, dann ist der Write erlaubt.
BLOCK_MSG
exit 2
