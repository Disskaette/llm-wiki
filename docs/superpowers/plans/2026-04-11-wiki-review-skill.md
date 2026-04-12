# Wiki-Review-Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Neuer `/wiki-review` Skill der das bestehende Wiki gegen aktuelle Plugin-Standards prueft — Obsidian-Layer exhaustiv, Content-Layer als Stichprobe, zweistufig mit Full-Audit bei Befund.

**Architecture:** Reiner Prompt-Skill (SKILL.md) — kein Shell-Hook, kein Agent. Liest Governance-Dateien dynamisch (self-referential), prueft Wiki-Seiten, gibt Report aus. Stufe 2 schreibt Report nach `wiki/_reviews/`. Guard-wiki-writes.sh erlaubt bereits `/wiki-review`.

**Tech Stack:** SKILL.md (Prompt), command.md (Routing), check-wiki-output.sh (Basis-Checks)

**Spec:** `docs/specs/SPEC-004-wiki-review-skill.md`

---

### Task 1: Command-Datei anlegen

**Files:**
- Create: `plugin/commands/wiki-review.md`

- [ ] **Step 1: Command-Datei schreiben**

```markdown
---
name: wiki-review
description: "Wiki-Review — Obsidian-Integritaet, Content-Drift, Abdeckungsanalyse, Migrationsplan"
---

# /wiki-review — Semantische Wiki-Analyse + Verbesserungsplan

**Kurzbeschreibung:** Zweistufiger Review — Quick-Scan (Obsidian exhaustiv + Content Stichprobe) mit optionalem Full-Audit bei Befund. Self-referential: liest aktuelle Templates um den Standard zu bestimmen.

**Ausloeser:**
- "Review", "Audit", "Stimmt die Wiki noch?", "Ist alles aktuell?"
- Session-Start Hinweis (using-bibliothek) wenn >3 Ingests oder >14 Tage seit letztem Review

**Skill:** → `skills/wiki-review/SKILL.md`

**Aktive Gates:** Keine (read-only Skill, diagnostisch)
```

- [ ] **Step 2: Verifiziere dass check-consistency.sh Check 04 noch passt**

Run: `bash plugin/hooks/check-consistency.sh plugin/`
Expected: 19/19 PASS (8 commands excl. using-bibliothek == 8 skill dirs excl. using-bibliothek)

Achtung: Schlaegt fehl bis Task 2 (SKILL.md) auch angelegt ist. Daher Task 1 + 2 zusammen committen.

---

### Task 2: SKILL.md — Governance-Vertrag + Phase 0 (Standard-Extraktion)

**Files:**
- Create: `plugin/skills/wiki-review/SKILL.md`

- [ ] **Step 1: Verzeichnis anlegen**

```bash
mkdir -p plugin/skills/wiki-review
```

- [ ] **Step 2: SKILL.md Kopf + Governance-Vertrag schreiben**

```markdown
---
name: wiki-review
description: "Wiki-Review — Obsidian-Integritaet, Content-Drift, Abdeckungsanalyse, Migrationsplan"
---

## Governance-Vertrag

> Wiki-Review ist ein diagnostischer Skill. Er prueft das bestehende Wiki
> gegen aktuelle Plugin-Standards und generiert Verbesserungsplaene.
> Er ist read-only — schreibt nur den Report nach wiki/_reviews/.

| Gate | Durchsetzung | Wie |
|------|-------------|-----|
| KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG | ⚪ N/A | Review liest keine PDFs |
| KEIN-INHALT-OHNE-SEITENANGABE | ⚪ N/A | Review prueft, modifiziert nicht |
| KEIN-ZAHLENWERT-OHNE-QUELLE | ⚪ N/A | Review prueft, modifiziert nicht |
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | ⚪ N/A | Review prueft, modifiziert nicht |
| KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS | ⚪ N/A | Review prueft, meldet Luecken |
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | ⚪ N/A | Review prueft, meldet Probleme |
| KEIN-UPDATE-OHNE-DIFF | ⚪ N/A | Review macht keine Aenderungen |
| KEIN-WIDERSPRUCH-OHNE-MARKIERUNG | ⚪ N/A | Review meldet unmarkierte Widersprueche |
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | ⚪ N/A | Review aendert Wiki nicht |
| KORREKTE-UMLAUTE | ⚪ N/A | Review meldet Umlaut-Drift |

---
```

- [ ] **Step 3: Phase 0 — Self-Referential Governance-Extraktion schreiben**

```markdown
## Phasen

### Phase 0: Governance laden (Self-Referential)

<NICHT-VERHANDELBAR>
Der Standard wird aus den AKTUELLEN Plugin-Dateien gelesen, NICHT hardcoded.
Wenn sich Templates aendern, aendert sich automatisch was der Review prueft.
</NICHT-VERHANDELBAR>

1. **Konzeptseiten-Standard extrahieren:**
   - Read `governance/synthese-dispatch-template.md`
   - Suche den Block nach "Frontmatter (alle Felder PFLICHT):"
   - Extrahiere alle YAML-Feldnamen zwischen den `---` Markern
   - Ergebnis: `PFLICHT_FELDER_KONZEPT` (z.B. type, title, synonyme, schlagworte,
     materialgruppe, versagensart, mocs, quellen-anzahl, created, updated,
     synth-datum, reviewed)

2. **Quellenseiten-Standard extrahieren:**
   - Read `governance/ingest-dispatch-template.md`
   - Analog: Extrahiere Pflicht-Felder aus dem Frontmatter-Block
   - Ergebnis: `PFLICHT_FELDER_QUELLE` (z.B. type, title, autor, jahr, verlag,
     seiten, kategorie, verarbeitung, pdf, reviewed, ingest-datum, schlagworte,
     kapitel-index, konzept-kandidaten)

3. **Soll-Struktur extrahieren:**
   - Read `governance/synthese-dispatch-template.md`
   - Suche den Block nach "Body-Struktur"
   - Extrahiere H2-Headers in Reihenfolge
   - Ergebnis: `SOLL_REIHENFOLGE_KONZEPT` (Zusammenfassung, Einsatzgrenzen,
     Formeln, Zahlenwerte, Norm-Referenzen, Widersprueche, Verwandte Konzepte, Quellen)

4. **Erlaubte Typen laden:**
   - Read `hooks/config/valid-types.txt`
   - Ergebnis: `VALID_TYPES` (quelle, konzept, norm, baustoff, verfahren, moc)

5. **Link-Konventionen laden:**
   - Read `governance/naming-konvention.md`
   - Extrahiere die 3 Link-Typen (PDF-Beleg, Konzept, Quellenseite)
   - Extrahiere Dateinamen-Regeln (lowercase, ASCII, Bindestriche, keine Umlaute)

---
```

- [ ] **Step 4: Commit (zusammen mit Task 1)**

```bash
git add plugin/skills/wiki-review/SKILL.md plugin/commands/wiki-review.md
git commit -m "feat: SPEC-004 wiki-review Skill + Command Grundgeruest (Phase 0)"
```

- [ ] **Step 5: Konsistenz pruefen**

Run: `bash plugin/hooks/check-consistency.sh plugin/`
Expected: 19/19 PASS

---

### Task 3: SKILL.md — Phase 1 (Obsidian-Layer, exhaustiv)

**Files:**
- Modify: `plugin/skills/wiki-review/SKILL.md`

- [ ] **Step 1: Phase 1 Obsidian-Layer schreiben**

Append to SKILL.md:

```markdown
### Phase 1: Obsidian-Layer (EXHAUSTIV — jede Seite)

Alle `.md`-Dateien in `wiki/` durchlaufen (ausser `_`-Prefix Metadateien).
Fuer JEDE Seite:

**1.1 Frontmatter-Schema:**
- Bestimme Seitentyp aus `type:` Feld
- Lade passende Pflicht-Felder-Liste:
  - `type: quelle` → `PFLICHT_FELDER_QUELLE`
  - `type: konzept|verfahren|baustoff` → `PFLICHT_FELDER_KONZEPT`
  - `type: norm|moc` → Minimaler Satz (type, title, schlagworte, reviewed)
- Pruefe: Jedes Pflicht-Feld vorhanden?
- Pruefe: `type:` Wert in `VALID_TYPES`?
- Pruefe: Array-Felder sind Arrays (schlagworte, mocs, synonyme — nicht Strings)
- Pruefe: Datumsfelder sind ISO-Format (created, updated, synth-datum, ingest-datum)
- Melde: Fehlende Felder, falsche Typen, unbekannte Felder (Warnung, kein Fehler)

**1.2 Link-Integritaet:**
- Extrahiere alle `[[...]]` Wikilinks
- Pro Link:
  - Ziel-Datei existiert? (mit Umlaut-Mapping ae↔ä, shortest-path)
  - Link-Syntax: Wikilink `[[...]]` oder Markdown-Link `[...](...)`?
    (Markdown-Links sind ein Konventions-Verstoss)
  - PDF-Links: `[[datei.pdf#page=N|...]]` → PDF existiert im Vault?
- Zaehle: aufloesbare vs. gebrochene Links

**1.3 Dateinamen-Konventionen:**
- Dateiname: lowercase ASCII + Bindestriche? Keine Umlaute? Keine Leerzeichen?
- Eindeutigkeit: Basename (ohne .md) ueber ALLE wiki/-Unterverzeichnisse eindeutig?
  (Obsidian Shortest-Path bricht bei Kollisionen)

**1.4 Graph-Konnektivitaet:**
- Baue Link-Graph: Seite → [ausgehende Links]
- Berechne eingehende Links pro Seite
- Waisen: Seiten mit 0 eingehenden Links (ausser MOCs, _index, _vokabular)
- Sackgassen: Konzept-/Verfahrens-/Baustoffseiten mit 0 ausgehenden Wikilinks

**1.5 Dataview-Kompatibilitaet:**
- `schlagworte:` — Array? (nicht `schlagworte: "Holz"`)
- `mocs:` — Array? (nicht `mocs: "moc-holzbau"`)
- `reviewed:` — boolean oder ISO-Datum? (nicht `reviewed: "ja"`)
- `quellen-anzahl:` — Zahl? (nicht String)

Ergebnis sammeln: `OBSIDIAN_BEFUNDE` (Liste von {seite, check, befund})

---
```

- [ ] **Step 2: Commit**

```bash
git add plugin/skills/wiki-review/SKILL.md
git commit -m "feat: SPEC-004 Phase 1 — Obsidian-Layer (exhaustiv)"
```

---

### Task 4: SKILL.md — Phase 2 (Content-Layer, Stichprobe) + Phase 3 (Meta)

**Files:**
- Modify: `plugin/skills/wiki-review/SKILL.md`

- [ ] **Step 1: Phase 2 Content-Layer schreiben**

Append to SKILL.md:

```markdown
### Phase 2: Content-Layer (STICHPROBE — 15 Seiten)

Waehle 15 zufaellige Seiten (gemischt ueber Typen, keine _-Metadateien):

**2.1 Struktur-Reihenfolge:**
- Extrahiere H2-Headers der Seite
- Vergleiche gegen `SOLL_REIHENFOLGE_KONZEPT` (fuer Konzeptseiten)
- Melde: falsche Reihenfolge, fehlende Abschnitte

**2.2 check-wiki-output.sh:**
- Fuehre `bash hooks/check-wiki-output.sh <seite> wiki/_vokabular.md wiki/` aus
- Sammle PASS/FAIL/WARN pro Seite

**2.3 Quellenqualitaet (nur Konzeptseiten):**
- `quellen-anzahl:` Wert — wie viele Quellen? (<2 ist duenn)
- Wikilink-Dichte: Links pro 100 Zeilen Body-Text

**2.4 Widerspruchs-Marker-Format:**
- `[WIDERSPRUCH]` Plaintext → veraltet (Callout-Syntax empfohlen)
- `> [!CAUTION]` Callout → aktuell

**2.5 Review-Freshness:**
- `reviewed: false` → seit wann? (created/updated Datum)
- `reviewed: true` oder ISO-Datum → OK

Ergebnis sammeln: `CONTENT_BEFUNDE` (Liste von {seite, check, befund})

---

### Phase 3: Meta-Konsistenz

**3.1 _log.md:**
- Offene Marker? `[INGEST UNVOLLSTAENDIG]`, `[SYNTHESE UNVOLLSTAENDIG]`
- Zaehle Ingests seit letztem Review (fuer Session-Start-Hinweis)

**3.2 _index/:**
- Lade alle Index-Dateien (quellen.md, konzepte.md, etc.)
- Pro Eintrag: existiert die verlinkte Seite?
- Pro Wiki-Seite: existiert ein Index-Eintrag?
- Melde: verwaiste Index-Eintraege, fehlende Eintraege

**3.3 _pending.json:**
- Existiert? → "Pipeline-Lock offen" melden (Info, kein Fehler)

**3.4 _vokabular.md:**
- Sammle alle `schlagworte:` aus allen Wiki-Seiten
- Vergleiche gegen _vokabular.md Definitionen (### Headings)
- Melde: Terme in Frontmatter aber nicht definiert (aggregiert, nicht pro Seite)
- Melde: Terme definiert aber nie verwendet ("potentiell veraltet")

Ergebnis sammeln: `META_BEFUNDE`

---
```

- [ ] **Step 2: Commit**

```bash
git add plugin/skills/wiki-review/SKILL.md
git commit -m "feat: SPEC-004 Phase 2-3 — Content-Stichprobe + Meta-Konsistenz"
```

---

### Task 5: SKILL.md — Phase 4 (Abdeckung) + Phase 5 (Ergebnis + Stufe-2-Logik)

**Files:**
- Modify: `plugin/skills/wiki-review/SKILL.md`

- [ ] **Step 1: Phase 4 + 5 schreiben**

Append to SKILL.md:

```markdown
### Phase 4: Abdeckungs-Check

**4.1 Konzept-Kandidaten:**
- `grep "konzept-kandidaten:" wiki/quellen/*.md`
- Zaehle pro Kandidat: wie viele Quellen nennen ihn?
- Kandidaten mit >=2 Quellen → pruefe ob Konzeptseite existiert
- Melde: offene Kandidaten mit Quellenanzahl

**4.2 Verwaiste Quellenseiten:**
- Quellenseiten die von keiner Konzeptseite verlinkt werden
- (Haben Inhalt extrahiert, aber nie in Konzepte eingeflossen)

---

### Phase 5: Ergebnis melden

**5.1 Quick-Scan Report zusammenbauen:**

```
## Quick-Scan: [DATUM]

### Obsidian-Integritaet (exhaustiv, N Seiten)
- Frontmatter: X/N vollstaendig, Y fehlende Felder
  [Top-3 fehlende Felder mit Anzahl]
- Links: X aufloesbar, Y gebrochen
  [Gebrochene Links mit Quellseite]
- Dateinamen: X/N konform, Y Verstoesse
  [Verstoesse auflisten]
- Graph: X Waisen, Y Sackgassen
  [Waisen + Sackgassen auflisten]
- Dataview: X/N kompatibel, Y Typ-Fehler
  [Typ-Fehler auflisten]

### Meta-Konsistenz
- _log.md: [X offene Marker / OK]
- _index: [X verwaiste Eintraege, Y fehlende / OK]
- _pending.json: [offen (Typ, Quelle) / nicht vorhanden]
- Vokabular: [X unbenutzte Terme, Y undefinierte Terme / OK]

### Content-Qualitaet (Stichprobe, 15 Seiten)
- Struktur: X/15 aktuelle Reihenfolge
- Quellen: Durchschnitt N pro Konzeptseite
- Callout-Syntax: X/Y Widersprueche im neuen Format
- Reviews: X ueberfaellig

### Abdeckung
- Offene Konzept-Kandidaten: N (mit >=2 Quellen)
- Verwaiste Quellenseiten: N

### Empfehlung
```

**5.2 Stufe-2-Entscheidung:**
- Obsidian-Layer: IRGENDEIN Befund → "Full-Audit fuer [Kategorie] empfohlen"
- Content-Layer: >=2 Seiten mit gleichem Drift-Muster → "Full-Audit empfohlen"
- Kein Befund → "Wiki-Gesundheit OK. Naechster Review nach dem naechsten Ingest."
- Nutzer entscheidet: "Soll ich den Full-Audit starten?"

---
```

- [ ] **Step 2: Commit**

```bash
git add plugin/skills/wiki-review/SKILL.md
git commit -m "feat: SPEC-004 Phase 4-5 — Abdeckung + Ergebnis + Stufe-2-Logik"
```

---

### Task 6: SKILL.md — Phase 6 (Full-Audit, batchweise)

**Files:**
- Modify: `plugin/skills/wiki-review/SKILL.md`

- [ ] **Step 1: Phase 6 Full-Audit schreiben**

Append to SKILL.md:

```markdown
### Phase 6: Full-Audit (batchweise, auf Nutzer-Anfrage)

<NICHT-VERHANDELBAR>
Full-Audit NUR nach Nutzer-Bestaetigung. Nie automatisch starten.
</NICHT-VERHANDELBAR>

**6.1 Batch-Strategie:**
- Batch 1: `wiki/quellen/` (alle Quellenseiten)
- Batch 2: `wiki/konzepte/` (alle Konzeptseiten)
- Batch 3: `wiki/normen/` + `wiki/verfahren/` + `wiki/baustoffe/`
- Batch 4: `wiki/_index/` + MOCs + Sonderdateien

Pro Batch: Alle Phase-1-Checks (Obsidian) + Phase-2-Checks (Content) auf JEDE Seite.
Nach jedem Batch: Zwischenergebnis melden, Nutzer kann abbrechen.

**6.2 Befunde kategorisieren:**

| Kategorie | Behebbar | Aktion |
|---|---|---|
| **Obsidian-Fix** | Automatisch | Frontmatter-Feld ergaenzen, Link korrigieren |
| **Restrukturierung** | Semi-auto (/synthese) | Abschnitte umstellen, Callout-Syntax |
| **Inhaltsluecke** | Manuell (/ingest, /synthese) | Konzept erstellen, Quellen hinzufuegen |
| **Veraltet** | Review noetig | reviewed: false seit >30 Tagen |

**6.3 Migrationsplan generieren:**

```
## Full-Audit Report: [DATUM]

### Befund-Uebersicht
- N Seiten geprueft
- X Obsidian-Fixes (automatisch behebbar)
- Y Restrukturierungen (Synthese noetig)
- Z Inhaltsluecken (Ingest/Synthese noetig)
- W Reviews ueberfaellig

### Obsidian-Fix Batch (vorgeschlagene Aktion)
| Seite | Fehlend | Vorgeschlagener Wert |
|---|---|---|
| quellen/xyz.md | materialgruppe | Stahlbeton (aus kategorie-Feld) |
| konzepte/abc.md | versagensart | [aus Body-Text extrahiert] |

Soll ich diesen Batch ausfuehren? (N Seiten, ~M Minuten)

### Restrukturierungen
| Seite | Problem | Vorschlag |
|---|---|---|
| konzepte/abc.md | Randbedingungen nach Formeln | `/synthese abc` |
| konzepte/def.md | Widerspruch als Plaintext | Callout-Syntax Migration |

### Inhaltsluecken
| Konzept | Quellen | Vorschlag |
|---|---|---|
| Durchstanzen | 3 (Fingerloos, Ehrhart, CEN/TS) | `/synthese durchstanzen` |

### Naechste Schritte
1. Obsidian-Fix Batch ausfuehren? (X Seiten)
2. Re-Synthese einplanen? (Y Seiten)
3. Neue Ingests empfohlen? (Z offene Kandidaten)
```

**6.4 Report speichern:**
- Erstelle `wiki/_reviews/` Verzeichnis falls nicht vorhanden
- Schreibe Report nach `wiki/_reviews/review-[DATUM].md`
- Eintrag in `wiki/_log.md`:
  ```
  ## [DATUM] wiki-review | Full-Audit
  - Seiten geprueft: N
  - Obsidian-Fixes: X
  - Restrukturierungen: Y
  - Inhaltsluecken: Z
  - Report: [[_reviews/review-[DATUM]]]
  ```

---
```

- [ ] **Step 2: Commit**

```bash
git add plugin/skills/wiki-review/SKILL.md
git commit -m "feat: SPEC-004 Phase 6 — Full-Audit batchweise + Migrationsplan"
```

---

### Task 7: Konsistenz-Pruefung + Governance-Sync

**Files:**
- Modify: `plugin/governance/naming-konvention.md` (Skill-Routing-Referenz, falls noetig)

- [ ] **Step 1: check-consistency.sh ausfuehren**

Run: `bash plugin/hooks/check-consistency.sh plugin/`
Expected: 19/19 PASS

- [ ] **Step 2: Hard-Gates Sync pruefen**

Run: `diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' plugin/skills/using-bibliothek/SKILL.md | sed '1d;$d') plugin/governance/hard-gates.md`
Expected: Kein Output (identisch)

- [ ] **Step 3: guard-wiki-writes Test**

Run: `bash tests/test-guard-wiki-writes.sh`
Expected: 6/6 PASS (wiki-review ist in der Skill-Liste)

- [ ] **Step 4: Alle Tests ausfuehren**

Run: `bash tests/test-guard-wiki-writes.sh && bash tests/test-inject-lock-warning.sh && bash tests/test-guard-pipeline-lock.sh && bash tests/test-advance-pipeline-lock.sh && bash tests/test-integration-pipeline.sh`
Expected: 6+7+10+16+137 = 176 PASS, 0 FAIL

- [ ] **Step 5: SPEC-004 Status auf Done setzen**

Modify `docs/specs/SPEC-004-wiki-review-skill.md`: Status: Done, Version: 1.0

- [ ] **Step 6: INDEX.md aktualisieren**

Modify `docs/specs/INDEX.md`: SPEC-004 Status auf Done

- [ ] **Step 7: Commit**

```bash
git add docs/specs/SPEC-004-wiki-review-skill.md docs/specs/INDEX.md
git commit -m "feat: SPEC-004 Done — wiki-review Skill komplett"
```

---

### Task 8: Manueller Smoke-Test

**Files:** Keine Aenderungen — nur Validierung

- [ ] **Step 1: Smoke-Test auf leerem Wiki**

Szenario: `wiki/` existiert nicht.
Expected: Skill meldet "Wiki ist leer, starte mit /ingest"

- [ ] **Step 2: Smoke-Test auf existierendem Wiki**

Falls `wiki/` mit Seiten existiert:
- `/wiki-review` ausfuehren
- Quick-Scan laeuft durch alle 5 Phasen
- Report wird ausgegeben
- Stufe-2-Empfehlung erscheint falls Befunde

Falls kein Wiki vorhanden: Erstelle Mock-Wiki fuer Smoke-Test:
```bash
mkdir -p wiki/quellen wiki/konzepte wiki/_index
# Minimale Testseiten anlegen (Frontmatter + Body)
# Quick-Scan ausfuehren und Output pruefen
```

- [ ] **Step 3: Verifiziere Session-Start-Hinweis**

Neue Session starten → using-bibliothek wird geladen
Expected: "Noch kein Wiki-Review gelaufen. `/wiki-review` empfohlen?"
(nur wenn `wiki/` existiert aber `wiki/_reviews/` nicht)
