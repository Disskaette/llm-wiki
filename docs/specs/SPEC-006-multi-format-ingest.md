# SPEC-006: Multi-Format-Ingest — PDF, Markdown, URL

**Status:** Planned
**Version:** 1.0
**Erstellt:** 2026-04-13
**Aktualisiert:** 2026-04-13

## Zusammenfassung

Der Ingest-Skill wird von reinem PDF-Input auf drei Quellformate erweitert:
PDF, Markdown und URL. Phase 0 erkennt das Format automatisch und waehlt die
passende Lese-Strategie. Der Rest der Pipeline (Quellenseite, Gates,
Nebeneffekte) bleibt identisch — die Quelle ist gelesen, egal wie.

## Voraussetzung

SPEC-005 (Domain-Agnostik) muss umgesetzt sein. Insbesondere:
- Dynamische Kategorien (gelten fuer alle Formate)
- Domain-agnostische Dispatch-Templates (keine PDF-spezifischen Formulierungen)
- Generalisiertes Bootstrap (pdfs/ → quellen-dateien/ oder Format-agnostisch)

## Anforderungen

1. Format-Erkennung in Phase 0 (Extension + Content-Sniffing)
2. Lese-Strategie pro Format (Read-Pages vs. Read-Direkt vs. WebFetch)
3. Beleg-/Link-Format pro Quelltyp im Wiki-Text
4. Frontmatter-Feld fuer Quellpfad (generalisiert, nicht nur pdf:)
5. Split-Trigger pro Format angepasst
6. Gate-Anpassungen (Spot-Check unterschiedlich je nach Format)
7. Rueckwaertskompatibilitaet mit bestehenden PDF-Quellenseiten

## Technische Details

### Format-Erkennung (Phase 0, Schritt 1)

| Signal | Format | Lese-Strategie |
|--------|--------|----------------|
| `.pdf` Extension | PDF | Read-Tool mit `pages` Parameter |
| `.md` Extension | Markdown | Read-Tool direkt (kein Seiten-Konzept) |
| `http://` oder `https://` Prefix | URL | WebFetch (HTML → Text) |
| `.epub` Extension | EPUB | Zukunft — Phase 0 meldet "Format nicht unterstuetzt" |
| Alles andere | Unbekannt | Phase 0 meldet "Format nicht erkannt" + Abbruch |

Erkennung ist deterministisch (Extension/Prefix), kein Content-Sniffing noetig.

### Lese-Strategien

#### PDF (bestehendes Verhalten, angepasst)

- Read-Tool mit `pages` Parameter fuer seitenweises Lesen
- Split-Ingest bei >10 MB Dateigroesse (API-Request-Size-Limit)
- Seitenangaben im Wiki-Text: `(S. 42)`, `(S. 42-48)`
- Beleg-Wikilink: `[[datei.pdf#page=42|Autor Jahr, S. 42]]`

#### Markdown

- Read-Tool direkt auf die gesamte Datei
- Kein Seiten-Konzept → Seitenangaben entfallen
- Stattdessen: Abschnitts-Referenzen `(Abschnitt "Titel")` oder Zeilenbereiche
- Split-Ingest bei >500 KB Dateigroesse (grosse Markdown-Dateien, selten)
- Beleg-Wikilink: `[[datei.md#heading|Autor Jahr, Abschnitt "Titel"]]`
  (Obsidian unterstuetzt #heading-Links in Markdown)
- `kapitel-index:` im Frontmatter: `seiten:` wird zu `abschnitt:` (Heading-basiert)

#### URL

- WebFetch-Tool zum Laden der Seite
- HTML wird als Text extrahiert (kein Rendering noetig)
- Kein Split (Webseiten sind selten >500 KB Text)
- Seitenangaben entfallen — Abschnitts-Referenzen wenn Seite Headings hat
- Beleg: `[Titel](url)` (Standard-Markdown-Link, kein Wikilink — externe Ressource)
- Zusaetzliches Frontmatter-Feld: `abgerufen: 2026-04-13` (Datum des Fetches)
- `kapitel-index:` optional (manche Webseiten haben keine klare Struktur)
- Risiko: URL kann sich aendern oder verschwinden → Hinweis in Quellenseite

### Frontmatter: Quellpfad generalisiert

Aktuell:
```yaml
pdf: "[[pdfs/holzbau/datei.pdf]]"
```

Neu — drei moegliche Felder, genau eines gesetzt:
```yaml
# PDF-Quelle:
pdf: "[[pdfs/kategorie/datei.pdf]]"

# Markdown-Quelle:
quelle-datei: "[[quellen-dateien/kategorie/datei.md]]"

# URL-Quelle:
url: "https://example.com/artikel"
abgerufen: 2026-04-13
```

Begruendung fuer getrennte Felder statt eines generischen `quelle-pfad:`:
- `pdf:` hat Obsidian-spezifisches Verhalten (Klick oeffnet PDF-Viewer)
- `url:` ist kein Obsidian-interner Link
- Dataview-Queries koennen nach Format filtern (`WHERE pdf != null`)
- Rueckwaertskompatibel: bestehende `pdf:`-Felder bleiben gueltig

### Dateiablage

| Format | Ablage | Bemerkung |
|--------|--------|-----------|
| PDF | `wiki/pdfs/<kategorie>/` | Wie bisher |
| Markdown | `wiki/quellen-dateien/<kategorie>/` | Neues Verzeichnis, analog zu pdfs/ |
| URL | Keine Dateiablage | URL im Frontmatter reicht |

`quellen-dateien/` wird beim ersten Markdown-Ingest angelegt (on-demand,
konsistent mit SPEC-005 Domain-Verzeichnis-Logik).

### Split-Trigger pro Format

| Format | Trigger | Begruendung |
|--------|---------|-------------|
| PDF | >10 MB Dateigroesse | API-Request-Size-Limit + base64-Overhead |
| Markdown | >500 KB Dateigroesse | Selten noetig, aber grosse .md-Dateien existieren |
| URL | Kein Split | Webseiten selten gross genug |

### Gate-Anpassungen

#### Gate 1 (Vollstaendigkeits-Pruefer)

| Format | Pruefung |
|--------|----------|
| PDF | Inhaltsverzeichnis gegen kapitel-index (wie bisher) |
| Markdown | Headings gegen kapitel-index (## und ### Ebene) |
| URL | Reduziert: Hauptinhalt erfasst? (keine strenge Kapitelstruktur erwartet) |

#### Gate 2 (Quellen-Pruefer)

| Format | Spot-Check |
|--------|------------|
| PDF | 5 zufaellige Seitenangaben gegen PDF verifizieren (wie bisher) |
| Markdown | 5 zufaellige Abschnitts-Referenzen gegen Datei verifizieren |
| URL | WebFetch erneut + 3 Stichproben pruefen (URL kann sich geaendert haben) |

#### Gate 3 + 4

Keine format-spezifischen Aenderungen — Konsistenz und Vokabular sind
inhaltsbasiert, nicht formatbasiert.

### Dispatch-Template Aenderungen

Neuer Platzhalter: `{{QUELLEN_FORMAT}}` (pdf, markdown, url)
Neuer Platzhalter: `{{QUELLEN_PFAD}}` (ersetzt {{PDF_PFAD}} nicht — ergaenzt)

Worker erhaelt Format-Info und passt Lese-Strategie an:
```
Quellen-Format: {{QUELLEN_FORMAT}}
Quellen-Pfad:   {{QUELLEN_PFAD}}

Lese-Strategie:
- pdf: Read-Tool mit pages-Parameter, jede Seite
- markdown: Read-Tool direkt, gesamte Datei
- url: WebFetch-Tool, HTML als Text
```

{{PDF_PFAD}} bleibt als Alias fuer Rueckwaertskompatibilitaet wenn
Format = pdf.

### Ingest SKILL.md Aenderungen

Phase 0 wird erweitert:

```
1. Quelle lokalisieren:
   - Expliziter Pfad/URL angegeben → Format aus Extension/Prefix ableiten
   - Kein Pfad → wiki/pdfs/neu/ UND wiki/quellen-dateien/neu/ scannen
   - Format bestimmen (PDF/Markdown/URL)
   - Existiert die Quelle? (Datei vorhanden / URL erreichbar?)
   - Bei URL: WebFetch-Test (erreichbar? Text extrahierbar?)
   - Bei PDF: Text extrahierbar? (wie bisher)
   - Bei Markdown: Read-Test (lesbar?)
   - Groesse/Seitenzahl ermitteln
```

Phase 0.6 (Dispatch):
```
3. Modellwahl:
   - PDF >200 Seiten → Opus
   - PDF ≤200 Seiten → Sonnet
   - PDF >10 MB → Split-Ingest
   - Markdown >500 KB → Split-Ingest
   - Markdown ≤500 KB → Sonnet (meist kurz genug)
   - URL → Sonnet (Webseiten sind kompakt)
```

### Naming-Konvention Erweiterung

Beleg-Link-Typen werden von 3 auf 5 erweitert:

| Nr | Typ | Format | Syntax |
|----|-----|--------|--------|
| 1 | PDF-Beleg | PDF | `[[datei.pdf#page=N\|Autor Jahr, S. N]]` |
| 2 | Fachbegriff | Alle | `[[konzeptname\|Anzeigename]]` |
| 3 | Normverweis | Alle | `[[normseite\|Norm, Abschnitt X.Y]]` |
| 4 | Markdown-Beleg | Markdown | `[[datei.md#heading\|Autor Jahr, Abschnitt "Titel"]]` |
| 5 | URL-Beleg | URL | `[Titel](url)` (externer Link) |

## Akzeptanzkriterien

- [ ] Phase 0 erkennt PDF, Markdown und URL korrekt
- [ ] Markdown-Quelle wird vollstaendig gelesen und als Quellenseite verarbeitet
- [ ] URL-Quelle wird via WebFetch gelesen und als Quellenseite verarbeitet
- [ ] Beleg-Links verwenden das richtige Format pro Quelltyp
- [ ] Frontmatter hat `pdf:`, `quelle-datei:` oder `url:` + `abgerufen:` je nach Format
- [ ] Split-Trigger funktioniert fuer PDF (10 MB) und Markdown (500 KB)
- [ ] Gate 1 passt Vollstaendigkeitspruefung an Format an
- [ ] Gate 2 Spot-Check funktioniert fuer alle 3 Formate
- [ ] Bestehende PDF-Quellenseiten bleiben gueltig (pdf: Feld unveraendert)
- [ ] Dispatch-Template hat {{QUELLEN_FORMAT}} und {{QUELLEN_PFAD}}
- [ ] naming-konvention.md dokumentiert 5 Link-Typen
- [ ] Alle bestehenden Tests PASS

## Edge Cases

| Situation | Verhalten |
|---|---|
| URL nicht erreichbar | Phase 0 meldet Fehler, kein Ingest. Retry-Option anbieten |
| URL liefert nur JavaScript (SPA) | Phase 0 meldet "Kein Text extrahierbar", Abbruch |
| Markdown-Datei ist eigentlich ein Export (>5 MB) | Split-Ingest ab 500 KB |
| PDF ohne Text (Scan ohne OCR) | Wie bisher: nach pdfs/unlesbar/ verschieben |
| Gemischte Quellen im selben Ingest-Batch | Jede Quelle einzeln, Format pro Quelle |
| URL aendert sich nach Ingest | Quellenseite hat `abgerufen:` Datum, wiki-review kann pruefen |
| Markdown mit Wikilinks (Obsidian-Export) | Worker behandelt als Content, nicht als Steuerung |

## Abhaengigkeiten

- SPEC-005 (Domain-Agnostik) muss abgeschlossen sein
- WebFetch-Tool muss verfuegbar sein (ist Standard in Claude Code)
