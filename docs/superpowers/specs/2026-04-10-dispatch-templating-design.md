# Design-Spec: Dispatch-Templating, Orchestrierungs-Härtung & Obsidian-UX

**Datum:** 2026-04-10
**Status:** Entwurf
**Scope:** Plugin-interne Änderungen + Obsidian-UX-Konventionen

---

## Problem

Das Bibliothek-Plugin hat gut designte Skills (SKILL.md), aber keine mechanische
Durchsetzung der Orchestrierungsregeln. Konkret:

1. **Kein Dispatch-Enforcement:** Nichts hindert den Hauptagent daran, mehrere PDFs
   in einen Subagent zu packen. Folge: Context-Overflow, Token-Verschwendung,
   unvollständige Verarbeitung.

2. **Kein Output-Template:** Subagents bekommen freie Prompts und liefern
   unterschiedlich strukturierten Output. check-wiki-output.sh prüft nur
   Minimum-Anforderungen, nicht die Inhaltsstruktur.

3. **Keine Konzept-Steuerung:** /ingest soll laut Skill neue Konzeptseiten anlegen,
   aber ohne Schwellenwert entsteht Page-Bloat. /synthese kann fehlende Konzepte
   nicht nachholen.

4. **Gate-Agents werden übersprungen:** In der 78-Quellen-Session wurde KEIN EINZIGER
   der 4 Gate-Agents (Vollständigkeit, Quellen, Konsistenz, Vokabular) dispatcht.
   Die gesamte Schicht 2 (Subagent-Review) wurde ignoriert — 78 Quellen ohne
   jegliche Qualitätsprüfung eingelesen.

5. **False-Positive im PostToolUse-Hook:** check-wiki-write.sh blockt lesende
   Bash-Befehle (z.B. `wc -l wiki/quellen/*.md 2>/dev/null`) weil das `>`
   in `2>/dev/null` als Schreibzugriff erkannt wird. Erzeugt ständige Fehlermeldungen
   die den Workflow stören und das Vertrauen in die Hooks untergraben.

**Auslöser:** Masterarbeit-Session (78 Quellen) — Regeln aus SKILL.md wurden
systematisch umgangen, ~30% Token-Verschwendung durch gebatchte Agents und
Context-Overflow. Null Gate-Reviews durchgeführt.

---

## Design-Entscheidungen

| # | Entscheidung | Begründung |
|---|---|---|
| D1 | 1 Agent = 1 PDF, mechanisch abgesichert | Verhindert Context-Overflow |
| D2 | Separate Template-Dateien in `governance/` | Iterierbar, prüfbar, vom Skill entkoppelt |
| D3 | Konzept-Schwellenwert N=2 | Verhindert Page-Bloat, sichert Relevanz |
| D4 | Konzept-Kandidaten bei Ingest, Erstellung bei Synthese | Trennung Extraktion/Verdichtung |
| D5 | Gates bleiben beim Hauptagent (4-Gate-Review pro Quelle) | Qualität vor Geschwindigkeit |
| D6 | Sequentieller Batch-Betrieb | Eine Quelle komplett fertig, dann die nächste |
| D7 | Synthese-Template erzwingt vollständige Übernahme | Kein Informationsverlust |
| D8 | Dateinamen bleiben ASCII-lowercase | Shell-Enforcement, Git-Stabilität, macOS-NFC/NFD |
| D9 | Drei Link-Typen: PDF#page (Beleg), Quellenseite (Übersicht), Konzeptseite (Fachbegriff) | Optimaler Obsidian-UX-Flow |
| D10 | Zweistufige MOC-Hierarchie, interaktiv erarbeitet | LYT-Pattern, keine hartcodierten Fachbereiche |
| D11 | Konzeptseiten dürfen in mehreren MOCs auftauchen | Wiki-Stärke gegenüber Ordnerstruktur |
| D12 | Quellenseiten im Graph View ausgeblendet | Übersichtlicher Graph, Quellen über Konzepte erreichbar |
| D13 | PDFs in .gitignore, nicht im Repository | Repo-Größe, separate Synchronisation |
| D14 | Synthese: Wiki-first, PDF nur bei Widersprüchen | Context-Effizienz, Quellenseiten sind die Extraktion |
| D15 | Gate 9 differenziert: strikt bei Ingest, wiki-first bei Synthese | Ingest erzeugt Extraktion, Synthese konsumiert sie |
| D16 | Gate-Review ist Teil des Dispatch-Templates | Template sagt dem Hauptagent explizit: "Dispatche jetzt die 4 Gates" |
| D17 | check-wiki-write.sh Bugfix: Umleitungen korrekt ignorieren | False Positives eliminieren, Vertrauen in Hooks wiederherstellen |
| D18 | Zweistufiger Pipeline-Lock: gates → sideeffects → frei | Kein Überspringen von Gates ODER Nebeneffekten möglich |
| D19 | PreToolUse-Hook auf Agent-Tool | Sperre BEVOR Token verbrannt werden, nicht erst beim Schreiben |
| D20 | _pending.json als Zustandsdatei | Maschinenlesbarer Pipeline-Status, überlebt Session-Abbrüche |

---

## Komponente 1: Ingest-Dispatch-Template

**Datei:** `governance/ingest-dispatch-template.md`

### Zweck

Standardisierter Prompt für jeden Ingest-Subagent. Der Hauptagent füllt die
Platzhalter aus und dispatcht den Agent mit diesem Prompt. Kein freies Formulieren.

### Platzhalter

| Platzhalter | Beschreibung | Beispiel |
|---|---|---|
| `{{PDF_PFAD}}` | Absoluter Pfad zur PDF-Datei | `/Users/.../wiki/_pdfs/neu/fingerloos-ec2-2016.pdf` |
| `{{WIKI_ROOT}}` | Absoluter Pfad zum Wiki-Verzeichnis | `/Users/.../wiki/` |
| `{{QUELLENSEITE_DATEI}}` | Ziel-Dateiname der Quellenseite | `fingerloos-ec2-2016.md` |
| `{{BESTEHENDE_KONZEPTE}}` | Liste existierender Konzeptseiten (Dateinamen) | `rollschub.md, querdruck.md, ...` |
| `{{VOKABULAR_TERME}}` | Auszug aus _vokabular.md (alle ### Terme) | `Rollschub, Querdruck, ...` |

### Template-Struktur (Grobaufbau)

```
# Ingest-Auftrag

Du bist ein Ingest-Agent des Bibliothek-Plugins.

## Dein Auftrag
- Lies GENAU EINE PDF vollständig: {{PDF_PFAD}}
- Schreibe GENAU EINE Quellenseite: wiki/quellen/{{QUELLENSEITE_DATEI}}
- Aktualisiere bestehende Konzeptseiten die vom Buch substanziell behandelt werden
- Melde neue Konzept-Kandidaten (NICHT als eigene Seiten anlegen)

## Regeln (NICHT VERHANDELBAR)
- Jede Seite lesen. Jedes Kapitel. Kein Überspringen.
- Jede Aussage mit Seitenangabe belegen.
- Jeder Zahlenwert mit Quelle + Seite.
- Jeder Normbezug mit Abschnittsnummer.
- Deutsche Umlaute (ä, ö, ü, ß) in Wiki-Text. ASCII in Dateinamen.
- Schlagworte NUR aus kontrolliertem Vokabular: {{VOKABULAR_TERME}}

## Output-Struktur: Quellenseite

[Exakte Frontmatter-Vorlage aus governance/seitentypen.md]
[Exakte Inhaltsstruktur: Überblick → Kapitel-Zusammenfassungen → Querverweise]

## Output-Struktur: Konzeptseiten-Updates

Für jedes Konzept das im Buch substanziell behandelt wird:
- Wenn {{BESTEHENDE_KONZEPTE}} die Seite enthält → Aktualisiere sie
  (neuen Quellenverweis + Seitenangabe hinzufügen)
- Wenn NICHT → Trage den Term als konzept-kandidat in die Quellenseite ein:
  `konzept-kandidaten: [Term1, Term2, ...]`
  KEINE neue Konzeptseite anlegen.

## Kontext-Budget-Stopp
Wenn du merkst dass der Context knapp wird (Kompression, unvollständige Reads):
HARTER STOPP. Schreibe was du hast mit Marker `verarbeitung: fehlerhaft`
und `[INGEST UNVOLLSTAENDIG]`. Lieber ehrlich abbrechen als halluzinieren.

## Nach dem Schreiben
- Führe check-wiki-output.sh auf jede geschriebene Datei aus
- Bei FAIL: Korrigiere und wiederhole (max 3×)
- Melde Ergebnis: welche Dateien geschrieben, welche Checks bestanden/gefailt
```

### Änderungen am /ingest-Skill (SKILL.md)

Phase 0 bekommt neuen Schritt **0.6: Dispatch vorbereiten**:

```
1. Lade governance/ingest-dispatch-template.md
2. Fülle Platzhalter:
   - {{PDF_PFAD}}: aus Phase 0.1
   - {{WIKI_ROOT}}: Projektpfad + /wiki/
   - {{QUELLENSEITE_DATEI}}: nach Naming-Konvention ableiten
   - {{BESTEHENDE_KONZEPTE}}: Glob wiki/konzepte/*.md → Dateinamen-Liste
   - {{VOKABULAR_TERME}}: grep "^### " wiki/_vokabular.md → Term-Liste
3. Dispatche Agent mit ausgefülltem Template als Prompt
4. VERBOTEN: Prompt frei formulieren. Immer Template verwenden.
```

Phase 2b (Konzeptseiten) wird angepasst:

```
ALT:  "Existiert keine? → Neue Konzeptseite anlegen"
NEU:  "Existiert keine? → Als konzept-kandidat in Quellenseite eintragen.
       Konzeptseite wird erst durch /synthese erstellt wenn ≥2 Quellen
       den Kandidaten nennen."
```

---

## Komponente 2: Synthese-Dispatch-Template

**Datei:** `governance/synthese-dispatch-template.md`

### Zweck

Standardisierter Prompt für jeden Synthese-Subagent. Erzwingt vollständige
Übernahme aller Informationen aus den Quellenseiten.

### Platzhalter

| Platzhalter | Beschreibung | Beispiel |
|---|---|---|
| `{{KONZEPT_NAME}}` | Name des zu vertiefenden Konzepts | `Indirekte Auflagerung` |
| `{{KONZEPT_DATEI}}` | Pfad zur bestehenden Konzeptseite (oder "NEU") | `wiki/konzepte/indirekte-auflagerung.md` |
| `{{QUELLENSEITEN_INHALT}}` | Vollständiger Inhalt aller Wiki-Quellenseiten die das Konzept behandeln | (inline eingefügt, mit Dateiname als Header) |
| `{{WIKI_ROOT}}` | Absoluter Pfad zum Wiki-Verzeichnis | `/Users/.../wiki/` |
| `{{VOKABULAR_TERME}}` | Auszug aus _vokabular.md | `Rollschub, Querdruck, ...` |

### Lesestrategie: Wiki-first, PDF bei Bedarf

Die Synthese arbeitet primär auf den Wiki-Quellenseiten — diese sind die
strukturierte Extraktion aus Phase 1 des Ingests (4-Gate-geprüft).
Original-PDFs werden nur punktuell geladen.

```
Schritt 1: Wiki-Quellenseiten lesen (IMMER)
   → Alle Quellenseiten die das Konzept behandeln
   → ~200-500 Zeilen pro Seite, auch bei 10 Quellen kein Context-Problem
   → Extrahiere: Formeln, Zahlenwerte, Normbezüge, Widersprüche

Schritt 2: Vergleichende Analyse auf Wiki-Basis
   → Formeln nebeneinanderstellen
   → Zahlenwerte in Vergleichstabelle
   → Widersprüche identifizieren

Schritt 3: PDF-Spot-Check (NUR BEI BEDARF)
   → Wenn Widerspruch zwischen Quellen: die konkreten PDF-Seiten laden
   → Wenn Formel unklar / möglicherweise falsch extrahiert: PDF-Seite prüfen
   → Wenn Zahlenwert unplausibel: Originalstelle verifizieren
   → GEZIELT: nur die 2-5 Seiten die den Punkt betreffen, nicht ganze Kapitel

Schritt 4: Konzeptseite schreiben
```

**Gate 9 Differenzierung:**

| Skill | Gate 9 Ausprägung | Begründung |
|---|---|---|
| /ingest | STRIKT — PDF komplett lesen | Hier entsteht die Extraktion. Keine Abkürzung. |
| /synthese | WIKI-FIRST — Quellenseiten primär, PDF bei Widerspruch/Unklarheit | Quellenseiten sind 4-Gate-geprüfte Extraktion. |
| /normenupdate | STRIKT — Neue Norm-PDF komplett lesen | Neue Normausgabe muss vollständig erfasst werden. |

### Template-Struktur (Grobaufbau)

```
# Synthese-Auftrag

Du bist ein Synthese-Agent des Bibliothek-Plugins.

## Dein Auftrag
- Vertiefe die Konzeptseite: {{KONZEPT_DATEI}}
- Arbeite primär auf den Wiki-Quellenseiten (unten eingefügt)
- Lade Original-PDFs NUR bei Widersprüchen oder Unklarheiten (gezielt, nicht komplett)
- Vergleiche Formeln, Zahlenwerte, Normbezüge über alle Quellen
- Dokumentiere JEDEN Widerspruch mit [WIDERSPRUCH]-Marker

## Wiki-Quellenseiten (PRIMÄRQUELLE)
{{QUELLENSEITEN_INHALT}}

## Lesestrategie (NICHT VERHANDELBAR)
1. Arbeite auf den Wiki-Quellenseiten oben — sie sind 4-Gate-geprüfte Extraktionen
2. NUR wenn du einen Widerspruch, eine unklare Formel oder einen unplausiblen
   Zahlenwert findest → lade die konkreten PDF-Seiten (gezielt, 2-5 Seiten)
3. Vermerke jeden PDF-Spot-Check: "PDF verifiziert: [Datei], S. X — [Ergebnis]"

## KEIN INFORMATIONSVERLUST (NICHT VERHANDELBAR)
Für JEDE Quellenseite gilt:
- Jede Formel die dort steht → muss in der Konzeptseite landen
- Jeder Zahlenwert → muss in der Vergleichstabelle landen
- Jede Randbedingung → muss dokumentiert sein
- Jeder Normbezug → muss mit Abschnitt erfasst sein

Wenn du unsicher bist ob eine Info relevant ist: AUFNEHMEN.
Weglassen nur mit expliziter Begründung im Text.

## Output-Struktur: Konzeptseite

[Exakte Struktur aus /synthese SKILL.md Phase 2a:]
- Zusammenfassung (1-3 Sätze)
- Formeln (pro Formel: Quelle, Annahmen, Gültigkeitsbereich)
- Zahlenwerte + Parameter (Vergleichstabelle über alle Quellen)
- Norm-Referenzen (mit Abschnitt + Interpretationsvergleich)
- Randbedingungen (Material, Geometrie, Temperatur, Feuchte)
- Widersprüche (mit [WIDERSPRUCH]-Marker, beide Quellen zitiert)
- Verwandte Konzepte (Wikilinks [[...]])
- Quellen (mit Kapitel + Seitenangabe)

## Link-Konventionen
- Fließtext-Belege: [[datei.pdf#page=N|Autor Jahr, S. N]] → direkt ins PDF
- Fachbegriffe: [[konzeptname|Anzeigename]] → Konzeptseite
- ## Quellen-Abschnitt: [[quellenseite|Autor Jahr]] → Wiki-Quellenseite

## Konzept-Kandidaten prüfen
Wenn dieses Konzept bisher nur als konzept-kandidat existiert und
≥2 Quellen es substanziell behandeln → Erstelle die Konzeptseite als NEU.
Wenn <2 Quellen → NICHT erstellen, nur im Bericht melden.

## Nach dem Schreiben
- Führe check-wiki-output.sh auf die Konzeptseite aus
- Bei FAIL: Korrigiere und wiederhole (max 3×)
- Melde Ergebnis: Datei, Checks, Anzahl Formeln/Werte/Widersprüche,
  Anzahl PDF-Spot-Checks
```

### Änderungen am /synthese-Skill (SKILL.md)

Phase 0 bekommt **0.0: Konzept-Kandidaten sammeln**:

```
1. Scanne alle Quellenseiten: grep "konzept-kandidaten:" wiki/quellen/*.md
2. Zähle pro Kandidat: wie viele Quellen nennen ihn?
3. Kandidaten mit ≥2 Quellen → zur Synthese-Liste hinzufügen
4. Meldung: "N neue Konzeptseiten können erstellt werden: [Liste]"
```

**Phase 0.5b GEÄNDERT:** Wiki-first statt PDF-first:

```
ALT:  "ALLE identifizierten PDF-Kapitel MÜSSEN vollständig gelesen werden."
NEU:  "1. Lies alle Wiki-Quellenseiten die das Konzept behandeln (PFLICHT).
       2. Lade Original-PDFs NUR bei Widersprüchen, unklaren Formeln oder
          unplausiblen Zahlenwerten (GEZIELT, 2-5 Seiten).
       3. Vermerke jeden PDF-Spot-Check im Output."
```

Gate 9 Governance-Tabelle anpassen:
```
ALT:  "✅ Aktiv | Phase 0.5 liest ALLE referenzierten Quellen (PDF)"
NEU:  "✅ Aktiv | Wiki-Quellenseiten als Primärquelle (4-Gate-geprüft),
       PDF-Spot-Check bei Widersprüchen/Unklarheiten"
```

Phase 0 bekommt neuen Schritt **0.6: Dispatch vorbereiten**:

```
1. Lade governance/synthese-dispatch-template.md
2. Fülle Platzhalter:
   - {{KONZEPT_NAME}}: aus Nutzer-Anfrage oder Kandidaten-Liste
   - {{KONZEPT_DATEI}}: Pfad zur bestehenden Seite oder "NEU"
   - {{QUELLENSEITEN_INHALT}}: Read aller Wiki-Quellenseiten → inline einfügen
   - {{WIKI_ROOT}}: Projektpfad + /wiki/
   - {{VOKABULAR_TERME}}: grep "^### " wiki/_vokabular.md → Term-Liste
3. Dispatche Agent mit ausgefülltem Template als Prompt
4. VERBOTEN: Prompt frei formulieren. Immer Template verwenden.
```

---

## Komponente 3: Konzept-Kandidaten-System

### Neues Frontmatter-Feld

Quellenseiten bekommen ein optionales Feld:

```yaml
konzept-kandidaten:
  - term: "Verschiebungsmodul"
    kontext: "Schlüsselparameter der HBV-Bemessung, Kap. 5, S. 120-135"
  - term: "Kerven"
    kontext: "Eigener Verbindungsmitteltyp, Kap. 8, S. 200-210"
```

### Schwellenwert-Logik

| Anzahl Quellen mit Kandidat | Aktion |
|---|---|
| 1 | Bleibt Kandidat. Kein Handlungsbedarf. |
| ≥2 | /synthese erstellt Konzeptseite bei nächstem Lauf. |

### Tracking

`/katalog` zeigt Kandidaten-Status an:
```
Konzept-Kandidaten (noch nicht als Seite):
- Verschiebungsmodul (3 Quellen) → BEREIT für /synthese
- Kerven (2 Quellen) → BEREIT für /synthese
- Stabwerkmodell (1 Quelle) → Wartet auf weitere Quellen
```

### Abgrenzung bestehende Konzeptseiten

Wenn eine Konzeptseite bereits existiert, wird sie NICHT als Kandidat geführt.
Der Ingest-Agent aktualisiert sie direkt (wie bisher in Phase 2b).

---

## Komponente 4: Skill-Anpassungen

### /ingest SKILL.md — Änderungen

1. **Phase 0.6 NEU:** Dispatch-Vorbereitung (Template laden, Platzhalter füllen)
2. **Phase 2b GEÄNDERT:** Neue Konzepte → konzept-kandidaten statt Seitenanlage
3. **Batch-Regel NEU:** Bei mehreren PDFs: sequentiell verarbeiten, eine nach der
   anderen, jede mit vollem Gate-Durchlauf. Parallelisierung nur bei Gates
   (Gate 1-4 können parallel dispatcht werden, da unabhängig).
4. **Template-Pflicht NEU:** "VERBOTEN: Subagent-Prompt frei formulieren."

### /synthese SKILL.md — Änderungen

1. **Phase 0.0 NEU:** Konzept-Kandidaten sammeln und Schwellenwert prüfen
2. **Phase 0.5b GEÄNDERT:** Wiki-first statt PDF-first. Quellenseiten als Primärquelle,
   PDFs nur bei Widersprüchen/Unklarheiten gezielt laden.
3. **Gate 9 Governance-Tabelle GEÄNDERT:** Differenzierte Durchsetzung dokumentieren
4. **Phase 0.6 NEU:** Dispatch-Vorbereitung (Template laden, Quellenseiten inline einfügen)
5. **Informationsverlust-Gate NEU:** Explizite Regel dass keine Info aus
   Quellenseiten verloren gehen darf
6. **Template-Pflicht NEU:** "VERBOTEN: Subagent-Prompt frei formulieren."

### governance/seitentypen.md — Änderungen

Quellen-Frontmatter bekommt optionales Feld `konzept-kandidaten:` dokumentiert.

### check-consistency.sh — Neue Checks

| # | Check | Prüft |
|---|---|---|
| 13 | Template-Existenz | `governance/ingest-dispatch-template.md` existiert |
| 14 | Template-Existenz | `governance/synthese-dispatch-template.md` existiert |
| 15 | Template-Platzhalter | Beide Templates enthalten alle dokumentierten Platzhalter |
| 16 | Skill-Template-Referenz | /ingest und /synthese SKILL.md referenzieren ihr Template |

---

## Komponente 5: Batch-Orchestrierung

### Sequentieller Ablauf (pro Quelle)

```
Für jede PDF in der Queue:
  1. Template laden + Platzhalter füllen
  2. Ingest-Agent dispatchen (1 PDF)
  3. Auf Ergebnis warten
  4. check-wiki-output.sh (automatisch via PostToolUse-Hook)
  5. 4 Gate-Agents dispatchen (können parallel laufen)
  6. Gate-Ergebnisse auswerten
  7. Bei FAIL: Korrektur-Zyklus (max 3×)
  8. Phase 4: Nebeneffekte (_log, _index, MOC, PDF sortieren)
  9. → Nächste PDF
```

### Batch-Modus (explizit angefordert)

Wenn der Nutzer sagt "Verarbeite alle PDFs in _pdfs/neu/":

```
1. Liste alle PDFs in _pdfs/neu/
2. Zeige Liste und frage: "N PDFs gefunden. Sequentiell verarbeiten?"
3. Pro PDF: vollständiger Ablauf (Schritte 1-9 oben)
4. Zwischen-Status nach jeder Quelle: "Fertig: M/N. Nächste: [Dateiname]"
5. Am Ende: Gesamtbericht
```

**KEIN paralleles Dispatchen** mehrerer Ingest-Agents — außer der Nutzer
fordert es explizit und akzeptiert das Risiko reduzierter Gate-Kontrolle.

---

## Nicht im Scope

- **PreToolUse-Hook auf Agent-Tool:** Technisch möglich, aber überkomplex.
  Die Template-Pflicht im Skill-Text + check-consistency.sh ist einfacher
  und ausreichend.
- **Änderungen an check-wiki-output.sh:** Die 16 Checks bleiben wie sie sind.
- **Änderungen an den 7 Subagent-Definitionen:** Die Gate-Agents bleiben unverändert.
- **Wiki-Daten-Migration:** Bestehende Wiki-Seiten werden nicht angepasst.
  Das konzept-kandidaten-Feld wird nur bei neuen Ingests gesetzt.
- **Umlaute in Dateinamen:** Bewusst verworfen (macOS NFD, Git, Shell-Enforcement).
  Stattdessen title:-Frontmatter + Wikilink-Aliases.
- **Community-Plugins (Juggl, Breadcrumbs):** Nicht nötig bei aktuellem Umfang.
  Native Obsidian-Features (Graph-Filter, Local Graph, Dataview) reichen aus.
- **Obsidian Sync / iCloud:** Nicht spezifiziert — Nutzer wählt Sync-Methode selbst.

---

## Dateien die erstellt/geändert werden

| Datei | Aktion | Beschreibung |
|---|---|---|
| `governance/ingest-dispatch-template.md` | NEU | Template-Prompt für Ingest-Subagents |
| `governance/synthese-dispatch-template.md` | NEU | Template-Prompt für Synthese-Subagents |
| `skills/ingest/SKILL.md` | ÄNDERN | Phase 0.6, Phase 2b, Batch-Regel, Template-Pflicht |
| `skills/synthese/SKILL.md` | ÄNDERN | Phase 0.0, Phase 0.6, Informationsverlust-Gate, Template-Pflicht |
| `governance/seitentypen.md` | ÄNDERN | konzept-kandidaten Feld dokumentieren |
| `hooks/check-consistency.sh` | ÄNDERN | 4 neue Checks (13-16) |
| `ARCHITECTURE.md` | ÄNDERN | Dispatch-Templates + Konzept-Kandidaten dokumentieren |

---

## Komponente 6: Obsidian-UX-Konventionen

### 6.1: Dateinamen — ASCII bleibt (bestätigt durch Recherche)

**Problem:** Umlaute in Dateinamen brechen Shell-Enforcement (macOS NFD vs. NFC),
verursachen Git-Phantom-Änderungen und destabilisieren check-wiki-output.sh.

**Lösung:** Bestehende ASCII-lowercase-Konvention beibehalten. Obsidian-Darstellung
über Frontmatter und Wikilink-Aliases:

| Ebene | Beispiel |
|---|---|
| Dateiname | `aufhaengebewehrung.md` |
| Frontmatter `title:` | `"Aufhängebewehrung"` |
| Wikilink im Text | `[[aufhaengebewehrung\|Aufhängebewehrung]]` |
| Obsidian Sidebar | zeigt `title:` wenn konfiguriert |

Obsidian löst Wikilinks case-insensitive auf → funktioniert zuverlässig.

### 6.2: Drei Link-Typen

Jede Wiki-Seite verwendet genau drei Arten von Links, je nach Kontext:

**Typ 1: Beleg im Fließtext → PDF mit Seitenangabe**

```markdown
kc,90 = 1,5 bei indirektem Anschluss ([[fingerloos-ec2-2016.pdf#page=234|Fingerloos 2016, S. 234]]).
```

- Klick öffnet PDF direkt auf Seite 234 (Obsidian nativer PDF-Viewer)
- Shortest-Path-Auflösung: Voller Pfad `_pdfs/stahlbeton/...` nicht nötig
- `#page=N` funktioniert nativ seit Obsidian 0.14
- Seitenbereiche im Alias: `[[datei.pdf#page=234|Fingerloos 2016, S. 234–237]]`
  (springt zu S. 234, Alias zeigt Bereich)

**Typ 2: Quellenübersicht → Quellenseite (## Quellen-Abschnitt)**

```markdown
## Quellen

- [[fingerloos-ec2-2016|Fingerloos 2016]] — Kap. 9, S. 230–250
- [[bathon2010|Bathon 2010]] — Kap. 4, S. 88–110
- [[ec2-9-2-5|EC2, §9.2.5]]
```

- Klick geht zur Wiki-Quellenseite (Zusammenfassung, Kapitelindex, Metadaten)
- Alias zeigt den "schönen" Autorennamen

**Typ 3: Fachbegriff → Konzeptseite**

```markdown
Die [[aufhaengebewehrung|Aufhängebewehrung]] wird nach Gl. (9.13) bemessen.
```

- Klick geht zur Konzeptseite (Formeln, Vergleichstabellen, Widersprüche)
- Keine Seitenangabe nötig — verweist auf Wissen, nicht auf Beleg

**Abgrenzungsregel:**
- **"Was ist das?"** → Konzeptseite
- **"Wer sagt das?"** → PDF#page (Beleg im Fließtext)
- **"Welche Quellen speisen diese Seite?"** → Quellenseite (## Quellen)
- **"Was fordert die Norm?"** → Normseite: `[[ec2-9-2-5|EC2, §9.2.5]]`

### 6.3: MOC-Hierarchie

**Struktur:** Zweistufig nach LYT-Pattern (Nick Milo)

```
wiki/home.md                          ← Top-Level-Einstieg (Default Open File)
├── wiki/moc/moc-holzbau.md           ← Bereichs-MOC (Top)
│   ├── wiki/moc/moc-querdruck.md     ← Themen-MOC (Sub)
│   │   ├── → querdruck.md            (Konzept)
│   │   └── → querdrucknachweis.md    (Verfahren)
│   ├── wiki/moc/moc-rollschub.md
│   │   └── → rollschub.md
│   └── wiki/moc/moc-verbindungsmittel.md
├── wiki/moc/moc-stahlbeton.md
│   └── ...
└── wiki/moc/moc-verbundbau.md
    └── ...
```

**Regeln:**
- Top-MOCs (Fachbereiche) werden **interaktiv mit dem Nutzer erarbeitet**,
  nicht hartcodiert. Grundlage: vorhandene Quellen + Nutzer-Einschätzung.
- Konzeptseiten dürfen in **mehreren MOCs** verlinkt sein
  (z.B. Aufhängebewehrung in MOC-Stahlbeton UND MOC-Verbundbau)
- Quellenseiten erscheinen **NICHT in MOCs** — nur über Konzeptseiten erreichbar
- MOC-Inhalte sind **manuell kuratiert** (narrative Reihenfolge),
  ergänzt durch Dataview-Queries für automatische Listen
- Zwei Ebenen genügen für ~100-200 Seiten. Dritte Ebene erst bei >500 Seiten erwägen.

**Neues Frontmatter-Feld für Konzeptseiten:**

```yaml
mocs: [moc-holzbau, moc-verbundbau]
```

Ermöglicht bidirektionale Dataview-Queries:
- "Welche Konzepte gehören zu MOC-Holzbau?" → `FROM "konzepte" WHERE contains(mocs, "moc-holzbau")`
- "In welchen MOCs taucht Rollschub auf?" → Frontmatter `mocs:` auslesen

**Home-Seite:** `wiki/home.md` als Vault-Einstieg. Obsidian-Config:
`"defaultOpenFile": "home"` in `.obsidian/app.json`

### 6.4: Graph View Konfiguration

**Standard-Filter (in obsidian-setup.md dokumentieren):**

```
-path:quellen/ -path:_index/ -file:_
```

Blendet aus: Quellenseiten, Index-Dateien, Sonderdateien (_log, _vokabular).
Zeigt: Konzepte, Verfahren, Baustoffe, Normen, MOCs.

**Gruppen-Coloring:**

| Gruppe | Query | Farbe (Vorschlag) |
|---|---|---|
| MOC | `path:moc/` | Rot (große Knoten) |
| Konzept | `path:konzepte/` | Blau |
| Verfahren | `path:verfahren/` | Grün |
| Norm | `path:normen/` | Orange |
| Baustoff | `path:baustoffe/` | Violett |

**Attachments-Toggle:** AUS — damit PDFs nicht im Graph erscheinen.

**Local Graph:** Für tägliche Arbeit wichtiger als globaler Graph.
Zeigt nur Nachbarn der aktuell geöffneten Seite (Tiefe konfigurierbar).

### 6.5: Git und PDFs

**Problem:** 95 PDFs à 5–50 MB = 500 MB–mehrere GB Repository-Größe.

**Lösung:** `wiki/_pdfs/` in `.gitignore` aufnehmen. PDFs separat synchronisieren
(Syncthing, NAS, oder Obsidian Sync).

Ergänzung in `.gitignore`:
```
wiki/_pdfs/
```

Die PDFs bleiben lokal im Vault (Obsidian-Links funktionieren),
aber belasten das Git-Repository nicht.

Alternative: Git LFS (`git lfs track "*.pdf"`) wenn PDFs im Repo
versioniert werden sollen.

---

## Komponente 7: Gate-Enforcement im Orchestrierungs-Flow

### Problem

Die 4 Gate-Agents existieren, werden aber vom Hauptagent nicht dispatcht.
Der Skill-Text sagt "Phase 3: 4-Gate Review (IRON LAW)" — aber in der Praxis
wurde Phase 3 komplett übersprungen.

### Lösung: Gates im Ingest-Workflow verankern

Der Hauptagent bekommt eine explizite Checkliste die er nach jedem Ingest-Agent
abarbeiten MUSS. Diese Checkliste steht NICHT im Subagent-Template (der Subagent
kann keine Subagents dispatchen), sondern im /ingest-Skill als Phase 3.

**Phase 3 (bestehend, aber verstärkt):**

```
NACH Rückkehr des Ingest-Subagents:

□ check-wiki-output.sh automatisch gelaufen (PostToolUse-Hook)
  → Bei FAIL: Subagent nochmal dispatchen mit Korrektur-Auftrag

□ Gate 1: vollstaendigkeits-pruefer dispatchen
  → Input: Quellenseite + Original-PDF (Kapitelverzeichnis)
  → PASS/FAIL?

□ Gate 2: quellen-pruefer dispatchen
  → Input: Quellenseite + 5 zufällige Seitenangaben zum Spot-Check gegen PDF
  → PASS/FAIL?

□ Gate 3: konsistenz-pruefer dispatchen
  → Input: Quellenseite + bestehende Wiki-Konzeptseiten
  → PASS/FAIL?

□ Gate 4: vokabular-pruefer dispatchen
  → Input: Quellenseite + _vokabular.md
  → PASS/FAIL?

Gate 1-4 können PARALLEL dispatcht werden (unabhängig voneinander).

Erst wenn alle 4 Gates PASS: → Phase 4 (Nebeneffekte)
Bei FAIL: Korrektur → Re-Gate (max 3×) → dann Eskalation an Nutzer
```

### Für /synthese analog (2 Gates + Nebeneffekte)

```
NACH Rückkehr des Synthese-Subagents:

□ check-wiki-output.sh automatisch gelaufen (PostToolUse-Hook)
□ Gate 1: quellen-pruefer dispatchen
□ Gate 2: konsistenz-pruefer dispatchen

Erst wenn beide PASS: → Nebeneffekte (Phase 5)
□ _index aktualisieren
□ _log.md Eintrag
□ MOC prüfen/aktualisieren
□ check-wiki-output.sh auf finale Seite
```

---

## Komponente 8: Zweistufiger Pipeline-Lock (PreToolUse + PostToolUse)

### Überblick

Mechanische Sperre die den nächsten Ingest/Synthese-Dispatch blockiert bis
Gates UND Nebeneffekte des aktuellen Durchlaufs abgeschlossen sind.
Verhindert Token-Verschwendung (Sperre BEVOR Agent startet, nicht beim Schreiben).

### Zustandsdatei: `wiki/_pending.json`

```json
{
  "typ": "ingest",
  "stufe": "gates",
  "quelle": "fingerloos-ec2-2016",
  "timestamp": "2026-04-10T14:30:00",
  "gates_erwartet": ["vollstaendigkeits-pruefer", "quellen-pruefer", "konsistenz-pruefer", "vokabular-pruefer"],
  "gates_bestanden": []
}
```

Stufen:
- `"gates"` — Gate-Agents müssen noch laufen
- `"sideeffects"` — Gates bestanden, Nebeneffekte ausstehend
- (Datei gelöscht) — alles fertig, nächster Durchlauf frei

### Hook 1: PreToolUse auf Agent (NEUER Hook)

**Datei:** `hooks/check-gates-pending.sh`

Feuert BEVOR ein Agent dispatcht wird. Prüft ob ein Durchlauf offen ist.

```bash
#!/usr/bin/env bash
# check-gates-pending.sh — PreToolUse Hook auf Agent-Tool
# Blockiert neue Ingest/Synthese-Agents wenn Gates oder Nebeneffekte ausstehen.
# Gate-Agents (pruefer/reviewer/validator) werden IMMER durchgelassen.

set -uo pipefail

INPUT=$(cat)
WIKI_DIR="..."  # aus Projekt-Root ableiten
PENDING="$WIKI_DIR/_pending.json"

# Kein Pending-File → alles frei
if [ ! -f "$PENDING" ]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Subagent-Typ extrahieren
SUBAGENT=$(echo "$INPUT" | sed -n 's/.*"subagent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

# Gate-Agents immer durchlassen
case "$SUBAGENT" in
    *pruefer*|*reviewer*|*validator*)
        echo '{"decision": "allow"}'
        exit 0
        ;;
esac

# Alle anderen Agents blockieren
STUFE=$(echo "$(cat "$PENDING")" | sed -n 's/.*"stufe"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
QUELLE=$(echo "$(cat "$PENDING")" | sed -n 's/.*"quelle"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

case "$STUFE" in
    gates)
        echo "{\"decision\": \"block\", \"reason\": \"Gate-Review fuer '$QUELLE' steht aus. Dispatche zuerst die Gate-Agents (vollstaendigkeits-pruefer, quellen-pruefer, konsistenz-pruefer, vokabular-pruefer).\"}"
        ;;
    sideeffects)
        echo "{\"decision\": \"block\", \"reason\": \"Nebeneffekte fuer '$QUELLE' stehen aus (_log.md, _index, MOC, PDF sortieren). Erst abschliessen, dann naechster Ingest.\"}"
        ;;
esac
exit 0
```

### Hook 2: PostToolUse auf Write/Edit — _pending.json erstellen (ERWEITERUNG)

Nach dem Schreiben einer neuen Quellenseite erstellt check-wiki-write.sh
automatisch `_pending.json` wenn noch keines existiert:

```bash
# In check-wiki-write.sh nach erfolgreichem Wiki-Check:
# Wenn neue Quellenseite geschrieben und kein _pending existiert → erstellen
case "$FILE_PATH" in
    */wiki/quellen/*.md)
        if [ ! -f "$WIKI_DIR/_pending.json" ]; then
            BASENAME=$(basename "$FILE_PATH" .md)
            echo "{\"typ\":\"ingest\",\"stufe\":\"gates\",\"quelle\":\"$BASENAME\",\"timestamp\":\"$(date -u +%FT%T)\"}" > "$WIKI_DIR/_pending.json"
        fi
        ;;
esac
```

### Hook 3: PostToolUse auf Write/Edit — _pending.json Stufen-Transition

Wenn _log.md geschrieben wird, prüft der Hook ob der Eintrag vollständig ist:

```bash
# In check-wiki-write.sh bei Schreibzugriff auf _log.md:
case "$BASENAME" in
    _log.md)
        if [ -f "$WIKI_DIR/_pending.json" ]; then
            QUELLE=$(sed -n 's/.*"quelle"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$WIKI_DIR/_pending.json")
            STUFE=$(sed -n 's/.*"stufe"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$WIKI_DIR/_pending.json")

            if [ "$STUFE" = "gates" ]; then
                # Prüfe ob Gate-Ergebnisse im Log stehen
                if grep -q "Gates:.*PASS" "$FILE_PATH" 2>/dev/null && grep -q "$QUELLE" "$FILE_PATH" 2>/dev/null; then
                    # Gates bestanden → Stufe auf sideeffects
                    sed -i '' 's/"stufe": *"gates"/"stufe": "sideeffects"/' "$WIKI_DIR/_pending.json"
                fi
            elif [ "$STUFE" = "sideeffects" ]; then
                # Prüfe ob vollständiger Log-Eintrag (Datum, Buch, Gates, betroffene Seiten)
                LAST_ENTRY=$(awk '/^## \[.*\] ingest \|/{found=1} found{print}' "$FILE_PATH" | tail -20)
                HAS_GATES=$(echo "$LAST_ENTRY" | grep -c "Gates:" || true)
                HAS_KONZEPTE=$(echo "$LAST_ENTRY" | grep -c "Konzeptseiten" || true)
                HAS_VERARBEITUNG=$(echo "$LAST_ENTRY" | grep -c "Verarbeitung:" || true)

                if [ "$HAS_GATES" -gt 0 ] && [ "$HAS_KONZEPTE" -gt 0 ] && [ "$HAS_VERARBEITUNG" -gt 0 ]; then
                    # Alles komplett → _pending.json löschen
                    rm -f "$WIKI_DIR/_pending.json"
                fi
            fi
        fi
        echo '{"decision": "allow", "reason": "Log-Update erlaubt"}'
        exit 0
        ;;
esac
```

### Vollständiger Flow (mechanisch erzwungen)

```
1. Ingest-Agent schreibt wiki/quellen/xyz.md
   → PostToolUse erstellt _pending.json (stufe: "gates")

2. Hauptagent will nächsten Ingest dispatchen
   → PreToolUse: _pending.json existiert → BLOCK
   → "Gate-Review für xyz steht aus"

3. Hauptagent dispatcht 4 Gate-Agents
   → PreToolUse: subagent_type enthält "pruefer" → ALLOW
   → Gates laufen parallel

4. Alle 4 PASS → Hauptagent schreibt "Gates: 4/4 PASS" in _log.md
   → PostToolUse: erkennt Gate-Ergebnis → stufe: "sideeffects"

5. Hauptagent will nächsten Ingest dispatchen
   → PreToolUse: _pending.json existiert (sideeffects) → BLOCK
   → "Nebeneffekte für xyz stehen aus"

6. Hauptagent macht alle Nebeneffekte, letzter Schritt: vollständiger _log.md Eintrag
   → PostToolUse: erkennt vollständigen Eintrag → löscht _pending.json

7. Nächster Ingest → PreToolUse: kein _pending.json → ALLOW ✅
```

### hooks.json Ergänzung

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/check-gates-pending.sh\"",
            "timeout": 5000
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/check-wiki-write.sh\"",
            "timeout": 30000
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "async": false
          }
        ]
      }
    ]
  }
}
```

### Edge Cases

| Situation | Verhalten |
|---|---|
| Session bricht ab während Gates laufen | _pending.json bleibt. Nächste Session sieht es und meldet: "Offener Durchlauf für [Quelle]. Gates fortsetzen oder verwerfen?" |
| Gate FAIL nach 3 Korrekturen | Hauptagent eskaliert an Nutzer. _pending.json bleibt bis Nutzer entscheidet. |
| Nutzer will _pending.json manuell löschen | Erlaubt — ist ein bewusster Override. /wiki-lint meldet dann fehlende Gate-Einträge. |
| Synthese statt Ingest | Gleicher Mechanismus, `typ: "synthese"`, nur 2 Gates statt 4. |

---

## Komponente 9: Hook-Bugfix (check-wiki-write.sh)

### Bug

Zeile 31 in `hooks/check-wiki-write.sh`:
```bash
grep -qE '(>|>>|tee |mv |cp |rm |echo .+>|sed -i|cat .+>|write)'
```

Das Pattern `>` matcht auch:
- `2>/dev/null` (Fehlerumleitung)
- `</dev/null` (Eingabeumleitung — enthält kein `>`, aber `2>` ja)
- Jede Pipe-Umleitung in Subshells

Folge: Lesende Befehle wie `wc -l wiki/quellen/*.md 2>/dev/null` werden geblockt.

### Fix

Schreibende Umleitungen präziser erkennen — nur `>` das NICHT Teil von
`2>/dev/null`, `>/dev/null`, `2>&1` oder File-Descriptor-Umleitungen ist:

```bash
# ALT (zu aggressiv):
grep -qE '(>|>>|tee |mv |cp |rm |echo .+>|sed -i|cat .+>|write)'

# NEU (präzise):
grep -qE '(^|[^2&])(>>?[^/&])|( tee )|( mv )|( cp )|( rm )|( sed -i)|( cat .+>)' 2>/dev/null
```

Oder einfacher — erst die harmlosen Umleitungen entfernen, dann prüfen:

```bash
CLEAN_CMD=$(echo "$COMMAND" | sed 's/2>\/dev\/null//g; s/>\/dev\/null//g; s/2>&1//g')
if echo "$CLEAN_CMD" | grep -qE '(>|>>|tee |mv |cp |rm |sed -i)' 2>/dev/null; then
    # Wirklich ein Schreibzugriff
fi
```

### Test-Cases

| Befehl | Erwartet | Aktuell |
|---|---|---|
| `wc -l wiki/quellen/*.md` | ALLOW | ALLOW ✅ |
| `wc -l wiki/quellen/*.md 2>/dev/null` | ALLOW | BLOCK ❌ |
| `echo "test" > wiki/quellen/test.md` | BLOCK | BLOCK ✅ |
| `cat wiki/quellen/test.md` | ALLOW | ALLOW ✅ |
| `sed -i 's/foo/bar/' wiki/quellen/test.md` | BLOCK | BLOCK ✅ |
| `grep "pattern" wiki/quellen/*.md 2>/dev/null` | ALLOW | BLOCK ❌ |

---

## Aktualisierte Dateiliste

| Datei | Aktion | Beschreibung |
|---|---|---|
| `governance/ingest-dispatch-template.md` | NEU | Template-Prompt für Ingest-Subagents |
| `governance/synthese-dispatch-template.md` | NEU | Template-Prompt für Synthese-Subagents |
| `skills/ingest/SKILL.md` | ÄNDERN | Phase 0.6, Phase 2b, Batch-Regel, Template-Pflicht, Link-Konventionen |
| `skills/synthese/SKILL.md` | ÄNDERN | Phase 0.0, Phase 0.6, Informationsverlust-Gate, Template-Pflicht |
| `governance/seitentypen.md` | ÄNDERN | konzept-kandidaten + mocs Felder, Link-Typ-Dokumentation |
| `governance/obsidian-setup.md` | ÄNDERN | Graph-Filter, Gruppen-Coloring, Local Graph, Home-Seite |
| `governance/naming-konvention.md` | ÄNDERN | Link-Alias-Konvention dokumentieren, title:-Feld-Nutzung |
| `hooks/check-gates-pending.sh` | NEU | PreToolUse-Hook: Blockiert Agent-Dispatch wenn Gates/Nebeneffekte ausstehen |
| `hooks/check-consistency.sh` | ÄNDERN | 4 neue Checks (13-16) |
| `hooks/check-wiki-write.sh` | ÄNDERN | Bugfix Umleitungen + _pending.json Erstellung/Transition |
| `hooks/hooks.json` | ÄNDERN | PreToolUse auf Agent hinzufügen |
| `ARCHITECTURE.md` | ÄNDERN | Dispatch-Templates, Pipeline-Lock, Konzept-Kandidaten, MOC, Link-Typen |
| `.gitignore` | ÄNDERN | `wiki/_pdfs/` hinzufügen |
