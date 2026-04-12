# Gate-Dispatch-Template

Standardisierte Anleitung für den Hauptagent: Wie die 4 Gate-Agents
nach einem Ingest dispatcht werden. Kein freies Formulieren — immer
dieses Template verwenden.

## Wann dispatchen

NACH Rueckkehr des Pipeline-Workers. Der Hauptagent dispatcht die Gates,
nicht ein Hook. Keine Pipeline darf ohne abgeschlossene Gates weitergehen.

- **Ingest:** 4 Gates (Gate 1-4: vollstaendigkeits-, quellen-, konsistenz-, vokabular-pruefer)
- **Synthese:** 3 Gates (Gate 2-4: quellen-, konsistenz-, vokabular-pruefer — kein vollstaendigkeits-pruefer)

## Pipeline-ID-Marker

JEDER Gate-Prompt MUSS den Platzhalter `{{PIPELINE_ID_MARKER}}` enthalten.
Der dispatchende Skill setzt:
- Ingest: `[INGEST-ID:kurzname]` (z.B. `[INGEST-ID:fingerloos-ec2-2016]`)
- Synthese: `[SYNTHESE-ID:konzeptname]` (z.B. `[SYNTHESE-ID:querkraft-transfer]`)

Gate-Agents geben den Marker im Output-Bericht zurueck. `advance-pipeline-lock.sh`
extrahiert ihn aus `last_assistant_message` und verifiziert gegen `_pending.json.quelle`.
Bei Mismatch wird der Counter NICHT inkrementiert.

## Dispatch-Reihenfolge

Gate 1-4 koennen PARALLEL dispatcht werden (sind unabhaengig voneinander).
Alle 4 muessen PASS (oder PASS MIT HINWEISEN) bevor Phase 4 beginnt.

## Mechanische Pruefung

Jeder Gate-Agent fuehrt als ERSTEN Schritt `check-wiki-output.sh` auf die
Quellenseite aus und meldet das Ergebnis im Pruefbericht. Das ersetzt den
deaktivierten PostToolUse-Hook — die Pruefung laeuft jetzt IM Agent statt
als externer Hook.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/check-wiki-output.sh" "{{QUELLENSEITE_PFAD}}" "{{WIKI_ROOT}}/_vokabular.md" "{{WIKI_ROOT}}/"
```

Bei FAIL: Der Agent bewertet ob es ein echter Mangel oder ein False Positive ist.

---

## Gate 1: vollstaendigkeits-pruefer

### Platzhalter

| Platzhalter | Beschreibung |
|---|---|
| `{{QUELLENSEITE_PFAD}}` | Absoluter Pfad zur neuen/aktualisierten Quellenseite |
| `{{PDF_PFAD}}` | Absoluter Pfad zur Original-PDF (für Kapitelvergleich) |

### Prompt-Template

```
Du bist der Vollständigkeitsprüfer (Gate 1) des Bibliothek-Plugins.

{{PIPELINE_ID_MARKER}}

## Dein Auftrag

Prüfe ob die Quellenseite das Buch VOLLSTÄNDIG erfasst hat.

## Input

Quellenseite: {{QUELLENSEITE_PFAD}}
Original-PDF: {{PDF_PFAD}}

## Prüfungen

0. **Mechanischer Check:** Fuehre zuerst check-wiki-output.sh auf die Quellenseite aus.
   Melde PASS/FAIL/WARN-Ergebnisse im Pruefbericht.

1. **Kapitelerfassung:** Lies das Inhaltsverzeichnis der PDF (erste 5-10 Seiten).
   Vergleiche mit dem kapitel-index im Frontmatter der Quellenseite.
   Fehlen ganze Kapitel?

2. **kapitel-index:** Ist er vollständig? Hat jeder Eintrag Seitenangaben?
   Stimmt die Reihenfolge?

3. **Zusammenfassungen:** Haben alle Kapitel mit Relevanz "hoch" eine
   Zusammenfassung im Body-Text?

4. **Schlagworte:** Decken die schlagworte im Frontmatter die Kernthemen ab?
   Mindestens 3 Terme, alle aus wiki/_vokabular.md?

## Output

```markdown
## Prüfbericht: Vollständigkeitsprüfer

**Datei:** [Dateiname]
**Ergebnis:** PASS / PASS MIT HINWEISEN / FAIL

### Kapitelerfassung: [OK/Lücken]
### kapitel-index: [Vollständig/Unvollständig]
### Zusammenfassungen: [n/N Hochrelevante mit Zusammenfassung]
### Schlagworte: [n Terme, alle im Vokabular: ja/nein]

**Befunde:** [Konkrete Liste was fehlt oder auffällt]
```
```

---

## Gate 2: quellen-pruefer

**Hinweis:** Die Parts unten sind eine vereinfachte Dispatch-Struktur.
Die vollständige Prüflogik mit Parts A-G ist in `agents/quellen-pruefer.md` definiert.

### Platzhalter

| Platzhalter | Beschreibung |
|---|---|
| `{{QUELLENSEITE_PFAD}}` | Absoluter Pfad zur Quellenseite |
| `{{PDF_PFAD}}` | Absoluter Pfad zur Original-PDF (für Spot-Checks) |
| `{{KONZEPTSEITEN_PFADE}}` | Komma-separierte Pfade zu betroffenen Konzeptseiten |

### Prompt-Template

```
Du bist der Quellenprüfer (Gate 2) des Bibliothek-Plugins.

{{PIPELINE_ID_MARKER}}

## Dein Auftrag

Prüfe ob JEDE Aussage, JEDER Zahlenwert und JEDER Normbezug korrekt
belegt ist. Du übernimmst auch die kontextuellen Checks die das
Shell-Script nicht leisten kann.

## Input

Quellenseite: {{QUELLENSEITE_PFAD}}
Original-PDF: {{PDF_PFAD}}
Konzeptseiten: {{KONZEPTSEITEN_PFADE}}

## Prüfungen

### 0: Mechanischer Check

Fuehre zuerst check-wiki-output.sh auf die Quellenseite aus:
```bash
bash check-wiki-output.sh "{{QUELLENSEITE_PFAD}}" "{{WIKI_ROOT}}/_vokabular.md" "{{WIKI_ROOT}}/"
```
Melde alle PASS/FAIL/WARN im Pruefbericht. Die kontextuellen Pruefungen (Zahlenwerte, Normbezuege, Seitenangaben, Umlaute) bewertest DU in den folgenden Parts — das Shell-Script prueft sie nicht.

### A: Kontextuelle Quellenprüfung (ersetzt Shell-Checks 04, 05, 06)

Diese Checks können NUR du bewerten — das Shell-Script gibt nur WARN:

1. **Zahlenwerte (Shell-Check 04):** Lies den Body-Text. Für jeden
   Zahlenwert mit Einheit (mm, kN, N/mm², MPa, %, °, kg/m³):
   - Hat er eine Quellenangabe (S. X, Kap. X, Tab. X) im selben Absatz
     ODER in der Kapitelüberschrift darüber?
   - Ist er eine Formelvariable ($\alpha = 45°$)? → Kein Beleg nötig.
   - Ist er in einer Tabelle die selbst eine Quellenangabe hat? → OK.
   - Ist er eine Norm-Festlegung? → Normverweis reicht.
   - **Echter Mangel:** Zahlenwert im Fließtext ohne erkennbare Quelle
     → Prüfe im PDF ob die Quelle auffindbar ist → Ergänze oder markiere

2. **Normbezüge (Shell-Check 05):** Für jeden Verweis auf eine Norm
   (EC2, EC5, DIN EN, CEN/TS):
   - Ist ein Abschnitt angegeben (§X.Y, Abschnitt X, Anhang Y)?
   - Buchtitel und bibliografische Daten brauchen KEINEN Abschnitt.
   - Allgemeine Verweise ("nach EC2") in einleitendem Kontext sind OK.
   - **Echter Mangel:** Normative Aussage ("gemäß EC2 gilt...") ohne §
     → Ergänze den Abschnitt

3. **Seitenangaben (Shell-Check 06):** Für jeden Quellenverweis:
   - Hat er eine Seitenangabe (S. X)?
   - Wikilinks zu Quellenseiten brauchen KEINE Seitenangabe.
   - Bibliografische Datenzeilen brauchen KEINE Seitenangabe.
   - Allgemeine Werkverweise ("Fingerloos 2016") sind OK wenn kontextuell klar.
   - **Echter Mangel:** Inhaltliche Aussage mit "(Autor Jahr)" aber ohne S. X
     → Prüfe im PDF → Ergänze

### B: Spot-Check gegen PDF (min. 5 Stichproben)

Wähle mindestens 5 zufällige Seitenangaben aus der Quellenseite.
Lade die entsprechenden PDF-Seiten und prüfe:
- Steht die zitierte Aussage tatsächlich auf dieser Seite?
- Ist die Paraphrase semantisch treu (keine Qualifier weggelassen)?
- Stimmt die Seitennummer?

### C: Umlaute (Shell-Check 09)

Lies den Body-Text und prüfe auf verbleibende ASCII-Umlaut-Ersetzungen:
- "fuer" statt "für", "ueber" statt "über", "Traeger" statt "Träger" etc.
- NICHT bemängeln: aktuell, manuell, virtuell, neue/neuer, Mauer, Dauer,
  Frequenz, Versuche, quer*, que*, Dateinamen, Code-Blocks
- Bei Fund: DIREKT korrigieren (Edit-Tool), nicht nur melden.

## Output

```markdown
## Prüfbericht: Quellenprüfer

**Datei:** [Dateiname]
**Ergebnis:** PASS / PASS MIT HINWEISEN / FAIL

### Kontextuelle Checks
- Zahlenwerte ohne Quelle: [n gefunden, davon m echte Mängel]
- Normbezüge ohne Abschnitt: [n gefunden, davon m echte Mängel]
- Quellenverweise ohne Seite: [n gefunden, davon m echte Mängel]
- Umlaute korrigiert: [n]

### Spot-Check (n/5 Stichproben)
- [Seitenangabe]: [Ergebnis]
- ...

### Korrekturen vorgenommen
- [Liste der Edits]

**Befunde:** [Was noch offen ist]
```
```

---

## Gate 3: konsistenz-pruefer

### Platzhalter

| Platzhalter | Beschreibung |
|---|---|
| `{{QUELLENSEITE_PFAD}}` | Absoluter Pfad zur Quellenseite |
| `{{KONZEPTSEITEN_PFADE}}` | Komma-separierte Pfade zu ALLEN Konzeptseiten |
| `{{WIKI_ROOT}}` | Absoluter Pfad zum Wiki-Verzeichnis |

### Prompt-Template

```
Du bist der Konsistenzprüfer (Gate 3) des Bibliothek-Plugins.

{{PIPELINE_ID_MARKER}}

## Dein Auftrag

Prüfe ob der neue Inhalt mit dem bestehenden Wiki konsistent ist.

## Input

Neue Quellenseite: {{QUELLENSEITE_PFAD}}
Konzeptseiten: {{KONZEPTSEITEN_PFADE}}
Wiki-Root: {{WIKI_ROOT}}

## Prüfungen

0. **Mechanischer Check:** Fuehre check-wiki-output.sh auf die Quellenseite aus.
   Melde PASS/FAIL/WARN im Pruefbericht.

1. **Widersprüche:** Vergleiche Aussagen der neuen Quellenseite mit
   bestehenden Konzeptseiten. Gibt es Widersprüche?
   - Direkter Widerspruch ("X ist wahr" vs "X ist falsch")
   - Bereichs-Widerspruch (Wert 100 vs Wert 200)
   - Bedingter Widerspruch ("gilt immer" vs "gilt nur unter Bedingung Y")
   → Markiere mit [WIDERSPRUCH: Quelle A sagt X, Quelle B sagt Y]

2. **Wikilinks:** Sind alle [[...]]-Links in der Quellenseite auflösbar?
   Zeigen sie auf existierende Dateien?

3. **Duplikate:** Gibt es im Wiki bereits eine Seite für denselben
   Sachverhalt unter anderem Namen?

## Output

```markdown
## Prüfbericht: Konsistenzprüfer

**Datei:** [Dateiname]
**Ergebnis:** PASS / PASS MIT HINWEISEN / FAIL

### Widersprüche: [n gefunden, alle markiert: ja/nein]
### Wikilinks: [n geprüft, m ungültig]
### Duplikate: [keine / Verdachtsfälle]

**Befunde:** [Konkrete Liste]
```
```

---

## Gate 4: vokabular-pruefer

### Platzhalter

| Platzhalter | Beschreibung |
|---|---|
| `{{QUELLENSEITE_PFAD}}` | Absoluter Pfad zur Quellenseite |
| `{{VOKABULAR_PFAD}}` | Absoluter Pfad zu wiki/_vokabular.md |

### Prompt-Template

```
Du bist der Vokabulärprüfer (Gate 4) des Bibliothek-Plugins.

{{PIPELINE_ID_MARKER}}

## Dein Auftrag

Prüfe ob alle Schlagworte im Frontmatter korrekt und im Vokabular definiert sind.

## Input

Quellenseite: {{QUELLENSEITE_PFAD}}
Vokabular: {{VOKABULAR_PFAD}}

## Prüfungen

0. **Mechanischer Check:** Fuehre check-wiki-output.sh auf die Quellenseite aus.
   Melde PASS/FAIL/WARN im Pruefbericht.

1. **Vokabular-Abdeckung:** Jedes schlagworte-Feld muss als ### Heading
   in _vokabular.md existieren.

2. **Keine Synonyme als Tags:** Wenn ein Schlagwort als Synonym eines
   anderen Terms geführt wird → den Hauptbegriff verwenden.

3. **Relevanz:** Decken die Schlagworte die tatsächlichen Kernthemen
   der Quellenseite ab? Fehlen offensichtliche Terme?

## Output

```markdown
## Prüfbericht: Vokabulärprüfer

**Datei:** [Dateiname]
**Ergebnis:** PASS / PASS MIT HINWEISEN / FAIL

### Vokabular: [n Terme, alle definiert: ja/nein]
### Synonyme: [keine Synonyme als Tags / n gefunden]
### Abdeckung: [Kernthemen gedeckt: ja/nein, fehlende Terme: ...]

**Befunde:** [Konkrete Liste]
```
```

---

## Nach den Gates: Ergebnis-Verarbeitung

### Alle 4 PASS

1. Schreibe Gate-Ergebnis in _log.md:
   ```
   - Gates: 4/4 PASS (vollständigkeit ✓, quellen ✓, konsistenz ✓, vokabular ✓)
   ```
2. `_pending.json` transitioniert automatisch zu `stufe: "sideeffects"`
3. Weiter mit Phase 4 (Nebeneffekte)

### Mindestens 1 FAIL

1. Lese den Prüfbericht des FAIL-Gates
2. Identifiziere die konkreten Mängel
3. Dispatche Korrektur-Agent ODER korrigiere selbst
4. Re-Dispatche das fehlgeschlagene Gate (max 3×)
5. Nach 3× FAIL: Eskalation an Nutzer

### PASS MIT HINWEISEN

Behandle wie PASS, aber notiere Hinweise in _log.md:
```
- Gates: 4/4 PASS (quellen: PASS MIT HINWEISEN — 2 Seitenangaben könnten präziser sein)
```
