#!/usr/bin/env bash
# sync-cache.sh — Synchronisiert Plugin-Dateien in den Claude-Code-Cache
# Aufruf: bash scripts/sync-cache.sh
# Nach Hook-Änderungen ausführen, dann Session neustarten.

set -e

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$HOME/.claude/plugins/cache/llm-wiki-local/bibliothek/1.1.0"

if [ ! -d "$CACHE" ]; then
    echo "Cache-Verzeichnis nicht gefunden: $CACHE"
    echo "Plugin zuerst installieren: claude plugin install ."
    exit 1
fi

# Nur Plugin-Dateien synchronisieren (kein .git, docs, tests)
for dir in hooks skills agents governance commands scripts .claude-plugin; do
    if [ -d "$SRC/$dir" ]; then
        rm -rf "$CACHE/$dir"
        cp -R "$SRC/$dir" "$CACHE/$dir"
    fi
done

for file in CLAUDE.md ARCHITECTURE.md; do
    [ -f "$SRC/$file" ] && cp "$SRC/$file" "$CACHE/$file"
done

echo "Cache synchronisiert: $(find "$CACHE" -type f | wc -l) Dateien"
echo "→ Session neustarten damit Hooks greifen"
