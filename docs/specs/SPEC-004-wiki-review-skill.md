# SPEC-004: Wiki-Review-Skill

**Status:** Done
**Version:** 1.0
**Erstellt:** 2026-04-11
**Aktualisiert:** 2026-04-11

## Zusammenfassung

Neuer Skill `/wiki-review` fuer semantische Analyse des bestehenden Wikis.
Prueft inhaltliche Qualitaet, Abdeckung und Standard-Drift — ergaenzt
`/wiki-lint` (technisch) und `/katalog` (Navigation).

Zweistufig: Quick-Scan zuerst, bei Befund Full-Audit als Batch.

## Abgrenzung

| Skill | Fokus | Output |
|---|---|---|
| `/wiki-lint` | Technisch — kaputte Links, fehlende Felder, Marker | PASS/FAIL pro Check |
| `/katalog` | Navigation — was haben wir, was fehlt | Bestandsliste |
| `/wiki-review` | Semantisch — Qualitaet, Abdeckung, Drift | Verbesserungsplan mit Prioritaeten |

## Kern-Designprinzip: Self-Referential

<NICHT-VERHANDELBAR>
Der Review-Skill liest die AKTUELLEN Plugin-Dateien um den Standard zu bestimmen.
Er hardcoded NICHTS. Wenn sich Templates aendern, aendert sich automatisch was
der Review als "korrekt" betrachtet.

Quellen fuer den aktuellen Standard:
1. `governance/synthese-dispatch-template.md` → Konzeptseiten-Struktur + Frontmatter-Felder
2. `governance/ingest-dispatch-template.md` → Quellenseiten-Struktur + Frontmatter-Felder
3. `governance/naming-konvention.md` → Dateinamen + Link-Konventionen
4. `governance/hard-gates.md` → Welche Gates gelten
5. `hooks/config/valid-types.txt` → Erlaubte Seitentypen
6. `hooks/check-wiki-output.sh` → Deterministische Checks (12 Stueck)

Der Skill extrahiert Pflicht-Felder, Struktur-Reihenfolge und Konventionen
aus diesen Dateien und vergleicht dann die Wiki-Seiten dagegen.
</NICHT-VERHANDELBAR>

## Zweistufiger Ablauf

### Zwei Pruef-Layer

**Entscheidende Unterscheidung:** Obsidian-Strukturelles muss EXHAUSTIV geprueft werden
(eine kaputte Verlinkung oder ein fehlendes Frontmatter-Feld bricht Dataview/Graph fuer alle).
Inhaltsqualitaet kann stichprobenartig geprueft werden.

| Layer | Pruefumfang | Warum |
|---|---|---|
| **Obsidian-Layer** | JEDE Seite | Frontmatter-Schema, Link-Syntax, Dateinamen-Konventionen, Graph-Konnektivitaet — Inkonsistenzen brechen Dataview-Queries und Graph View |
| **Content-Layer** | Stichprobe 5-10 pro Typ | Struktur-Reihenfolge, Quellenqualitaet, Review-Freshness — Qualitaetsmessung, nicht Strukturintegritaet |

### Stufe 1: Quick-Scan (immer)

**Ziel:** In 2-5 Minuten feststellen ob das Wiki strukturell konsistent ist
und inhaltlich im Grossen und Ganzen passt.

**Phase 0: Governance laden**
- Aktuelle Templates lesen, Pflicht-Felder + Soll-Struktur extrahieren

**Phase 1: Obsidian-Layer (EXHAUSTIV — jede Seite)**

Alle `.md`-Dateien in `wiki/` durchlaufen:

1. **Frontmatter-Schema:**
   - Pflicht-Felder vorhanden? (aus Template dynamisch extrahiert)
   - `type:` Wert gueltig? (aus config/valid-types.txt)
   - Feldtypen korrekt? (Arrays als Arrays, Dates als Dates)
   - Unbekannte Felder? (nicht im Template → melden, nicht blockieren)

2. **Link-Integrität:**
   - Jeder `[[...]]` Wikilink aufloesbar? (Datei existiert)
   - Link-Syntax korrekt? (3 Typen: PDF-Beleg, Konzept, Quellenseite)
   - Keine gemischten Formate? (z.B. Markdown-Links `[text](url)` statt Wikilinks)
   - PDF-Links mit `#page=N` → PDF existiert im Vault?

3. **Dateinamen-Konventionen:**
   - Lowercase ASCII + Bindestriche?
   - Keine Umlaute in Dateinamen?
   - Eindeutigkeit ueber alle Verzeichnisse? (Obsidian Shortest-Path)
   - Kein Namens-Kollision zwischen Verzeichnissen?

4. **Graph-Konnektivitaet:**
   - Waisen-Seiten? (keine eingehenden Links)
   - Sackgassen? (keine ausgehenden Links bei Konzeptseiten)
   - MOC-Abdeckung? (Konzepte ohne MOC-Zuordnung)

5. **Dataview-Kompatibilitaet:**
   - `schlagworte:` als Array (nicht String)?
   - `mocs:` als Array?
   - `reviewed:` als boolean oder ISO-Datum (nicht String "ja")?

**Phase 2: Content-Layer (STICHPROBE — 15 Seiten, gemischt ueber Typen)**

Zufaellige Seiten ziehen und pruefen:
- H2-Reihenfolge gegen Template-Soll
- Quellenanzahl pro Konzeptseite
- Wikilink-Dichte (Links pro Absatz)
- Widerspruchs-Marker: Obsidian Callout-Syntax oder Plaintext?
- `check-wiki-output.sh` laufen lassen
- `reviewed:` Alter

**Phase 3: Meta-Konsistenz**
- `_log.md`: Offene Marker? (`[INGEST UNVOLLSTAENDIG]`, `[SYNTHESE UNVOLLSTAENDIG]`)
- `_index/`: Eintraege ohne zugehoerige Seite? Seiten ohne Index-Eintrag?
- `_pending.json`: Verwaist? (Lock offen aber kein aktiver Ingest/Synthese)
- `_vokabular.md`: Terme definiert aber nie verwendet? Terme in Frontmatter aber nicht definiert?
  (Check 03 prueft pro Seite — hier aggregiert ueber das ganze Wiki)

**Phase 4: Abdeckungs-Check**
- Konzept-Kandidaten mit >=2 Quellen ohne eigene Seite
- Quellenseiten ohne Konzeptseiten-Verlinkung

**Phase 5: Ergebnis melden**

```markdown
## Quick-Scan: 2026-04-15

### Obsidian-Integritaet (exhaustiv, N Seiten)
- Frontmatter: X/N vollstaendig, Y fehlende Felder
- Links: X/N aufloesbar, Y gebrochen
- Dateinamen: X/N konform, Y Verstoesse
- Graph: X Waisen, Y Sackgassen
- Dataview: X/N kompatibel

### Content-Qualitaet (Stichprobe, M Seiten)
- Struktur: X/M aktuelle Reihenfolge
- Quellen: Durchschnitt N pro Konzeptseite
- Reviews: X ueberfaellig

### Empfehlung
[Alles OK] / [Full-Audit empfohlen: N Obsidian-Probleme + M Content-Drift]
```

**Schwellwert fuer Stufe 2:**
- Obsidian-Layer: JEDER Fund → Full-Audit fuer betroffene Kategorie
  (ein gebrochener Link ist einer zu viel)
- Content-Layer: Stichprobe 15 Seiten, >=2 mit gleichem Drift-Muster
  → Full-Audit empfehlen (ein Einzelfund ist Ausreisser, zwei sind Muster)

### Stufe 2: Full-Audit (auf Vorschlag, batchweise)

**Ziel:** Kategorisierte Befunde + konkreter Migrationsplan.

**Ausloeser:** Nutzer stimmt zu ODER Obsidian-Layer hat Befunde.

1. **Batch-Strategie** — Wiki nach Verzeichnis aufteilen:
   - Batch 1: `wiki/quellen/` (alle Quellenseiten)
   - Batch 2: `wiki/konzepte/` (alle Konzeptseiten)
   - Batch 3: `wiki/normen/` + `wiki/verfahren/` + `wiki/baustoffe/`
   - Batch 4: `wiki/_index/` + MOCs + Sonderdateien
   Pro Batch: Report generieren, dann naechster Batch.
   Grund: Token-Budget. 50 Seiten × 500 Zeilen = 25K Zeilen → Split noetig.

2. **Pro Seite pruefen (Obsidian + Content komplett):**
   - **Frontmatter-Drift:** Fehlende Pflicht-Felder (aus aktuellem Template)
   - **Link-Drift:** Falsche Syntax, gebrochene Links, fehlende Aliases
   - **Struktur-Drift:** H2-Reihenfolge gegen Template
   - **Konventions-Drift:** Dateinamen, Umlaut-Handling
   - **Inhalts-Qualitaet:** Quellenanzahl, Wikilink-Dichte, offene Marker
   - **Review-Alter:** `reviewed: false` seit wann?

3. **Befunde kategorisieren:**

   | Kategorie | Behebbar | Beispiel |
   |---|---|---|
   | **Obsidian-Fix** | Automatisch (Frontmatter, Links) | `materialgruppe:` fehlt, Link-Alias korrigieren |
   | **Restrukturierung** | Semi-automatisch (/synthese) | Randbedingungen nach statt vor Formeln |
   | **Inhaltslücke** | Manuell (/ingest, /synthese) | Konzept hat nur 1 Quelle |
   | **Veraltet** | Review noetig | `reviewed: false` seit >30 Tagen |

4. **Migrationsplan generieren:**

   ```markdown
   ## Full-Audit Report: 2026-04-15

   ### Befund-Uebersicht
   - 45 Seiten geprueft
   - 12 Migrationen (automatisch behebbar)
   - 5 Restrukturierungen (Synthese noetig)
   - 3 Inhaltsluecken (Ingest/Synthese noetig)
   - 8 Reviews ueberfaellig

   ### Migration-Batch (automatisch — vorgeschlagene Aktion)
   Die folgenden 12 Seiten brauchen nur Frontmatter-Ergaenzungen.
   Soll ich das als Batch durchfuehren? (Schreibt via /synthese oder direkt)
   
   | Seite | Fehlend | Aktion |
   |---|---|---|
   | quellen/fingerloos-ec2.md | materialgruppe | Ergaenze: `materialgruppe: Stahlbeton` |
   | konzepte/querkraft.md | versagensart, Callout-Syntax | `/synthese querkraft` (Re-Synthese) |
   | ... | ... | ... |

   ### Restrukturierungen (manuell — Nutzer entscheidet)
   | Seite | Problem | Vorschlag |
   |---|---|---|
   | konzepte/biegung.md | Randbedingungen nach Formeln | `/synthese biegung` mit aktualisiertem Template |

   ### Inhaltsluecken
   | Konzept-Kandidat | Quellen | Vorschlag |
   |---|---|---|
   | Durchstanzen | 3 Quellen | `/synthese durchstanzen` |

   ### Naechste Schritte
   1. Migration-Batch ausfuehren? (12 Seiten, ~5 Min)
   2. Re-Synthese fuer 5 Seiten einplanen?
   3. Reviews fuer 8 Seiten terminieren?
   ```

## Technische Details

### Self-Referential-Extraktion

Der Skill extrahiert den Standard dynamisch:

```
Phase 0: Governance laden
1. Read governance/synthese-dispatch-template.md
   → Regex auf "Frontmatter (alle Felder PFLICHT):" Block
   → Extrahiere Feldnamen zwischen --- Markern
   → Ergebnis: PFLICHT_FELDER_KONZEPT = [type, title, synonyme, schlagworte, 
     materialgruppe, versagensart, mocs, quellen-anzahl, created, updated, 
     synth-datum, reviewed]

2. Read governance/ingest-dispatch-template.md
   → Analog: PFLICHT_FELDER_QUELLE = [type, title, autor, ausgabe, ...]

3. Read governance/synthese-dispatch-template.md
   → Regex auf "Body-Struktur" Block
   → Extrahiere H2-Headers in Reihenfolge
   → Ergebnis: SOLL_REIHENFOLGE = [Zusammenfassung, Einsatzgrenzen, 
     Formeln, Zahlenwerte, Norm-Referenzen, Widersprueche, 
     Verwandte Konzepte, Quellen]

4. Read hooks/config/valid-types.txt
   → VALID_TYPES = [quelle, konzept, norm, baustoff, verfahren, moc]
```

### Gate-Agents
- Kein eigener Gate — `/wiki-review` ist read-only
- Nutzt `check-wiki-output.sh` als Basis-Check pro Seite
- Eigene Analyse-Logik im Skill selbst

### Output + Report-Historie
- Stufe 1: Chat-Output (kein File)
- Stufe 2: `wiki/_reviews/review-YYYY-MM-DD.md` als persistenter Report
  (datiert, nicht ueberschrieben — Verlauf bleibt erhalten)
- `wiki/_reviews/` Verzeichnis wird beim ersten Full-Audit angelegt

### Ausloeser
- **Manuell:** Nutzer ruft `/wiki-review` auf
- **Session-Start (using-bibliothek):** Governance-Hub prueft automatisch:
  1. Kein `wiki/_reviews/` → "Noch kein Review. `/wiki-review` empfohlen?"
  2. Letzter Review >3 Ingests oder >14 Tage her → "Review empfohlen"
  3. Sonst → Schweigen (kein Hinweis)
- **Kein Timer/Cron:** Laeuft nur wenn aufgerufen, wird aber proaktiv erfragt.

### Kein Pipeline-Lock noetig
- `/wiki-review` liest nur, schreibt nicht in wiki/ (ausser _reviews/)
- guard-wiki-writes.sh hat `/wiki-review` als erlaubten Skill
  (fuer Report-Write in wiki/_reviews/)

## Akzeptanzkriterien

### Obsidian-Layer (exhaustiv)
- [ ] Frontmatter-Schema gegen aktuelles Template geprueft (JEDE Seite)
- [ ] Link-Integritaet: jeder Wikilink aufloesbar (JEDE Seite)
- [ ] Dateinamen-Konventionen: lowercase ASCII, keine Kollisionen (JEDE Seite)
- [ ] Graph-Konnektivitaet: Waisen + Sackgassen gemeldet
- [ ] Dataview-Kompatibilitaet: Feldtypen korrekt (Arrays, Dates, Booleans)

### Meta-Konsistenz
- [ ] _log.md: Offene Marker erkannt
- [ ] _index: Eintraege vs. Seiten abgeglichen
- [ ] _pending.json: Verwaiste Locks erkannt
- [ ] _vokabular.md: Unbenutzte Terme + fehlende Terme aggregiert

### Content-Layer (Stichprobe 15 Seiten)
- [ ] Struktur-Reihenfolge gegen Template
- [ ] Widerspruchs-Marker: Callout-Syntax vs. Plaintext erkannt

### Self-Referential
- [ ] Pflicht-Felder dynamisch aus Templates extrahiert (nicht hardcoded)
- [ ] Struktur-Reihenfolge dynamisch aus Template extrahiert
- [ ] valid-types.txt als Quelle fuer Seitentypen

### Ablauf
- [ ] Stufe 1 laeuft in <5 Minuten auf 50-Seiten-Wiki
- [ ] Obsidian-Fund → automatisch Full-Audit fuer betroffene Kategorie empfehlen
- [ ] Content-Drift: >=2 gleiche Muster in Stichprobe → Full-Audit empfehlen
- [ ] Stufe 2 arbeitet batchweise (pro Verzeichnis)
- [ ] Migrationsplan mit konkreten Skill-Aufrufen
- [ ] Obsidian-Fixes als automatischen Batch vorschlagen
- [ ] Reports in wiki/_reviews/review-YYYY-MM-DD.md (datiert, nicht ueberschrieben)

## Abhaengigkeiten

- SPEC-003 (Synthese-Enforcement) → Done
- Frontmatter-Felder `materialgruppe`, `versagensart` → Done (in Templates)
- `guard-wiki-writes.sh` muss `/wiki-review` als erlaubten Skill fuehren
  (fuer _review-report.md Write)

## Edge Cases

- Leeres Wiki → "Wiki ist leer, starte mit /ingest"
- Wiki mit nur Quellenseiten → Abdeckungs-Analyse betonen, Konzept-Kandidaten listen
- Sehr grosses Wiki (500+) → Obsidian-Layer ist exhaustiv aber lightweight (nur Frontmatter + Links), Content-Layer sampelt
- Template hat sich seit letztem Ingest geaendert → genau dafuer ist der Drift-Check da
- _pending.json offen waehrend Review → melden, nicht loeschen (Review ist read-only)
- _log.md mit offenem Marker → melden + Link zum letzten Ingest-Eintrag
- Vokabular-Term in 0 Seiten verwendet → melden als "potentiell veraltet" (nicht loeschen)
- Review waehrend laufendem Ingest → harmlos (read-only), aber Ergebnis kann verrauscht sein
