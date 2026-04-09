# Obsidian-Setup — Wiki als Vault

## Vault-Root

Das Wiki-Verzeichnis `wiki/` ist der Obsidian-Vault.
Beim ersten `/ingest` (Bootstrap) wird eine `.obsidian/`-Konfiguration angelegt.

## Empfohlene Obsidian-Einstellungen

Diese werden automatisch in `wiki/.obsidian/app.json` gesetzt:

```json
{
  "useMarkdownLinks": false,
  "newLinkFormat": "shortest",
  "strictLineBreaks": true,
  "showFrontmatter": true,
  "readableLineLength": true
}
```

**Erklaerung:**
- `useMarkdownLinks: false` — Wikilinks `[[...]]` statt `[text](url)`
- `newLinkFormat: shortest` — Kuerzester eindeutiger Pfad (funktioniert nur bei eindeutigen Dateinamen)
- `showFrontmatter: true` — YAML-Metadaten sichtbar

## Empfohlene Plugins

| Plugin | Zweck | Installation |
|--------|-------|-------------|
| **Dataview** | SQL-artige Queries auf Frontmatter | Community Plugins → "Dataview" |
| **Graph Analysis** | Erweiterte Graph-Ansicht | Community Plugins → "Graph Analysis" |

### Dataview-Beispielqueries

**Alle Quellen nach Kategorie:**
```dataview
TABLE autor, jahr, kategorie, verarbeitung
FROM "quellen"
SORT kategorie, jahr DESC
```

**Konzepte mit wenig Quellen (Luecken):**
```dataview
TABLE quellen-anzahl, schlagworte
FROM "konzepte"
WHERE quellen-anzahl < 3
SORT quellen-anzahl ASC
```

**Unreviewed Seiten:**
```dataview
LIST
FROM ""
WHERE reviewed = false
SORT file.mtime DESC
```

**Alle Widersprueche:**
```dataview
LIST
FROM ""
WHERE contains(file.content, "[WIDERSPRUCH")
```

## Dateinamen-Regel (NICHT-VERHANDELBAR)

Dateinamen MUESSEN ueber ALLE Wiki-Verzeichnisse hinweg eindeutig sein.
Grund: Obsidian "shortest path" Wikilink-Aufloesung.

- `wiki/konzepte/querkraft.md` und `wiki/moc/querkraft.md` → VERBOTEN (Kollision)
- Wenn gleicher Name noetig: Praefix oder Suffix verwenden
  - `wiki/moc/moc-querkraft.md` (MOC-Praefix)

## Index-Datei-Format

Alle `_index/*.md`-Dateien nutzen einheitliches Tabellenformat:

### _index/quellen.md
```markdown
# Index: Quellen

| Datei | Autor | Jahr | Kategorie | Verarbeitung | Reviewed |
|-------|-------|------|-----------|--------------|----------|
| [[fingerloos-ec2-2016]] | Fingerloos/Hegger | 2016 | Stahlbeton | vollstaendig | false |
```

### _index/konzepte.md
```markdown
# Index: Konzepte

| Datei | Synonyme | Quellen | Erstellt | Reviewed |
|-------|----------|---------|----------|----------|
| [[querkraftuebertragung]] | Querkraft-Fluss | 3 | 2026-04-09 | false |
```

### _index/normen.md
```markdown
# Index: Normen

| Datei | Norm | Abschnitt | Ausgabe | Status | Reviewed |
|-------|------|-----------|---------|--------|----------|
| [[ec2-9-2-5]] | DIN EN 1992-1-1 | 9.2.5 | 2011-01 | gueltig | false |
```

### _index/baustoffe.md
```markdown
# Index: Baustoffe

| Datei | Kategorie | Norm | Reviewed |
|-------|-----------|------|----------|
| [[bsh-gl24h]] | Holz | EN 14080 | false |
```

### _index/verfahren.md
```markdown
# Index: Verfahren

| Datei | Norm-Basis | Anwendung | Reviewed |
|-------|-----------|-----------|----------|
| [[gamma-verfahren]] | EC5 Anhang B | Nachgiebig verbundene Biegetraeger | false |
```
