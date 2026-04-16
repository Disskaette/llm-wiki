# SPEC-014: Quellen-Zuordnung + Enforcement-Haertung

**Status:** In Progress
**Version:** 1.2
**Erstellt:** 2026-04-16
**Aktualisiert:** 2026-04-16

## Zusammenfassung

Sieben zusammenhaengende Verbesserungen die aus der gescheiterten Synthese-Session
vom 2026-04-15 abgeleitet sind:

1. **`/zuordnung` — Neuer Skill** mit eigenem Worker-Agent. Laedt alle
   Quellen-Zusammenfassungen + Konzeptseiten in einen Agent und baut eine
   inhaltliche Zuordnungs-Matrix. Fuehrt gleichzeitig den Schlagwort-Audit
   durch (fehlende Tags patchen, neue Terme vorschlagen). Schreibt
   Konzept-Rueckverweise (`relevant-fuer:`) auf Quellenseiten.
2. **Machine-Law fuer Mapping-Aktualitaet** — Synthese blockiert wenn
   Mapping veraltet ist.
3. **check-wiki-output.sh Haertung** — Drei neue deterministische Checks
   die in der Session gefehlt haben.
4. **Context-Budget-Klarstellung** — Dispatch-Templates und Skills
   dokumentieren explizit: Opus = 1M, Sonnet = 200K, Split NUR ueber 700K.
5. **Template-Lese-Pflicht** — Neuer Hook blockiert Worker-Dispatch wenn
   das zugehoerige Dispatch-Template nicht im Transcript gelesen wurde.
6. **Session-Befund-Nachzuegler** — Phase-5-Guard (keine Nebeneffekte bei
   offenen Gates), Konsistenz-Pruefer globale Link-Suche, Gate-Agents
   sammeln alle Maengel statt nach erstem FAIL abzubrechen.
7. **Dual-Link ueberall** — Eine Regel: Jeder Quellenbeleg ist ein
   Dual-Link (Quellenseite + PDF), im Fliesstext UND in Tabellen.
   Shell-Check 21 erzwingt das als FAIL. Tabellen-Sonderregel gestrichen.

### Befund: Was ist schiefgelaufen (2026-04-15)

| Schicht | Problem | Ursache |
|---------|---------|---------|
| Prompt-Law | Worker schrieb `[@key, S. N]` statt Dual-Links | Template korrekt, Worker ignoriert, kein Gate prueft FORMAT |
| Prompt-Law | Worker schrieb ASCII-Umlaute statt Unicode | Template korrekt, Worker ignoriert |
| Prompt-Law | Orchestrator hat Skills nicht gelesen vor Dispatch | guard-wiki-writes.sh sah alten Skill-Call im Transcript |
| Prompt-Law | Orchestrator hat Gates freestyle dispatcht | gate-dispatch-template.md nicht gelesen |
| Machine-Law | check-wiki-output.sh prueft nicht auf `[@`-Syntax | Kein Check vorhanden |
| Machine-Law | check-wiki-output.sh prueft nicht auf ASCII-Umlaute | Wurde explizit entfernt ("braucht Kontext") |
| Machine-Law | WIDERSPRUCH-Regex zu eng fuer Abkuerzungen | `[A-Z][a-z]+` matched nicht ISB, EC2, NA |
| Machine-Law | Orchestrator loeschte `_pending.json` manuell | Kein Hook verhindert das |
| Workflow | Synthese findet Quellen nur per Schlagwort | Ingest-Zuordnung oberflaechlich, kein inhaltliches Matching |
| Workflow | Schlagwort-Rueckverteilung unvollstaendig | Synthese sieht nur Subset der Quellen |
| Prompt-Law | Orchestrator hat Dispatch-Template nicht gelesen vor Worker-Start | Keine mechanische Pruefung ob Template gelesen wurde |
| Machine-Law | Orchestrator umging Gate-Re-Dispatch: manuell editiert, Shell-Check, "PASS" deklariert | Kein Check ob `_pending.json` stufe=sideeffects vor Phase 5 |
| Machine-Law | Konsistenz-Pruefer meldete [[ec2]] als toten Link (existiert in normen/) | Part C sucht nur in quellen/ + konzepte/, nicht global |
| Machine-Law | Gate-Agents brachen nach erstem FAIL ab, Pandoc nie bemaengelt | Kein "sammle alle Maengel"-Instruktion im Template |
| Machine-Law | Nur PDF-Links auf Konzeptseite, kein Quellenseiten-Link daneben | Dual-Link-Format nicht mechanisch geprueft |
| Workflow | Orchestrator splittet unnoetig auf mehrere Agents | Context-Budget-Angst, 1M nicht dokumentiert |

---

## Paket 1: `/zuordnung` — Neuer Skill

### Motivation

Ingest sieht immer nur EINE Quelle und ordnet per Schlagwort zu. Das ist
zwangslaeufig oberflaechlich — Zusammenhaenge die erst im Vergleich mehrerer
Quellen sichtbar werden, kann der Ingest-Agent nicht erkennen.

Synthese geht dann pro Konzept los und sucht Quellen per Schlagwort — aber
wenn die Zuordnung vom Ingest lueckenhaft war, fehlen Quellen. Der Nutzer
muss manuell nachsteuern ("Pruef die Quellen nicht nur auf Schlagwoerter,
sondern auf alles was mit dem Konzept zu tun hat").

### Loesung

Ein dedizierter Skill `/zuordnung` mit eigenem Worker-Agent der ALLE Quellen
und ALLE Konzepte gleichzeitig im Kontext hat. Zwei Jobs, ein Durchlauf:

**Job 1: Quelle → Konzept (inhaltlich, nicht nur per Tag)**
- Liest alle Quellen-Zusammenfassungen (Frontmatter + erste 50 Zeilen Body)
- Liest alle Konzeptseiten (Frontmatter + Zusammenfassung)
- Liest alle reifen Konzept-Kandidaten aus `_konzept-reife.md`
- Ordnet jede Quelle inhaltlich zu: Welche Konzepte behandelt sie substanziell?
- Begruendung pro Zuordnung (1 Satz)
- Neue Kandidaten: Wenn ein Thema in >=2 Quellen substanziell vorkommt aber
  weder als Konzeptseite noch als Kandidat existiert → neuer Kandidat

**Job 2: Schlagwort-Audit (fehlende Tags patchen, neue Terme vorschlagen)**
- Fuer jede Quelle: Behandelt sie ein Thema ausfuehrlich das nicht in ihren
  Schlagwoertern steht? → Patch-Vorschlag
- Fuer neue Terme die in >=2 Quellen substanziell vorkommen und im Vokabular
  fehlen → Vorschlag fuer `_vokabular.md`
- Rueckwaertsverteilung: Wenn ein neues Schlagwort eingefuehrt wird, ALLE
  Quellen identifizieren die es erhalten sollten (nicht nur die im aktuellen
  Synthese-Durchlauf sichtbaren)

**Job 3: Konzept-Rueckverweise auf Quellenseiten (`relevant-fuer:` Feld)**
- Fuer jede Quellenseite: Patche das Frontmatter-Feld `relevant-fuer:` mit
  der Liste der Konzeptseiten die diese Quelle inhaltlich fuettert.
- Nur additiv — bestehende Eintraege nie entfernen.
- Ermoeglicht in Obsidian: Quellenseite oeffnen → sofort sehen welche Konzepte
  darauf aufbauen. Ohne dieses Feld ist die Zuordnung nur zentral im Mapping
  sichtbar, nicht auf der Quellenseite selbst.
- Obsidian-Graph zeigt dann Quelle→Konzept-Kanten.

Beispiel Frontmatter nach Patch:
```yaml
schlagworte: [Aufhängebewehrung, Indirekte Auflagerung, Querkraft]
relevant-fuer: [aufhaengebewehrung, indirekte-auflagerung, direkte-auflagerung]
```

### Artefakt: `wiki/_quellen-mapping.md`

```yaml
---
type: meta
title: "Quellen-Zuordnung"
updated: 2026-04-16
mapping-version: 1
quellen-stand: 45        # Anzahl Quellen beim letzten Mapping
konzepte-stand: 12       # Anzahl Konzeptseiten beim letzten Mapping
kandidaten-stand: 8      # Anzahl reifer Kandidaten beim letzten Mapping
letzter-log-hash: "abc"  # Erster Satz des juengsten _log.md-Eintrags (fuer Drift-Erkennung)
---

# Quellen-Zuordnung

## Zuordnungs-Matrix

| Quelle | Konzepte | Kandidaten | Begruendung |
|--------|----------|------------|-------------|
| [[fingerloos2016]] | [[aufhaengebewehrung]], [[indirekte-auflagerung]], [[direkte-auflagerung]] | Stabwerkmodell | EC2-Kommentar mit ausfuehrlichen Kapiteln zu allen drei Themen |
| [[beer2015]] | [[aufhaengebewehrung]], [[direkte-auflagerung]] | — | Bewehrungstechnik-Fokus, Kap. 8 Auflagerdetails |
| ... | ... | ... | ... |

## Nicht zugeordnete Quellen

Quellen die keinem Konzept und keinem Kandidaten zugeordnet werden konnten:
- [[quelle-x]] — Grund: Thematisch ausserhalb des aktuellen Wiki-Fokus

## Schlagwort-Audit

### Fehlende Zuordnungen (Patches)
| Quelle | Fehlendes Schlagwort | Evidenz |
|--------|---------------------|---------|
| [[oudjene2013]] | Finite-Elemente-Methode | Titel + Kap. 3-5 FE-Analyse |
| ... | ... | ... |

### Neue Terme (Vokabular-Vorschlaege)
| Term | Quellen | Status |
|------|---------|--------|
| Stabwerkmodell | fingerloos2016, zilch2010, beer2015 | vorgeschlagen |
| ... | ... | ... |

## Konzept-Kandidaten (neu entdeckt)
| Kandidat | Quellen (>=2) | Reife |
|----------|---------------|-------|
| Stabwerkmodell | fingerloos2016, zilch2010, beer2015 | reif |
| ... | ... | ... |
```

### Trigger

`/zuordnung` wird ausgefuehrt:
1. **Nach jedem Ingest** — neue Quelle muss allen Konzepten zugeordnet werden
2. **Nach jeder neuen Konzeptseite** — oder Konzeptseite die nur Template ist
3. **Manuell** — Nutzer ruft `/zuordnung` auf
4. **Automatisch vor Synthese** — wenn Mapping veraltet (siehe Paket 2)

### Worker-Agent

Neuer Agent `bibliothek:zuordnung-worker`:
- Liest: alle `wiki/quellen/*.md` (Frontmatter + Zusammenfassung), alle
  `wiki/konzepte/*.md` (Frontmatter + Zusammenfassung), `_konzept-reife.md`,
  `_vokabular.md`, `_schlagwort-vorschlaege.md`
- Schreibt: `_quellen-mapping.md` (komplett neu, kein Merge)
- Schreibt: Schlagwort-Patches auf Quellenseiten-Frontmatter `schlagworte:` (nur additiv)
- Schreibt: Konzept-Rueckverweise auf Quellenseiten-Frontmatter `relevant-fuer:` (nur additiv)
- Schreibt: neue Terme in `_vokabular.md` (nur additiv)
- Schreibt: neue Kandidaten in `_konzept-reife.md`
- Tools: Read, Write, Edit, Grep, Glob
- Model: Opus (braucht alle Quellen im Kontext)

### Dispatch-Template

Neues Template `governance/zuordnung-dispatch-template.md` mit Platzhaltern:
- `{{QUELLEN_ZUSAMMENFASSUNGEN}}` — Frontmatter + erste 50 Zeilen jeder Quelle
- `{{KONZEPT_ZUSAMMENFASSUNGEN}}` — Frontmatter + Zusammenfassung jeder Konzeptseite
- `{{KONZEPT_REIFE_INHALT}}` — inline
- `{{VOKABULAR_TERME}}` — inline
- `{{SCHLAGWORT_VORSCHLAEGE_INHALT}}` — inline
- `{{WIKI_ROOT}}` — Pfad

### Synthese-Integration

Phase 0 von Synthese aendert sich:
- **Alt (Phase 0):** Quellen per Schlagwort suchen via `grep`
- **Neu (Phase 0):** `_quellen-mapping.md` lesen. Alle dort fuer das
  Zielkonzept gelisteten Quellen + Kandidaten-Zuordnungen inline einfuegen.
  Kein eigenes Suchen mehr.

Phase 2e (Discovery im Worker) bleibt — aber wird entlastet weil die
grobe Zuordnung schon steht. Discovery konzentriert sich auf Feinheiten
die erst beim Tiefenvergleich sichtbar werden.

### Gates fuer `/zuordnung`

Minimales Gate-Set (kein Pipeline-Lock noetig — `/zuordnung` schreibt keine
Konzeptseiten, nur Meta-Dateien):

1. **Konsistenz-Check:** Jede zugeordnete Quelle existiert als Datei?
   Jedes zugeordnete Konzept existiert als Datei oder Kandidat?
2. **Vollstaendigkeits-Check:** Jede Quelle in `wiki/quellen/` taucht in
   der Matrix auf? Kein Orphan?
3. **Vokabular-Check:** Jeder vorgeschlagene Patch-Term existiert im Vokabular?
4. **Rueckverweis-Check:** Fuer jede Zuordnung in der Matrix: Hat die
   Quellenseite das Konzept in `relevant-fuer:`? Bidirektionale Konsistenz.

Diese Checks sind deterministisch und koennen per Shell laufen (kein Agent noetig).
Neues Script: `check-zuordnung-output.sh`.

---

## Paket 2: Machine-Law fuer Mapping-Aktualitaet

### Mechanismus

Erweiterung von `guard-pipeline-lock.sh` ODER neuer Hook
`guard-mapping-freshness.sh` (PreToolUse auf Agent-Dispatch):

**Prueflogik:**
1. Existiert `wiki/_quellen-mapping.md`? Falls nein → Block:
   "Kein Quellen-Mapping vorhanden. Erst `/zuordnung` ausfuehren."
2. Lies `mapping-version` und `updated` aus dem Frontmatter
3. Lies `_log.md`: Gibt es Eintraege neuer als `updated`?
   (Vergleich: juengster Log-Eintrag vs. Mapping-Timestamp)
4. Zaehle Quellen in `wiki/quellen/` und vergleiche mit `quellen-stand`
5. Zaehle Konzepte in `wiki/konzepte/` und vergleiche mit `konzepte-stand`
6. Falls delta > 0 → Block:
   "Mapping veraltet (N neue Quellen / M neue Konzepte seit letztem Mapping).
   Erst `/zuordnung` ausfuehren."

**Wann aktiv:** Nur wenn im Transcript ein Synthese-Skill-Call steht
(gleiche Logik wie guard-wiki-writes.sh). Blockiert nicht Ingest oder
andere Skills.

**Alternative — weniger aggressiv:** Statt Block nur Warnung via
`inject-lock-warning.sh`-Muster (UserPromptSubmit). Der Orchestrator
sieht die Warnung, kann aber trotzdem fortfahren. Riskanter weil der
Orchestrator die Warnung ignorieren kann.

**Empfehlung:** Block (exit 2). Der Orchestrator hat in der Session bewiesen
dass er Warnungen ignoriert. Mechanische Blockade ist zuverlaessiger.

---

## Paket 3: check-wiki-output.sh Haertung

### Check 19: Pandoc-Zitat-Syntax (NUR Konzeptseiten)

```bash
# Nur bei type: konzept pruefen (Quellenseiten verwenden kein Dual-Link)
if [ "$FM_TYPE" = "konzept" ] || [ "$FM_TYPE" = "verfahren" ] || [ "$FM_TYPE" = "baustoff" ]; then
    PANDOC_REFS=$(grep -cE '\[@[a-z_]+[0-9]*' "$FILE" 2>/dev/null) || PANDOC_REFS=0
    if [ "$PANDOC_REFS" -gt 0 ]; then
        check FAIL "19-kein-pandoc" "Pandoc-Zitate gefunden ($PANDOC_REFS Stellen). Dual-Links verwenden: [[datei.pdf#page=N|Autor, S. N]]"
    else
        check PASS "19-kein-pandoc" ""
    fi
fi
```

**Regex:** `\[@[a-z_]+[0-9]*` matched `[@fingerloos2016`, `[@beer2015` etc.
Kein False Positive auf `[WIDERSPRUCH]` oder `[DISCOVERY]` (die haben kein `@`).

### Check 20: Deterministische Umlaut-Pruefung

```bash
# Woerter die im Wiki-Text IMMER Umlaute haben muessen
# (nicht in Dateinamen, Code-Blocks, Frontmatter-Werten)
BODY=$(awk '/^---$/{n++; next} n>=2{print}' "$FILE")
UMLAUT_ISSUES=""
for WORD in "fuer:fuer" "ueber:ueber" "Laenge:Laenge" "Staerke:Staerke" \
            "Traeger:Traeger" "Stuetze:Stuetze" "Hoehe:Hoehe" "Breite:Breite" \
            "Flaeche:Flaeche" "Spannungsfeld:Spannungsfeld" "genuegt:genuegt" \
            "muesste:muesste" "waere:waere" "koennte:koennte" "Gueltigkeit:Gueltigkeit" \
            "Pruefung:Pruefung" "Ausfuehrung:Ausfuehrung" "Einfuehrung:Einfuehrung" \
            "Buegel:Buegel" "stuetzend:stuetzend" "Zulaessig:Zulaessig"; do
    ASCII="${WORD%%:*}"
    if echo "$BODY" | grep -qw "$ASCII" 2>/dev/null; then
        UMLAUT_ISSUES="${UMLAUT_ISSUES}${ASCII}, "
    fi
done
if [ -n "$UMLAUT_ISSUES" ]; then
    check FAIL "20-umlaute-body" "ASCII-Umlaute im Body-Text: ${UMLAUT_ISSUES%, }"
else
    check PASS "20-umlaute-body" ""
fi
```

**Woerterliste:** Nur Woerter die IMMER Umlaute haben (keine Homographen).
"fuer" ist immer falsch im Wiki-Text. "aktuell" ist korrekt (kein Umlaut).
Die Liste wird in `config/umlaut-woerter.txt` ausgelagert fuer Erweiterbarkeit.

### Check 15 fix: WIDERSPRUCH-Regex lockern

**Alt:**
```
$0 !~ /[A-Z][a-z]+ [0-9]{4}.*[A-Z][a-z]+ [0-9]{4}/
```

**Neu:**
```
$0 !~ /[A-Z][A-Za-z/.-]+ [0-9]{4}.*[A-Z][A-Za-z/.-]+ [0-9]{4}/
```

Das matched jetzt auch:
- `ISB 2013` (nur Grossbuchstaben)
- `EC2 2013` (Buchstabe+Zahl)
- `CEN/TS 2019` (mit Slash)
- `Zilch/Zehetmaier 2010` (mit Slash)

Weiterhin nicht gematched (gewollt): Zahlen am Anfang, leere Strings.

---

## Paket 4: Context-Budget-Klarstellung

### Aenderungen in Dateien

**1. `synthese-dispatch-template.md` — Neue Sektion nach KONTEXT:**

```
═══════════════════════════════════════════════════════
CONTEXT-BUDGET — FAKTEN
═══════════════════════════════════════════════════════

Du laeuft als Opus-Worker mit 1.000.000 Tokens Context.
Die inline eingefuegten Quellenseiten belegen typischerweise 50-400K Tokens.
Du hast IMMER genug Platz fuer alle Quellen eines Konzepts.

KEIN SPLIT erforderlich wenn Quellenmaterial < 700K Tokens.
KEIN Aufteilen auf mehrere Agents.
KEIN "ich mache das in Batches".

Wenn du glaubst der Context reicht nicht: Du hast 1M Tokens.
Lies die Quellen. Schreib die Seite. Fertig.
```

**2. `plugin/skills/synthese/SKILL.md` — Phase 0 Token-Budget realistisch:**

Alt (Z.81-83):
```
3. **Token-Budget pruefen:**
   - Zaehlen: Zielseite + alle Quell-Kapitel?
   - Falls >700K Tokens: Split-Plan erstellen (Quelle 1-2, dann 3-4, ...)
   - Falls <100K Tokens: Single-Shot moeglich
```

Neu:
```
3. **Token-Budget einordnen:**
   - Opus-Worker hat 1M Tokens. Sonnet-Worker hat 200K.
   - Synthese-Worker laeuft IMMER auf Opus (1M).
   - Typisches Quellenmaterial fuer ein Konzept: 50-400K Tokens.
   - Split NUR wenn Quellenmaterial > 700K Tokens (>20 ausfuehrliche Quellen).
   - Bei <700K: KEIN Split, KEIN Batch, alles in einen Worker.
```

**3. `plugin/skills/synthese/SKILL.md` — Phase 0 Quellen-Identifikation:**

Alt (Phase 0, Schritt 2):
```
2. **Referenzierte Quellen identifizieren:**
   - Alle Quellenangaben im Text durchlaufen
   - Alle Wikilinks zu Quellenseiten
   - Norm-Paragraph-Verweise
```

Neu:
```
2. **Quellen aus Mapping laden:**
   - Lies `wiki/_quellen-mapping.md`
   - Alle dort fuer das Zielkonzept gelisteten Quellen UND Kandidaten-Zuordnungen
   - KEIN eigenes Suchen per Schlagwort — Mapping ist Single Source of Truth
   - Falls Mapping veraltet: `/zuordnung` zuerst ausfuehren (Hook blockiert sonst)
```

**4. `plugin/governance/gate-dispatch-template.md` — Modellwahl-Tabelle erweitern:**

Neue Zeile in der Tabelle (nach dem bestehenden Block):

```
## Context-Budget-Referenz

| Modell | Context | Typischer Einsatz |
|--------|---------|-------------------|
| Opus   | 1.000.000 Tokens | Synthese-Worker, Zuordnung-Worker, Quellen-Pruefer |
| Sonnet | 200.000 Tokens | Konsistenz-Pruefer, Vokabular-Pruefer, Vollstaendigkeits-Pruefer (kleine PDFs) |

Split-Schwelle: 700K Tokens Quellenmaterial. Darunter: KEIN Split.
```

---

## Paket 5: Template-Lese-Pflicht vor Worker-Dispatch

### Motivation

In der gescheiterten Session hat der Orchestrator den Synthese-Worker dispatcht
OHNE vorher das Dispatch-Template zu lesen. Ergebnis: Freestyle-Prompt, Pandoc-
Syntax, ASCII-Umlaute. Die Regel "IMMER Template verwenden" (SKILL.md Z.131)
ist Prompt-Law — und Prompt-Law hat versagt.

### Loesung: `guard-dispatch-template.sh` (PreToolUse auf Agent)

Neuer Hook der bei jedem `bibliothek:*-worker`-Dispatch prueft ob das zugehoerige
Template im Transcript gelesen wurde (Read-Tool-Call auf die Template-Datei).

**Template-Mapping:**

| Worker | Pflicht-Template |
|--------|-----------------|
| `bibliothek:ingest-worker` | `governance/ingest-dispatch-template.md` |
| `bibliothek:synthese-worker` | `governance/synthese-dispatch-template.md` |
| `bibliothek:zuordnung-worker` | `governance/zuordnung-dispatch-template.md` |

**Prueflogik:**
1. Extrahiere `subagent_type` aus `tool_input`
2. Matched auf `bibliothek:*-worker`? Falls nein → exit 0 (durchlassen)
3. Bestimme das Pflicht-Template aus dem Mapping
4. Suche im Transcript nach einem Read-Tool-Call auf die Template-Datei
   (gleiche grep-auf-Transcript-Logik wie `guard-wiki-writes.sh`)
5. Gefunden → exit 0
6. Nicht gefunden → exit 2 + stderr:

```
DISPATCH-GATE: Template nicht gelesen.

Du dispatcht [worker-typ] ohne vorher das Dispatch-Template zu lesen.
Lies zuerst: governance/[template-name].md
Dann fuelle die Platzhalter aus und dispatche erneut.
```

**Kein Kontext-Problem:** Reine Transcript-Suche, deterministisch.
Gleiche Architektur wie `guard-wiki-writes.sh` (das nach Skill-Tool-Calls sucht).

### hooks.json-Eintrag

```json
{
  "event": "PreToolUse",
  "matcher": "Agent",
  "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/guard-dispatch-template.sh"
}
```

**Reihenfolge:** `guard-dispatch-template.sh` feuert VOR `guard-pipeline-lock.sh`
(beide auf PreToolUse/Agent). Erst Template-Check, dann Lock-Check. Wenn das
Template nicht gelesen wurde, ist der Lock-Check irrelevant.

---

## Neue Dateien

| Datei | Typ | Beschreibung | Paket |
|-------|-----|-------------|-------|
| `plugin/skills/zuordnung/SKILL.md` | Skill | Skill-Definition fuer `/zuordnung` | 1 |
| `plugin/agents/zuordnung-worker.md` | Agent | Worker-Agent fuer Mapping | 1 |
| `plugin/governance/zuordnung-dispatch-template.md` | Template | Standardisierter Worker-Prompt | 1 |
| `plugin/hooks/guard-mapping-freshness.sh` | Hook | Blockiert Synthese bei veraltetem Mapping | 2 |
| `plugin/hooks/guard-dispatch-template.sh` | Hook | Blockiert Worker-Dispatch ohne Template-Lesung | 5 |
| `plugin/hooks/config/umlaut-woerter.txt` | Config | Woerterliste fuer Check 20 | 3 |
| `tests/test-guard-dispatch-template.sh` | Test | Tests fuer Template-Lese-Pflicht | 5 |
| `tests/test-phase5-guard.sh` | Test | Tests fuer Phase-5-Vorbedingung | 6 |

## Geaenderte Dateien

| Datei | Aenderung | Paket |
|-------|-----------|-------|
| `plugin/hooks/check-wiki-output.sh` | +Check 19 (Pandoc), +Check 20 (Umlaute), +Check 21 (Dual-Link FAIL), Fix Check 15 (WIDERSPRUCH-Regex) | 3, 7 |
| `plugin/skills/synthese/SKILL.md` | Phase 0 nutzt Mapping statt Schlagwort-Suche, Token-Budget realistisch | 1, 4 |
| `plugin/governance/synthese-dispatch-template.md` | +CONTEXT-BUDGET Sektion, TABELLEN-Regel → Dual-Link ueberall | 4, 7 |
| `plugin/governance/gate-dispatch-template.md` | +Context-Budget-Referenz-Tabelle | 4 |
| `plugin/.claude-plugin/hooks.json` | +guard-mapping-freshness.sh, +guard-dispatch-template.sh | 2, 5 |
| `plugin/hooks/guard-wiki-writes.sh` | +`zuordnung` in Skill-Whitelist | 1 |
| `plugin/agents/konsistenz-pruefer.md` | Part C: globale Link-Suche unter wiki/ | 6 |
| `plugin/skills/synthese/SKILL.md` | Phase 5: _pending.json stufe-Check als Vorbedingung | 6 |
| `plugin/hooks/guard-pipeline-lock.sh` | +`bibliothek:zuordnung-worker` in case-Liste | 1 |
| `plugin/skills/using-bibliothek/SKILL.md` | +`/zuordnung` in Routing, +`_quellen-mapping.md` in Meta-Dateien | 1 |
| `docs/specs/INDEX.md` | +SPEC-014 Eintrag | — |
| `docs/specs/SPEC-009-synthese-pipeline.md` | Phase 0 → Mapping (nach Umsetzung) | 1 |

---

## Akzeptanzkriterien

### Paket 1: /zuordnung
- [ ] Skill-Definition `zuordnung/SKILL.md` existiert mit Phasen-Beschreibung
- [ ] Agent-Definition `zuordnung-worker.md` mit Tools: Read, Write, Edit, Grep, Glob
- [ ] Dispatch-Template mit 6 Platzhaltern, ausgefuelltes Template wird an Worker uebergeben
- [ ] Worker liest ALLE Quellen-Zusammenfassungen (Frontmatter + Body-Anfang)
- [ ] Worker liest ALLE Konzeptseiten (Frontmatter + Zusammenfassung)
- [ ] Worker liest `_konzept-reife.md` und beruecksichtigt reife Kandidaten bei der Zuordnung
- [ ] `_quellen-mapping.md` wird geschrieben mit vollstaendiger Matrix
- [ ] Jede Quelle in `wiki/quellen/` taucht in der Matrix auf (kein Orphan)
- [ ] Schlagwort-Patches werden direkt auf Quellenseiten geschrieben (nur additiv)
- [ ] Neue Vokabular-Terme werden in `_vokabular.md` geschrieben (nur additiv)
- [ ] Neue Konzept-Kandidaten werden in `_konzept-reife.md` eingetragen
- [ ] `check-zuordnung-output.sh` verifiziert das Ergebnis (deterministisch)
- [ ] Synthese Phase 0 liest Mapping statt eigene Schlagwort-Suche
- [ ] `guard-wiki-writes.sh` Whitelist enthaelt `zuordnung`
- [ ] `guard-pipeline-lock.sh` case-Liste enthaelt `bibliothek:zuordnung-worker`
- [ ] using-bibliothek SKILL.md Skill-Routing-Tabelle enthaelt `/zuordnung`
- [ ] using-bibliothek SKILL.md Meta-Dateien-Auflistung enthaelt `_quellen-mapping.md`
- [ ] Neue Kandidaten werden in `_konzept-reife.md` geschrieben (nicht nur in Mapping)
- [ ] `relevant-fuer:` Feld auf Quellenseiten gepatcht (nur additiv)
- [ ] Jede Quellenseite mit Konzept-Zuordnung hat `relevant-fuer:` im Frontmatter
- [ ] SPEC-009 wird nach Umsetzung aktualisiert (Phase 0 → Mapping)
- [ ] Kein SubagentStop-Hook fuer zuordnung-worker (kein _pending.json)

### Paket 2: Mapping-Aktualitaet
- [ ] `guard-mapping-freshness.sh` existiert und ist in hooks.json registriert
- [ ] Hook prueft: `_quellen-mapping.md` existiert
- [ ] Hook prueft: Mapping nicht aelter als juengster `_log.md`-Eintrag
- [ ] Hook prueft: `quellen-stand` == Anzahl Dateien in `wiki/quellen/`
- [ ] Hook prueft: `konzepte-stand` == Anzahl Dateien in `wiki/konzepte/`
- [ ] Hook blockiert Synthese-Dispatch bei veraltetem Mapping (exit 2 + stderr)
- [ ] Hook laesst Ingest, Vokabular, Normenupdate, Wiki-Review durch
- [ ] Test-Suite: `tests/test-guard-mapping-freshness.sh` mit >=10 Tests

### Paket 3: Shell-Check-Haertung
- [x] Check 19: `[@`-Syntax auf Konzeptseiten → FAIL
- [x] Check 19: Kein False Positive auf `[WIDERSPRUCH]`, `[DISCOVERY]`
- [x] Check 20: ASCII-Umlaute im Body-Text → FAIL (Woerterliste aus config/)
- [x] Check 20: Frontmatter und Dateinamen nicht betroffen
- [x] Check 15: WIDERSPRUCH-Regex matched ISB, EC2, NA, CEN/TS, Zilch/Zehetmaier
- [x] Bestehende Tests weiterhin PASS (keine Regression)
- [x] Neue Tests fuer Check 19 + 20 in `tests/test-check-wiki-output-discovery.sh`

### Paket 4: Context-Budget
- [x] synthese-dispatch-template.md hat CONTEXT-BUDGET-Sektion mit 1M Tokens explizit
- [x] SKILL.md Phase 0 sagt "Split NUR ueber 700K" statt "Split-Plan erstellen"
- [x] gate-dispatch-template.md hat Context-Budget-Referenz-Tabelle
- [x] Kein Dispatch-Template enthaelt "Batches", "mehrere Sessions" oder aehnliches

### Paket 5: Template-Lese-Pflicht
- [x] `guard-dispatch-template.sh` existiert und ist in hooks.json registriert
- [x] Hook matched auf `bibliothek:*-worker` Dispatches
- [x] Hook prueft: zugehoeriges Dispatch-Template wurde im Transcript gelesen (Read-Call)
- [x] Hook blockiert bei fehlendem Template-Read (exit 2 + stderr mit Template-Pfad)
- [x] Hook laesst Non-Worker-Agents durch (Gate-Agents, Reviewer etc.)
- [x] Template-Mapping: ingest-worker→ingest-template, synthese-worker→synthese-template, zuordnung-worker→zuordnung-template
- [x] Test-Suite: `tests/test-guard-dispatch-template.sh` mit >=10 Tests
- [x] Kein False Positive wenn Template in frueherer Conversation gelesen aber nicht in dieser Session

### Paket 6: Session-Befund-Nachzuegler
- [x] Synthese-Skill Phase 5 prueft `_pending.json` auf `stufe: "sideeffects"` vor Start
- [x] Bei `stufe: "gates"` → Fehlermeldung "Gates nicht bestanden, re-dispatchen"
- [x] Bei fehlender `_pending.json` → Fehlermeldung "Pipeline-Lock fehlt"
- [x] gate-dispatch-template.md sagt explizit: "Manuelles Fixen + Shell-Check ≠ Gate-PASS"
- [x] konsistenz-pruefer.md Part C sucht global unter wiki/ (nicht nur quellen/+konzepte/)
- [x] Keine hartcodierten Verzeichnisnamen in der Link-Suche
- [x] gate-dispatch-template.md: "Bei Step 0 FAIL alle Parts trotzdem durchfuehren"
- [x] Gate-Pruefberichte listen ALLE Maengel (nicht nur den ersten)

### Paket 7: Dual-Link ueberall
- [x] Check 21 in check-wiki-output.sh: PDF-Links ohne Quellenseiten-Link → FAIL (auf Konzeptseiten)
- [x] Gilt fuer Fliesstext UND Tabellen (eine Regel, keine Ausnahmen)
- [x] synthese-dispatch-template.md: "Keine Quellen-Wikilinks in Tabellen" gestrichen
- [x] Stattdessen: "Dual-Link UEBERALL — auch in Tabellen. Pipe-Escaping beachten."
- [x] Kein False Positive auf Quellen-Abschnitt (dort sind nur Quellenseiten-Links ohne PDF OK)

---

## Paket 6: Session-Befund-Nachzuegler (3 Fixes)

### Fix 1: Phase-5-Guard — Keine Nebeneffekte bei offenen Gates

In der Session hat der Orchestrator alle Gates umgangen: manuell editiert,
Shell-Check laufen lassen, "PASS" deklariert, `_pending.json` geloescht.
`advance-pipeline-lock.sh` hat nie gefeuert, `gates_passed` stand bei 0.

**Loesung:** Synthese-Skill Phase 5 bekommt eine nicht-verhandelbare Vorbedingung:

```
<NICHT-VERHANDELBAR>
BEVOR Phase 5 (Nebeneffekte) beginnt:
1. Pruefe `wiki/_pending.json`: Feld `stufe` MUSS "sideeffects" sein.
2. Wenn `stufe` noch "gates": Gates sind NICHT bestanden.
   → Fehlgeschlagene Gates RE-DISPATCHEN (nicht manuell fixen + Shell-Check).
   → Shell-Check ist KEIN Ersatz fuer Gate-Agents.
3. Wenn `_pending.json` nicht existiert: Phase 5 NICHT starten.
   → Meldung: "Pipeline-Lock fehlt. Gates muessen erst laufen."
</NICHT-VERHANDELBAR>
```

Zusaetzlich im gate-dispatch-template.md "Nach den Gates: Ergebnis-Verarbeitung"
klarstellen: "Manuelles Editieren + Shell-Check ist KEIN Gate-PASS. Nur ein
Gate-Agent der PASS zurueckgibt zaehlt."

### Fix 2: Konsistenz-Pruefer — Wikilink-Suche global statt nur quellen/+konzepte/

Der Konsistenz-Pruefer hat `[[ec2]]` und `[[cen-ts-19103]]` als tote Links
gemeldet, obwohl beide in `wiki/normen/` existieren. Ursache: Agent-Definition
Z.79+84 sucht nur in `wiki/konzepte/` und `wiki/quellen/`.

**Fix:** In `plugin/agents/konsistenz-pruefer.md` Part C aendern:

Alt:
```
- Link-Ziel existiert in wiki/konzepte/ oder wiki/quellen/ als Datei
- Prüfe Dateibaum von wiki/konzepte/ und wiki/quellen/
```

Neu:
```
- Link-Ziel existiert als .md-Datei IRGENDWO unter wiki/ (Obsidian sucht global)
- Prüfe: find wiki/ -name "<linkziel>.md" — existiert mindestens ein Treffer?
- NICHT auf bestimmte Unterverzeichnisse beschraenken (normen/, verfahren/,
  baustoff/ etc. koennen je nach Domain existieren oder nicht)
```

Domain-agnostisch: keine hartcodierten Verzeichnisnamen.

### Fix 3: Gate-Agents — Bei Step 0 FAIL trotzdem alle Parts durchfuehren

In der Session brachen die Gate-Agents nach dem ersten FAIL (Step 0: Shell-Check
WIDERSPRUCH-Format) ab, ohne Parts A-G zu pruefen. Dadurch wurde die Pandoc-
Syntax nie bemaengelt.

**Fix:** Im gate-dispatch-template.md bei jedem Gate-Prompt ergaenzen:

```
WICHTIG: Bei Step 0 FAIL trotzdem ALLE nachfolgenden Parts ausfuehren.
Sammle ALLE Maengel in einem Pruefbericht. Nicht nach dem ersten FAIL abbrechen.
Das Gesamtergebnis ist FAIL wenn IRGENDEIN Part FAILt — aber der Bericht
muss ALLE Probleme auflisten, damit sie in einem Durchgang behoben werden.
```

Verhindert den Ping-Pong-Effekt: Gate FAILt fuer Problem A, Fix, Re-Dispatch,
Gate FAILt fuer Problem B, Fix, Re-Dispatch, Gate FAILt fuer Problem C...

---

## Paket 7: Dual-Link ueberall — eine Regel, keine Ausnahmen

### Befund

Dual-Link-Format: `[[quellenseite|Autor Jahr]], [[datei.pdf#page=N|S. N]]`
Erster Link → Wiki-Quellenseite (Zusammenfassung, Kapitelindex).
Zweiter Link → direkt ins PDF (Obsidian oeffnet die Seite).

Bisher galt eine Sonderregel: Tabellen verwenden NUR PDF-Links, keine
Quellenseiten-Links. Begruendung war Markdown-Lesbarkeit — aber die Seiten
werden in Obsidian gelesen, nicht im Texteditor. Die Sonderregel erzeugt
Inkonsistenz und macht den Shell-Check komplex.

### Aenderung

**Eine Regel:** Jeder Quellenbeleg auf Konzeptseiten ist ein Dual-Link.
Im Fliesstext, in Tabellen, ueberall. Keine Ausnahmen.

**Ausnahme nur:** Der `## Quellen`-Abschnitt am Seitenende listet
Quellenseiten-Links ohne PDF (Uebersichts-Sektion, kein Beleg).

### Shell-Check 21

```bash
# Check 21: Dual-Link — jeder PDF-Link muss von Quellenseiten-Link begleitet sein
if [ "$FM_TYPE" = "konzept" ] || [ "$FM_TYPE" = "verfahren" ] || [ "$FM_TYPE" = "baustoff" ]; then
    # Zaehle Zeilen mit PDF-Link aber ohne Quellenseiten-Link
    # Quellen-Abschnitt (## Quellen) ausschliessen
    SOLO_PDF=$(awk '
        /^## Quellen/ { in_quellen=1 }
        /^## [^Q]/ { in_quellen=0 }
        !in_quellen && /\[\[.*\.pdf#page=/ {
            if ($0 !~ /\[\[[a-z_]+[0-9]*[a-z]*\|/) count++
        }
        END { print count+0 }
    ' "$FILE")
    if [ "$SOLO_PDF" -gt 0 ]; then
        check FAIL "21-dual-link" "$SOLO_PDF PDF-Links ohne Quellenseiten-Link. Dual-Link: [[quellenseite|Autor]], [[datei.pdf#page=N|S. N]]"
    else
        check PASS "21-dual-link" ""
    fi
fi
```

### Template-Aenderung

In `synthese-dispatch-template.md` Sektion TABELLEN aendern:

Alt:
```
Zahlenwerte-Tabellen und Norm-Referenzen-Tabellen verwenden
DIESELBEN PDF-Deeplinks wie der Fliesstext. Keine Quellen-Wikilinks
([[quellenkey|...]]) in Tabellen — immer PDF-Links ([[datei.pdf#page=N|...]]).
```

Neu:
```
Zahlenwerte-Tabellen und Norm-Referenzen-Tabellen verwenden
DASSELBE Dual-Link-Format wie der Fliesstext:
[[quellenseite\|Autor Jahr]], [[datei.pdf#page=N\|S. N]]
Pipe-Escaping (\|) in Tabellen PFLICHT fuer beide Links.
```

---

## Synergie-Check: Integration ins bestehende Plugin

### guard-wiki-writes.sh — `/zuordnung` in Whitelist (KRITISCH)

`/zuordnung` schreibt Schlagwort-Patches auf Quellenseiten (`wiki/quellen/*.md`),
neue Terme in `_vokabular.md` und Kandidaten in `_konzept-reife.md`.
All das sind `wiki/**/*.md`-Dateien → `guard-wiki-writes.sh` blockiert sie.

**Fix:** Zeile 36 in guard-wiki-writes.sh erweitern:
```
# Alt:
grep -qE '"skill":"(bibliothek:)?(ingest|synthese|normenupdate|vokabular|wiki-review|obsidian-setup)"'
# Neu:
grep -qE '"skill":"(bibliothek:)?(ingest|synthese|normenupdate|vokabular|wiki-review|obsidian-setup|zuordnung)"'
```

### guard-pipeline-lock.sh — `/zuordnung` sperren bei aktivem Lock

`guard-pipeline-lock.sh` (Z.14-17) prueft nur `bibliothek:ingest-worker` und
`bibliothek:synthese-worker`. `/zuordnung` wuerde durchgelassen, obwohl sie
Quellenseiten-Frontmatter editiert waehrend ein Ingest/Synthese laueft.

**Fix:** `bibliothek:zuordnung-worker` in die case-Liste aufnehmen:
```bash
case "$SUBAGENT_TYPE" in
  bibliothek:ingest-worker|bibliothek:synthese-worker|bibliothek:zuordnung-worker) ;;
  *) exit 0 ;;
esac
```

`/zuordnung` bekommt KEIN eigenes `_pending.json` — sie wird nur blockiert
wenn ein anderer Lock aktiv ist. `create-pipeline-lock.sh` muss NICHT
angepasst werden (matched nur ingest-worker und synthese-worker).

### using-bibliothek SKILL.md — Skill-Routing erweitern

Neue Zeile in der Skill-Routing-Tabelle:
```
| Quellen-Zuordnung pruefen | /zuordnung | "Quellen zuordnen", "Mapping aktualisieren", "Welche Quellen passen zu..." |
```

Neue Zeile in der Meta-Dateien-Auflistung:
```
Quellen-Zuordnung: `wiki/_quellen-mapping.md`
```

### hard-gates.md — Kein neues Gate noetig

`/zuordnung` schreibt keine Konzeptseiten und keine Quellenseiten-Body-Texte.
Sie editiert nur Frontmatter-Felder (`schlagworte:`) und Meta-Dateien.
Die bestehenden 10 Gates decken das ab:
- KEIN-SCHLAGWORT-OHNE-VOKABULAR → `/zuordnung` muss Vokabular pruefen
- Alle anderen Gates betreffen Content-Writes die `/zuordnung` nicht macht

### Discovery-Abgrenzung (SPEC-003 vs. SPEC-014)

| Aspekt | SPEC-003 (Discovery im Worker) | SPEC-014 (/zuordnung) |
|--------|-------------------------------|----------------------|
| Scope | 1 Konzept, Subset der Quellen | ALLE Quellen, ALLE Konzepte |
| Tiefe | Feinheiten beim Tiefenvergleich | Grobe inhaltliche Zuordnung |
| Trigger | Automatisch waehrend Synthese | Vor Synthese, nach Ingest |
| Schreibt | `_vokabular.md`, Quellenseiten-Patches | `_quellen-mapping.md`, `_vokabular.md`, Patches |
| Kandidaten | In `[DISCOVERY]`-Block melden | In `_konzept-reife.md` direkt schreiben |

**Kein Duplikat** — `/zuordnung` ist die grobe Vorarbeit (alle Quellen, alle Konzepte),
Discovery in SPEC-003 ist die Feinarbeit (ein Konzept, tiefe Analyse). Synthese
Phase 2e (Discovery) bleibt bestehen, wird aber entlastet.

**Kandidaten-Persistierung:** `/zuordnung` schreibt neue Kandidaten DIREKT in
`_konzept-reife.md` (nicht erst in `_quellen-mapping.md` zwischenspeichern).
Die Mapping-Tabelle referenziert Kandidaten nur, sie ist nicht das Reife-Tracking.
Das ist konsistent mit SPEC-003 wo `_konzept-reife.md` die Single Source of Truth
fuer Kandidaten ist.

### hooks.json — Neue Eintraege

```json
{
  "hooks": [
    {
      "event": "PreToolUse",
      "matcher": "Agent",
      "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/guard-mapping-freshness.sh"
    }
  ]
}
```

Kein SubagentStop-Hook fuer `zuordnung-worker` noetig — `/zuordnung` erzeugt
kein `_pending.json` und braucht keine Gate-Pipeline. Die Verifikation
(`check-zuordnung-output.sh`) laeuft im Orchestrator nach Worker-Rueckkehr.

### SPEC-009 (Synthese-Pipeline) — Update noetig

SPEC-009 dokumentiert den Ist-Stand der Synthese-Pipeline. Nach Umsetzung
von SPEC-014 muss SPEC-009 aktualisiert werden:
- Phase 0: "Quellen aus Mapping laden" statt "per Schlagwort suchen"
- Neue Vorbedingung: `_quellen-mapping.md` muss aktuell sein

---

## Abhaengigkeiten

- Paket 3 (Shell-Checks), Paket 4 (Context-Budget), Paket 5 (Template-Guard), Paket 6 (Nachzuegler), Paket 7 (Dual-Link) sind unabhaengig
- Paket 1 (Zuordnung) braucht Paket 5 (sonst wird Template beim Dispatch ignoriert)
- Paket 2 (Mapping-Guard) haengt von Paket 1 ab (braucht `_quellen-mapping.md`)
- Empfohlene Reihenfolge: 4 → 3 → 6 → 7 → 5 → 1 → 2
- Pakete 3-7 sind reine Haertung (kein neuer Skill) und koennen in einer Session umgesetzt werden
- Nach Umsetzung: SPEC-009 aktualisieren, using-bibliothek + guard-wiki-writes.sh patchen

## Edge Cases

- **Erster Lauf (kein wiki/):** `/zuordnung` braucht mindestens 1 Quelle und
  1 Konzept. Falls wiki/ nicht existiert → Meldung: "Erst /ingest ausfuehren."
- **Sehr grosses Wiki (>100 Quellen):** Zusammenfassungen statt Volltext laden.
  Bei 100 Quellen x 50 Zeilen = ~5000 Zeilen ≈ 50K Tokens. Passt locker in 1M.
- **Mapping-Orphans:** Quelle wurde geloescht aber steht noch im Mapping →
  `check-zuordnung-output.sh` erkennt das (Datei existiert nicht mehr).
- **Mapping waehrend laufendem Ingest:** `guard-pipeline-lock.sh` blockiert
  `bibliothek:zuordnung-worker` wenn `_pending.json` existiert (nach Fix oben).
  `/zuordnung` hat kein eigenes `_pending.json`.
- **Leere Konzeptseite (nur Template):** Mapping erkennt das an fehlendem
  `synth-datum` oder `quellen-anzahl: 0` im Frontmatter → wird wie neues
  Konzept behandelt.
- **Zuordnung vor erstem Synthese-Lauf:** `_konzept-reife.md` existiert
  moeglicherweise noch nicht → `/zuordnung` bootstrapt sie (leer) wie
  Synthese Phase 0.0 es auch tut.
