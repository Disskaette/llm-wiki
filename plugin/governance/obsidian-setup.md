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

Index-Dateien werden pro existierendem Verzeichnis on-demand angelegt
(Core: quellen.md, konzepte.md; Domain: bei Bedarf).
Tabellenformat folgt dem jeweiligen Seitentyp-Schema aus seitentypen.md.

## Graph View Konfiguration

### Standard-Filter

```
-path:quellen/ -path:_index/ -file:_
```

Blendet aus: Quellenseiten, Index-Dateien, Sonderdateien (_log, _vokabular).
Zeigt: Konzepte, Verfahren, Baustoffe, Normen, MOCs.

### Gruppen-Coloring

Graph-View-Queries werden aus den aktiven Seitentypen in seitentypen.md
abgeleitet. Jeder Typ mit eigenem Verzeichnis bekommt eine Farbgruppe:
- Core-Typen (quellen/, konzepte/) → immer sichtbar
- Domain-Typen → nur wenn Verzeichnis existiert

Attachments-Toggle: AUS — damit PDFs nicht im Graph erscheinen.

### Local Graph

Fuer taegliche Arbeit wichtiger als globaler Graph.
Rechte Sidebar → "Open local graph". Zeigt Nachbarn der aktuell geoeffneten Seite.
Tiefe konfigurierbar (1-3 Hops).

## MOC-Hierarchie

Zweistufig nach LYT-Pattern (Nick Milo):
- `wiki/home.md` als Vault-Einstieg (Default Open File)
- Top-MOCs (Fachbereiche): interaktiv mit Nutzer erarbeitet, nicht hartcodiert
- Sub-MOCs (Themen): verlinken auf Konzept-/Verfahrensseiten
- Konzeptseiten duerfen in mehreren MOCs auftauchen

Obsidian-Config: `"defaultOpenFile": "home"` in `.obsidian/app.json`
