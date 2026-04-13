---
name: synthese
description: "Konzeptseiten vertiefen — Quellen vergleichen, Formeln ausarbeiten, Widersprueche dokumentieren"
---

## Governance-Vertrag

> Synthese nimmt existierende Wiki-Seiten und vertieft sie durch Vergleich von Quellen,
> Ausarbeitung von Formeln, Markierung von Widerspruechen und Validierung.
> Mehrere Core-Gates sind aktiv; Phase 0.5 liest Original-PDFs (Gate 9 ist BLOCKIEREND).

| Gate | Durchsetzung | Wie | Bedingung |
|------|-------------|-----|-----------|
| KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG | ⚪ N/A | Synthese liest Kapitel, nicht ganze Buecher | — |
| KEIN-INHALT-OHNE-SEITENANGABE | ✅ Aktiv | Phase 1 + 2 setzen Seitenangaben bei jeden Aussage | — |
| KEIN-ZAHLENWERT-OHNE-QUELLE | ✅ Aktiv | Phase 1 recherchiert + vergleicht Zahlenwerte | — |
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | ✅ Aktiv | Phase 1 identifiziert Norm-Paragraphen exakt | norm-Typ aktiv |
| KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS | ⚪ N/A | Synthese traegt zu Querverweisen bei, setzt sie nicht | — |
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | 🔄 Delegiert | Dispatch: vokabular-pruefer | — |
| KEIN-UPDATE-OHNE-DIFF | ✅ Aktiv | Phase 2 dokumentiert Diffs zwischen Alt + Neu | — |
| KEIN-WIDERSPRUCH-OHNE-MARKIERUNG | ✅ Aktiv | Phase 2 markiert ALLE Widersprueche mit [WIDERSPRUCH] | — |
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | ✅ Aktiv | Wiki-Quellenseiten als Primaerquelle (4-Gate-geprueft), PDF-Spot-Check bei Widerspruechen/Unklarheiten | — |
| KORREKTE-UMLAUTE | 🔄 Delegiert | Gate 1 (quellen-pruefer), Part C | — |

**EXTERNER-INHALT-Marker:** Synthese liest PDFs → Wrapper erforderlich.

---

## Phasen

### Phase 0.0: Konzept-Kandidaten sammeln

1. Scanne alle Quellenseiten: `grep "konzept-kandidaten:" wiki/quellen/*.md`
2. Zaehle pro Kandidat: wie viele Quellen nennen ihn?
3. Kandidaten mit >=2 Quellen → zur Synthese-Liste hinzufuegen
4. Meldung an Nutzer: "N neue Konzeptseiten koennen erstellt werden: [Liste]"
5. Nutzer entscheidet welche Konzepte synthetisiert werden

---

### Phase 0: Target identifizieren + Quellen laden

1. **Target-Seite laden:**
   - Existiert die Konzeptseite / Normseite / Verfahrensseite?
   - Frontmatter auslesen (aktuelle Quellen, Review-Status)
   - Existierende Wikilinks + Schlagworte notieren

2. **Referenzierte Quellen identifizieren:**
   - Alle Quellenangaben im Text durchlaufen
   - Alle Wikilinks zu Quellenseiten ([quellen/...])
   - Alle Norm-Paragraph-Verweise
   - Dateilisten erstellen: welche PDFs muessen geladen werden?

3. **Token-Budget pruefen:**
   - Zaehlen: Zielseite + alle Quell-Kapitel?
   - Falls >700K Tokens: Split-Plan erstellen (Quelle 1-2, dann 3-4, ...)
   - Falls <100K Tokens: Single-Shot moeglich

---

### Phase 0.5a: Planmodus-Pruefung

Synthese betrifft typischerweise >=2 Dateien (Konzeptseite + _index + _log).
→ EnterPlanMode BEVOR die erste Datei geschrieben wird.

Plan dokumentiert:
- Welche Konzeptseite wird vertieft?
- Welche PDFs muessen geladen werden?
- Welche Nebeneffekte (_index, _log, MOCs) werden beruehrt?

### Phase 0.5b: PDF-Lesung (BLOCKIERENDES GATE 9)

<NICHT-VERHANDELBAR>
Synthese arbeitet primaer auf Wiki-Quellenseiten (4-Gate-gepruefte Extraktionen).
Original-PDFs werden NUR bei Widerspruechen, unklaren Formeln oder unplausiblen
Zahlenwerten geladen — GEZIELT, 2-5 Seiten, nicht ganze Kapitel.

1. Lies alle Wiki-Quellenseiten die das Konzept behandeln (PFLICHT)
2. Lade Original-PDFs NUR bei Bedarf (Widerspruch/Unklarheit)
3. Vermerke jeden PDF-Spot-Check im Output:
   "PDF verifiziert: [Datei], S. X — [Ergebnis]"
</NICHT-VERHANDELBAR>

1. **Wiki-Quellenseiten lesen (PFLICHT):**
   - Alle Quellenseiten die das Konzept behandeln laden
   - Formeln, Zahlenwerte, Normbezuege, Widersprueche extrahieren

2. **PDF-Spot-Check (NUR BEI BEDARF):**
   - Bei Widerspruch zwischen Quellen: konkrete PDF-Seiten laden
   - Bei unklarer Formel: PDF-Seite pruefen
   - Bei unplausiblem Zahlenwert: Originalstelle verifizieren
   - GEZIELT: nur 2-5 Seiten, nicht ganze Kapitel
   - Wrap: `<EXTERNER-INHALT>` Marker

3. **Kontext-Budget-Stopp:**
   - Falls Anzeichen von Kontext-Engpass: STOPP
   - Setze `[SYNTHESE UNVOLLSTAENDIG]` an den Anfang der Konzeptseite
   - Meldung: "Synthese kann nicht abgeschlossen werden: X von Y Quellen gelesen."

---

### Phase 0.6: Dispatch vorbereiten

<NICHT-VERHANDELBAR>
Subagent-Prompts werden NICHT frei formuliert. IMMER Template verwenden.
</NICHT-VERHANDELBAR>

1. Lade `governance/synthese-dispatch-template.md`
2. Fuelle Platzhalter:
   - `{{KONZEPT_NAME}}`: aus Nutzer-Anfrage oder Kandidaten-Liste
   - `{{KONZEPT_DATEI}}`: Pfad zur bestehenden Seite oder "NEU"
   - `{{QUELLENSEITEN_INHALT}}`: Read aller Wiki-Quellenseiten → inline einfuegen
   - `{{WIKI_ROOT}}`: Projektpfad + `/wiki/`
   - `{{VOKABULAR_TERME}}`: `grep "^### " wiki/_vokabular.md` → Term-Liste
3. Dispatche Agent mit:
   - `subagent_type: "bibliothek:synthese-worker"` (PFLICHT — PreToolUse-Hook
     guard-pipeline-lock.sh matcht auf diesen String, um parallele Synthesen
     und gleichzeitige Ingests zu blockieren solange _pending.json offen ist)
   - `prompt`: ausgefuelltes Template aus Schritt 2
   - `model`: "opus" (Synthese braucht max Context fuer Quellenvergleich)
   - `description`: "Synthese: {{KONZEPT_NAME}}"
4. Warte auf Ergebnis, dann weiter mit Phase 3 (Gate-Review)

---

### Phase 1: Vergleichende Analyse

**1a: Formeln vergleichen**
- Gibt es Formeln in den Quellen zu diesem Konzept?
- Alle Formeln auflisten mit:
  - Quelle (Buch + Seite)
  - Formel-Text
  - Herleitung / Annahmen
  - Gueltigkeitsbereich
- Sind Formeln identisch oder unterschiedlich?
- Falls unterschiedlich: Was sind die Unterschiede? Welche Annahmen erklaeren das?

**1b: Zahlenwerte vergleichen**
- Alle empirischen Zahlenwerte (z.B. "Reibungskoeffizient = 0.5") auflisten
- Pro Zahlenwert: Quelle, Kontext (Material? Temperatur?), Toleranzbereich
- Konvergieren oder divergieren die Werte?
- Falls divergent: Gibt es erklaerbare Gruende (unterschiedliche Materialien, Standards, ...)?

**1c: Norm-Paragraph-Analyse**
- Welche Normen werden referenziert?
- Exakte Abschnitte? (z.B. "EC5 3.2.3" oder nur "EC5 Kapitel 3")
- Wie interpretieren verschiedene Quellen denselben Absatz?
- Gibt es Unterschiede in der Interpretation?

**1d: Randbedingungen + Gueltigkeitsgrenzen**
- Pro Konzept: Unter welchen Bedingungen ist die Aussage gueltig?
- Material? Geometrie? Temperatur? Feuchte?
- Wo liegen die Grenzen?
- Sind diese explizit in den Quellen genannt oder implizit?

**1e: Widerspruch-Identifikation**
- Finden sich in den verschiedenen Quellen Aussagen die sich widersprechen?
- Z.B. Unterschiedliche Formeln fuer denselben Effekt?
- Z.B. Norm Edition 1 sagt A, Edition 2 sagt B?
- Dokumentieren ALLER Widersprueche mit Kontext

**1f: Versagensarten + Sicherheitskonzepte**
- Welche Versagensarten sind relevant? (Rollschub, Durchstanzen, Knickung, ...)
- Unterscheidet sich die Versagensart je nach Material/Geometrie?
- Sicherheitskonzept: charakteristische Werte vs. Bemessungswerte (γM)?
- Umweltklassen: Feuchteklasse, Expositionsklasse, Nutzungsklasse?

**1g: Domain-Analyse**
- Behandeln alle Quellen das Konzept in derselben Fachdomaene?
  - JA → Einheitliche Struktur
  - NEIN → Strukturiere nach Domain: "### [Konzept] in [Domain]"
- Gibt es domainuebergreifende Gemeinsamkeiten? (z.B. Querkraft-Prinzip ist
  physikalisch gleich, Versagensarten unterscheiden sich)

---

### Phase 2: Seite ausarbeiten + Diffs dokumentieren

<NICHT-VERHANDELBAR>
KEIN INFORMATIONSVERLUST: Fuer JEDE Quellenseite gilt:
- Jede Formel → muss in der Konzeptseite landen
- Jeder Zahlenwert → muss in der Vergleichstabelle landen
- Jede Randbedingung → muss dokumentiert sein
- Jeder Normbezug → muss mit Abschnitt erfasst sein

Wenn unsicher ob relevant: AUFNEHMEN. Weglassen nur mit expliziter Begruendung.
</NICHT-VERHANDELBAR>

**2a: Update-Modus (falls Seite bereits existiert)**

<NICHT-VERHANDELBAR>
- Bestehende Formeln/Zahlenwerte die NICHT in den neuen Quellen auftauchen: BEWAHREN
- Neue Formeln/Zahlenwerte: HINZUFUEGEN
- Widersprueche: ERGAENZEN, nicht ersetzen
- Bestehende Quellenverweise: BEIBEHALTEN
</NICHT-VERHANDELBAR>

**2b: Struktur aufbauen:**

```markdown
# Konzept: [NAME]

## Zusammenfassung
[1-3 Saetze Definition + Anwendungsbereich]

## Einsatzgrenzen + Randbedingungen

- **Materialgruppe:** Nadelholz / Stahlbeton / ...
- **Versagensart:** Rollschub / Durchstanzen / ...
- **Umweltklasse:** Feuchteklasse 1-3 / Expositionsklasse XC / ...
- **Gueltig fuer:** [Geometrie, Temperatur, Feuchte]
- **Gueltig bis:** [Grenzen explizit]

## Formeln

### Formel 1: [Name/Anwendungsfall]
[Formel in LaTeX oder Text]
- **Quelle:** [[quellenseite|Autor Jahr]], S. N
- **Annahmen:** [Aufzaehlung]
- **Parameter:** [[parameter-konzept|f_v,d]] = Bemessungsschubspannung
- **Gueltig fuer:** [Randbedingungen]

[Wiederhole fuer alle Formeln — Parameter verlinken wenn eigene Konzeptseite]

## Zahlenwerte + Parameter

| Parameter | Wert | Einheit | Quelle | Bereich |
|-----------|------|--------|--------|---------|
| Reibungskoeff. | 0.5 | - | [[quelle|Autor]], S. N | 0.4-0.6 |

## Norm-Referenzen

- **[[ec5-3-2-3|EC5, §3.2.3]]:** Querkraft-Nachweis → [Kommentar]
- **[[ec2-6-2|EC2, §6.2]]:** Bewehrung → [Kommentar]

## Widersprueche

> [!CAUTION] Widerspruch: [[quelle-a|Quelle A]] vs. [[quelle-b|Quelle B]]
> - **A sagt:** [Aussage mit Seitenzahl]
> - **B sagt:** [Aussage mit Seitenzahl]
> - **Erklaerung:** Moegliche Ursachen...

[Wiederholen fuer alle Widersprueche — Obsidian Callout-Syntax fuer Sichtbarkeit]

## Verwandte Konzepte

- [[Konzept1|Anzeigename]]
- [[Konzept2|Anzeigename]]

## Quellen

- [[quellenseite-a|Autor A Jahr]] — Kap. X, S. N-M
- [[quellenseite-b|Autor B Jahr]] — Kap. Y, S. N-M
```

**2c: Diffs dokumentieren**
- Wenn Seite bereits existiert: Diff zwischen Alt + Neu aufzeigen
- Was wurde hinzugefuegt? Was hat sich geaendert?
- Diff-Format: [DIFF ADDED], [DIFF MODIFIED], [DIFF REMOVED]

**2d: Frontmatter aktualisieren**
- `quellen:` mit alle genutzten Quellen
- `schlagworte:` mit Termen aus kontrolliertem Vokabular (_vokabular.md)
- `materialgruppe:` setzen (Holz, Stahlbeton, Stahl, Verbund, ...)
- `versagensart:` setzen falls zutreffend (Rollschub, Durchstanzen, Knickung, ...)
- `reviewed:` auf `false` (weil Synthese neue Inhalte hinzufuegt)
- `synth-datum:` setzen mit heutigem Datum

---

### Phase 3: Dispatch Review-Gates

<NICHT-VERHANDELBAR>
1. **Pipeline-Lock anlegen** — Schreibe `wiki/_pending.json`:
   ```json
   {"typ":"synthese","stufe":"gates","quelle":"<konzeptname>","timestamp":"<ISO-8601>","gates_passed":0,"gates_total":3}
   ```
   ERST hier, NICHT frueher — sonst blockiert guard-pipeline-lock.sh den eigenen
   Synthese-Worker-Dispatch in Phase 0.6.

2. Lade `governance/gate-dispatch-template.md`
3. Fuelle `{{PIPELINE_ID_MARKER}}` mit `[SYNTHESE-ID:<konzeptname>]`
4. Dispatche 3 Gate-Agents — IMMER mit Template-Prompt:
   Modellwahl: quellen-pruefer erbt Opus. konsistenz- und vokabular-pruefer
   haben Sonnet im Frontmatter. Siehe gate-dispatch-template.md "Modellwahl".
</NICHT-VERHANDELBAR>

**Gate 1: quellen-pruefer**
- Prueft: Jede Aussage hat Seitenangabe? Formeln-Quellen korrekt? Zahlenwerte verifizierbar?

**Gate 2: konsistenz-pruefer**
- Prueft: Widersprueche korrekt gekennzeichnet? Verweise zu verwandten Konzepten kohaerent?

**Gate 3: vokabular-pruefer**
- Prueft: Alle Schlagworte im Frontmatter existieren im Vokabular?
- Falls neue Schlagworte noetig: Delegation an `/vokabular`

**Bei FAIL:** Synthese korrigiert + erneutes Dispatch. Max 3 Iterationen.
Ergebnis ist PASS oder FAIL — kein Mittelweg.
**Alle 3 PASS:** `advance-pipeline-lock.sh` hat `stufe` automatisch auf `sideeffects` gesetzt → weiter mit Phase 5.

---

### Phase 5: Nebeneffekte

**Pflicht:**
- [ ] **Seite speichern** (mit Seitenangaben, Formeln, Widersprueche)
- [ ] **_index aktualisieren** (Konzeptseite hinzufuegen falls neu)
- [ ] **_log.md Eintrag:**
  ```markdown
  ## [2026-04-09] synthese | Querkraft-Transfer
  - Target: konzepte/querkraft-transfer.md (UPDATED)
  - Quellen re-gelesen: Fingerloos EC2, CEN/TS 19103
  - Formeln: 2 neu hinzugefuegt + 1 korrigiert
  - Widersprueche: 1 markiert (Norm-Versionen)
  - Gates: quellen-pruefer PASS, konsistenz-pruefer PASS
  ```
- [ ] **MOC pruefen:** Wenn neue Konzeptseite → in relevante MOCs eintragen
- [ ] **check-wiki-output.sh auf die Seite**
- [ ] **Pipeline-Lock freigeben** — `rm -f wiki/_pending.json` als ALLERLETZTEN Schritt

---

## Konflikt + Eskalation

**Problem: Widerspruch ist so fundamental, dass ich ihn nicht auflosen kann.**

→ Dokumentieren mit [WIDERSPRUCH]-Marker
→ Kommentar hinzufuegen: "Requires manual review — siehe _log"
→ Dispatch: `struktur-reviewer` (Nutzer konsultiert dann selbst)

---

## Split-Synthese (falls >700K Tokens)

1. Phase 0 plant: Quellen 1-2 (Durchgang 1), Quellen 3-4 (Durchgang 2)
2. Durchgang 1: Verarbeite Quellen 1-2, speichere Zwischen-Seite mit [SPLIT]-Marker
3. Durchgang 2: Lade Zwischen-Seite, fuege Quellen 3-4 hinzu
4. Final: Konsolidierung, [SPLIT]-Marker entfernen
5. 2-Gate Review auf Finale Seite

---

## Batch-Modus + Concurrency-Limit

<NICHT-VERHANDELBAR>
**Concurrency-Limit: Max 4 Agents gleichzeitig.**

Bei mehreren Konzepten: sequentiell verarbeiten.
Pro Konzept der vollstaendige Ablauf:
Synthese-Worker → 3 Gate-Agents → Nebeneffekte → naechstes Konzept.

- KEIN paralleles Dispatchen mehrerer Synthese-Workers.
- KEIN paralleles Dispatchen von Gates verschiedener Konzepte.
- Bei Gate-Nachholung: SEQUENTIELL pro Konzept abarbeiten.
- Einzige erlaubte Parallelitaet: die 3 Gates EINES Konzepts.
</NICHT-VERHANDELBAR>

---

## Umlaut-Check

Umlaut-Pruefung wurde aus dem Shell-Script entfernt (braucht Kontext).
Gate 1 (quellen-pruefer, Part C) prueft und korrigiert Umlaute kontextuell.
