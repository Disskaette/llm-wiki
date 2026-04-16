# SPEC-009: Synthese-Pipeline

**Status:** Done
**Version:** 1.2
**Erstellt:** 2026-04-14
**Aktualisiert:** 2026-04-16

## Zusammenfassung

Dokumentation des Ist-Zustands der Synthese-Pipeline. Der `/synthese` Skill
vertieft Konzeptseiten durch Quellenvergleich: Formeln nebeneinanderstellen,
Zahlenwerte vergleichen, Widersprueche markieren, Normbezuege mit Abschnitt
erfassen. Die Pipeline laueft in 8 Phasen (0.0 bis 5) mit Worker-Dispatch,
3-Gate-Review und mechanischer Lock-Enforcement.

**Abgrenzung zu anderen Specs:**

| Thema | Zustaendig | Nicht hier |
|-------|-----------|------------|
| Pipeline-Lock-Mechanik (`_pending.json`, Counter, Auto-Lock) | SPEC-002 | -- |
| Discovery-Logik (`[DISCOVERY]`-Block, `_konzept-reife.md`, Enforcement-Kette) | SPEC-003 | -- |
| Bedingte Gates (`{{DOMAIN_GATES}}`, Core/Domain-Split) | SPEC-005 | -- |
| Gesamtworkflow, Phasen, Lesestrategie, Seitenstruktur, Split/Batch | -- | **Dieser SPEC** |

## Quelldateien

| Datei | Zeilen | Rolle |
|-------|--------|-------|
| `plugin/skills/synthese/SKILL.md` | 426 | Skill-Definition (Orchestrator-Anweisungen) |
| `plugin/governance/synthese-dispatch-template.md` | 375 | Standardisierter Worker-Prompt |
| `plugin/agents/synthese-worker.md` | 52 | Subagent-Definition |

---

## Phasen-Uebersicht

| Phase | Name | Akteur | Beschreibung |
|-------|------|--------|--------------|
| 0.0 | Konzept-Discovery auswerten | Orchestrator | Reife-Kandidaten praesentieren, Nutzer waehlt |
| 0 | Target + Quellen laden | Orchestrator | Zielseite + Quellenseiten identifizieren, Token-Budget |
| 0.5a | Planmodus-Pruefung | Orchestrator | EnterPlanMode vor erstem Write |
| 0.5b | PDF-Lesung | Orchestrator/Worker | Wiki-first, PDF nur Spot-Check |
| 0.6 | Dispatch vorbereiten | Orchestrator | Template befuellen, Worker starten |
| 1 | Vergleichende Analyse | Worker | Formeln, Zahlen, Normen, Widersprueche |
| 2 | Seite ausarbeiten + Diffs | Worker | Konzeptseite schreiben/updaten |
| 2e | Discovery-Erkennung | Worker | Kandidaten, Schlagworte, Vokabular-Patches |
| 3 | Gate-Review | Orchestrator + 3 Gate-Agents | quellen-, konsistenz-, vokabular-pruefer |
| 5 | Nebeneffekte | Orchestrator | Persistierung, Index, Log, Lock-Freigabe |

---

## Phase 0.0: Konzept-Discovery auswerten

**Quelle:** SKILL.md Z.30-63

### Ablauf

1. **Primaere Quelle lesen:** `_konzept-reife.md` YAML-Frontmatter parsen
   → Liste aller Kandidaten mit Status (unreif / reif / erstellt)
   (SKILL.md Z.33-34)

2. **Rueckwaertskompatibilitaet:** Quellenseiten-Frontmatter scannen via
   `grep "konzept-kandidaten:" wiki/quellen/*.md` → Kandidaten die NICHT
   in `_konzept-reife.md` stehen dort nachtragen, Status berechnen
   (SKILL.md Z.36-39)

3. **Reife-Bericht an Nutzer:** Formatierte Ausgabe mit reifen Kandidaten
   (>=2 Quellen, mit Quellenliste), unreifen Kandidaten (1 Quelle) und
   seit letzter Synthese neu hinzugekommenen Kandidaten
   (SKILL.md Z.41-51)

4. **Nutzer waehlt** welche reifen Kandidaten synthetisiert werden
   (SKILL.md Z.53)

5. **Schlagwort-Vorschlaege pruefen:** `_schlagwort-vorschlaege.md` lesen,
   offene Vorschlaege melden mit Empfehlung `/vokabular`
   (SKILL.md Z.55-58)

### Bootstrap (erster Lauf)

- `_konzept-reife.md` nicht vorhanden → Bootstrap mit leerem `kandidaten: []`
  (SKILL.md Z.60-61)
- `_schlagwort-vorschlaege.md` nicht vorhanden → Bootstrap mit leeren
  `neue-terme: []`, `fehlende-zuordnungen: []`
  (SKILL.md Z.62-63)

---

## Phase 0: Target identifizieren + Quellen aus Mapping laden

**Quelle:** SKILL.md Z.67-84

### Vorbedingung

`wiki/_quellen-mapping.md` muss aktuell sein. Falls veraltet: `/zuordnung` ausfuehren.
`guard-mapping-freshness.sh` (PreToolUse-Hook) blockiert Synthese-Worker automatisch
wenn Mapping aelter als 24h ist.

### Ablauf

1. **Target-Seite laden:** Existenz pruefen, Frontmatter auslesen
   (aktuelle Quellen, Review-Status), Wikilinks + Schlagworte notieren
   (SKILL.md Z.69-72)

2. **Quellen aus Mapping laden:** Lies `wiki/_quellen-mapping.md`.
   Alle dort fuer das Zielkonzept gelisteten Quellen UND Kandidaten-Zuordnungen.
   KEIN eigenes Suchen per Schlagwort — Mapping ist Single Source of Truth.
   Falls Mapping veraltet: `/zuordnung` zuerst ausfuehren (Hook blockiert sonst).
   (SKILL.md Z.74-79)

3. **Token-Budget pruefen:**
   - >700K Tokens → Split-Plan erstellen (siehe Split-Synthese)
   - <100K Tokens → Single-Shot moeglich
   (SKILL.md Z.81-83)

---

## Phase 0.5a: Planmodus-Pruefung

**Quelle:** SKILL.md Z.87-96

Synthese betrifft typischerweise >=2 Dateien (Konzeptseite + `_index` + `_log`).
→ EnterPlanMode BEVOR die erste Datei geschrieben wird.

Plan dokumentiert:
- Welche Konzeptseite vertieft wird
- Welche PDFs geladen werden muessen
- Welche Nebeneffekte (`_index`, `_log`, MOCs) betroffen sind

---

## Phase 0.5b: Wiki-first-Lesestrategie (BLOCKIERENDES GATE 9)

**Quelle:** SKILL.md Z.97-125, Dispatch-Template Z.7-11 + Z.83-101

### Kernprinzip

Wiki-Quellenseiten (4-Gate-geprueft) sind die **primaere Datenbasis**.
Original-PDFs werden NUR bei Widerspruechen, unklaren Formeln oder
unplausiblen Zahlenwerten geladen — GEZIELT, 2-5 Seiten, nie ganze Kapitel.

**Design-Begruendung (Dispatch-Template Z.8-11):** 10 Quellenseiten (~300 Zeilen)
passen problemlos ins Context. 10 vollstaendige PDFs wuerden das
Context-Fenster sprengen.

### Dreistufige Lesestrategie

| Stufe | Was | Wann | Pflicht |
|-------|-----|------|---------|
| 1 | Wiki-Quellenseiten lesen | Immer | Ja |
| 2 | Formeln/Zahlenwerte/Normbezuege extrahieren | Immer | Ja |
| 3 | PDF-Spot-Check | Nur bei Widerspruch/Unklarheit | Nein |

(SKILL.md Z.110-118)

### PDF-Spot-Check-Regeln

- Nur bei: Widerspruch zwischen Quellen, unklarer Formel, unplausiblem Zahlenwert
- Umfang: 2-5 Seiten gezielt, nie ganze Kapitel
- Wrapping: `<EXTERNER-INHALT>` Marker (Prompt-Injection-Schutz)
- Dokumentation: Jeder Check wird vermerkt als
  `"PDF verifiziert: [Datei], S. X — [Ergebnis]"`
  (SKILL.md Z.114-119)

### Kontext-Budget-Stopp

Falls Anzeichen von Kontext-Engpass: STOPP.
`[SYNTHESE UNVOLLSTAENDIG]` an den Anfang der Konzeptseite setzen.
Meldung: "Synthese kann nicht abgeschlossen werden: X von Y Quellen gelesen."
(SKILL.md Z.121-124, Dispatch-Template Z.278-284)

---

## Phase 0.6: Dispatch vorbereiten

**Quelle:** SKILL.md Z.128-152, Dispatch-Template Z.1-28

### Nicht-verhandelbar

Subagent-Prompts werden NICHT frei formuliert. IMMER Template verwenden.
(SKILL.md Z.131-132)

### Platzhalter-Befuellung

| Platzhalter | Befuellung | Quelle |
|-------------|-----------|--------|
| `{{KONZEPT_NAME}}` | Aus Nutzer-Anfrage oder Kandidaten-Liste | SKILL.md Z.137 |
| `{{KONZEPT_DATEI}}` | Pfad zur Seite oder "NEU" | SKILL.md Z.138 |
| `{{QUELLENSEITEN_INHALT}}` | Read aller Wiki-Quellenseiten → inline | SKILL.md Z.139 |
| `{{WIKI_ROOT}}` | Projektpfad + `/wiki/` | SKILL.md Z.140 |
| `{{VOKABULAR_TERME}}` | `grep "^### " wiki/_vokabular.md` | SKILL.md Z.141 |
| `{{KONZEPT_REIFE_INHALT}}` | Read `_konzept-reife.md` → inline | SKILL.md Z.142 |
| `{{SCHLAGWORT_VORSCHLAEGE_INHALT}}` | Read `_schlagwort-vorschlaege.md` → inline | SKILL.md Z.143 |
| `{{BESTEHENDE_KONZEPTE}}` | `ls wiki/konzepte/*.md` → Komma-separiert | SKILL.md Z.144 |
| `{{DOMAIN_GATES}}` | Aus hard-gates.md + seitentypen.md (SPEC-005) | Dispatch-Template Z.24 |

(Dispatch-Template Z.16-28 dokumentiert die vollstaendige Platzhalter-Tabelle)

### Dispatch-Parameter

- `subagent_type`: `"bibliothek:synthese-worker"` — PFLICHT.
  `guard-pipeline-lock.sh` matcht auf diesen String fuer Lock-Enforcement.
  (SKILL.md Z.145-147, synthese-worker.md Z.46-50)
- `model`: `"opus"` — Synthese braucht max Context fuer Quellenvergleich
  (SKILL.md Z.149)
- `description`: `"Synthese: {{KONZEPT_NAME}}"`
  (SKILL.md Z.150)

---

## Phase 1: Vergleichende Analyse (im Worker)

**Quelle:** SKILL.md Z.155-203, Dispatch-Template Z.74-101

Die vergleichende Analyse ist der Kern der Synthese. Der Worker fuehrt
7 Analyse-Schritte aus:

### 1a: Formeln vergleichen (SKILL.md Z.157-166)

- Alle Formeln zum Konzept auflisten mit Quelle, Seite, Herleitung, Annahmen, Gueltigkeitsbereich
- Identisch oder unterschiedlich? Bei Unterschieden: Annahmen die das erklaeren

### 1b: Zahlenwerte vergleichen (SKILL.md Z.168-173)

- Empirische Zahlenwerte auflisten pro Quelle mit Kontext (Material, Temperatur, Toleranzbereich)
- Konvergenz/Divergenz bewerten mit Ursachenanalyse

### 1c: Norm-Paragraph-Analyse (SKILL.md Z.175-179)

- Referenzierte Normen mit exakten Abschnitten
- Interpretationsvergleich ueber verschiedene Quellen

### 1d: Randbedingungen + Gueltigkeitsgrenzen (SKILL.md Z.181-184)

- Pro Konzept: Material, Geometrie, Temperatur, Feuchte
- Explizit vs. implizit in den Quellen

### 1e: Widerspruch-Identifikation (SKILL.md Z.186-189)

- Widersprueche zwischen Quellen (unterschiedliche Formeln, Norm-Editionen)
- Dokumentation ALLER Widersprueche mit Kontext

### 1f: Versagensarten + Sicherheitskonzepte (SKILL.md Z.191-196)

- Relevante Versagensarten (domain-spezifisch)
- Sicherheitskonzept: charakteristisch vs. Bemessung
- Umweltklassen

### 1g: Domain-Analyse (SKILL.md Z.198-203)

- Alle Quellen in derselben Fachdomaene? → Einheitliche Struktur
- Verschiedene Domaenen? → Strukturierung nach Domain
- Domainuebergreifende Gemeinsamkeiten identifizieren

---

## Phase 2: Seite ausarbeiten + Diffs dokumentieren (im Worker)

**Quelle:** SKILL.md Z.206-298, Dispatch-Template Z.105-206

### Nicht-verhandelbar: KEIN INFORMATIONSVERLUST

Fuer JEDE Quellenseite gilt (SKILL.md Z.208-215, Dispatch-Template Z.106-115):
- Jede Formel → muss in der Konzeptseite landen
- Jeder Zahlenwert → muss in der Vergleichstabelle landen
- Jede Randbedingung → muss dokumentiert sein
- Jeder Normbezug → muss mit Abschnitt erfasst sein

Im Zweifel: AUFNEHMEN. Weglassen nur mit expliziter Begruendung.

### 2a: Update-Modus (SKILL.md Z.218-225)

Falls Seite bereits existiert — ebenfalls nicht-verhandelbar:
- Bestehende Formeln/Zahlenwerte die NICHT in neuen Quellen auftauchen: BEWAHREN
- Neue Formeln/Zahlenwerte: HINZUFUEGEN
- Widersprueche: ERGAENZEN, nicht ersetzen
- Bestehende Quellenverweise: BEIBEHALTEN

### 2b: Konzeptseiten-Struktur (SKILL.md Z.227-283, Dispatch-Template Z.130-206)

Pflicht-Frontmatter-Felder (Dispatch-Template Z.133-148):

```yaml
type: konzept
title: "Konzeptname"
synonyme: [...]
schlagworte: [...]         # Nur aus kontrolliertem Vokabular
materialgruppe: Kategorie  # Level-1-Term aus _vokabular.md
versagensart: [...]        # Domain-spezifisch, falls zutreffend
mocs: [...]
quellen-anzahl: N
created: YYYY-MM-DD
updated: YYYY-MM-DD
synth-datum: YYYY-MM-DD
reviewed: false            # Immer false nach Synthese
```

Body-Struktur (Randbedingungen VOR Formeln — Dispatch-Template Z.150-151):

1. `# [Konzeptname]`
2. `## Zusammenfassung` — 1-3 Saetze Definition + Anwendungsbereich
3. `## Einsatzgrenzen + Randbedingungen` — Materialgruppe, Versagensart, Umweltklasse, Gueltigkeitsbereich/-grenzen
4. `## Formeln` — Pro Formel: LaTeX/Text, Quelle+Seite, Annahmen, Parameter (verlinkt), Gueltigkeitsbereich
5. `## Zahlenwerte + Parameter` — Vergleichstabelle (Parameter | Wert | Einheit | Quelle | Bereich)
6. `## Norm-Referenzen` — Mit Abschnittsnummer und Interpretationsvergleich
7. `## Widersprueche` — Obsidian `[!CAUTION]`-Callout-Syntax (farbkodiert, foldable)
8. `## Verwandte Konzepte` — Wikilinks
9. `## Quellen` — Wikilinks mit Kapitel + Seitenbereich

### Link-Konventionen (Dispatch-Template Z.208-260)

| Typ | Syntax | Verwendung |
|-----|--------|------------|
| Beleg (PDF) | `[[datei.pdf#page=N\|Autor Jahr, S. N]]` | Fliesstext UND Tabellen, N = physische PDF-Seite |
| Fachbegriff | `[[konzeptname\|Anzeigename]]` | Konzeptseiten |
| Quellen-Abschnitt | `[[quellenseite\|Autor Jahr]]` | Quellen-Section (NUR dort, nie in Tabellen) |

**Tabellen-Regeln (Dispatch-Template Z.228-248):**
- Zahlenwerte- und Norm-Referenzen-Tabellen verwenden PDF-Deeplinks, keine Quellen-Wikilinks
- Pipe in Wikilinks innerhalb Tabellen MUSS escaped werden: `\|` statt `|`
- Norm-Abschnitte (§X.Y) in der Norm-Referenzen-Tabelle als klickbare PDF-Links

**Norm-Labels (Dispatch-Template Z.250-260):**
- Gueltige Normen: Kurzname (EC2, EC5, CEN/TS 19103)
- Norm-Entwuerfe: Kurzname:Jahr (E) (z.B. EC2:2025 (E))
- Lehrbuecher/Forschung: IMMER "Autor Jahr" (nie nur Nachname)
- NIEMALS "CEN/TC" als Label (technisches Komitee ≠ Norm)

**Page-Offset-Warnung (Dispatch-Template Z.262-266):**
- page-offset kann variabel sein (Farbseiten-Einschuebe)
- #page=N Werte aus Wiki-Quellenseiten direkt uebernehmen, nie selbst umrechnen

### 2c: Diffs dokumentieren (SKILL.md Z.285-288)

Bei existierenden Seiten: Diff zwischen Alt + Neu aufzeigen.
Format: `[DIFF ADDED]`, `[DIFF MODIFIED]`, `[DIFF REMOVED]`

### 2d: Frontmatter aktualisieren (SKILL.md Z.290-296)

- `quellen:` mit allen genutzten Quellen
- `schlagworte:` mit Termen aus kontrolliertem Vokabular
- `materialgruppe:` setzen
- `versagensart:` setzen falls zutreffend
- `reviewed: false` (neue Inhalte)
- `synth-datum:` heutiges Datum

---

## Phase 2e: Discovery-Erkennung (im Worker)

**Quelle:** SKILL.md Z.300-315, Dispatch-Template Z.304-374

**Hinweis:** Details der Discovery-Logik sind in SPEC-003 spezifiziert.
Hier nur die Pipeline-Einbettung.

Der Worker fuehrt Phase 2e automatisch aus — der Orchestrator muss nichts tun.

### Worker-Aktionen (SKILL.md Z.305-309)

1. Konzept-Kandidaten identifizieren (Fachbegriffe in mehreren Quellen ohne eigene Seite)
2. Fehlende Vokabular-Terme erkennen
3. Neue Terme in `_vokabular.md` schreiben (nur additiv)
4. Quellenseiten-Schlagworte patchen (nur additiv)
5. Alles im `[DISCOVERY]`-Block melden

### Orchestrator-Verifikation (SKILL.md Z.311-315)

- `[DISCOVERY]`-Block im Worker-Output vorhanden?
- Gate 3 (konsistenz-pruefer) Part D prueft Details (SPEC-003)

---

## Phase 3: Gate-Review

**Quelle:** SKILL.md Z.318-347

### Pipeline-Lock Timing

**Nicht-verhandelbar:** Pipeline-Lock ERST hier anlegen (SKILL.md Z.321-327).
Nicht frueher — sonst blockiert `guard-pipeline-lock.sh` den eigenen
Synthese-Worker-Dispatch in Phase 0.6.

```json
{
  "typ": "synthese",
  "stufe": "gates",
  "quelle": "<konzeptname>",
  "timestamp": "<ISO-8601>",
  "gates_passed": 0,
  "gates_total": 3
}
```

**Hinweis:** Seit SPEC-002 v2.0 wird `_pending.json` automatisch durch
`create-pipeline-lock.sh` (SubagentStop-Hook) nach Worker-Ende angelegt.
Phase 3 verifiziert die Datei und dispatcht die Gates.

### Gate-Dispatch (SKILL.md Z.328-333)

1. `governance/gate-dispatch-template.md` laden
2. `{{PIPELINE_ID_MARKER}}` mit `[SYNTHESE-ID:<konzeptname>]` befuellen
3. 3 Gate-Agents dispatchen — IMMER mit Template-Prompt

**Modellwahl (SKILL.md Z.331-332):** quellen-pruefer erbt Opus.
konsistenz- und vokabular-pruefer haben Sonnet im Frontmatter.

### Die 3 Gates

| Gate | Prueft | Quelle |
|------|--------|--------|
| quellen-pruefer | Seitenangaben, Formeln-Quellen, Zahlenwerte, Umlaute (Part C) | SKILL.md Z.335-336 |
| konsistenz-pruefer | Widerspruchs-Markierung, Querverweis-Kohaerenz, Discovery Part D (SPEC-003) | SKILL.md Z.338-339 |
| vokabular-pruefer | Schlagworte im Vokabular, ggf. Delegation an `/vokabular` | SKILL.md Z.341-343 |

### Ergebnis-Logik (SKILL.md Z.345-347)

- Bei FAIL: Synthese korrigiert + erneutes Dispatch. Max 3 Iterationen.
- Ergebnis ist PASS oder FAIL — kein Mittelweg.
- Alle 3 PASS: `advance-pipeline-lock.sh` hat `stufe` automatisch auf
  `sideeffects` gesetzt → weiter mit Phase 5.

---

## Phase 5: Nebeneffekte

**Quelle:** SKILL.md Z.351-382

### Pflicht-Checkliste (in dieser Reihenfolge)

- [x] **Seite speichern** (mit Seitenangaben, Formeln, Widersprueche)
  (SKILL.md Z.354)
- [x] **`_index` aktualisieren** (Konzeptseite hinzufuegen falls neu)
  (SKILL.md Z.355)
- [x] **`_log.md` Eintrag** inkl. Discovery-Zusammenfassung:
  Target, Quellen re-gelesen, Formeln (neu + korrigiert), Widersprueche,
  Gate-Ergebnisse, Discovery (Kandidaten, Vorschlaege, Ergaenzungen, Patches)
  (SKILL.md Z.356-365)
- [x] **MOC pruefen** — neue Konzeptseite in relevante MOCs eintragen
  (SKILL.md Z.366)
- [x] **Discovery persistieren** — Worker hat `_vokabular.md` + Quellenseiten-Patches
  bereits geschrieben, Gates haben verifiziert. Jetzt nur Tracking-Metadaten:
  (SKILL.md Z.367-379)
  1. `[DISCOVERY]`-Block aus Worker-Output parsen
  2. Konzept-Kandidaten → `_konzept-reife.md` (Duplikat-Check, Status-Berechnung,
     `entdeckt-bei: "synthese:<konzeptname>"`)
  3. Schlagwort-Vorschlaege → `_schlagwort-vorschlaege.md` (Duplikat-Check,
     umgesetzte Patches als `status: umgesetzt` markieren)
  4. Markdown-Body beider Dateien aus YAML regenerieren
- [x] **`check-wiki-output.sh`** auf die Seite ausfuehren
  (SKILL.md Z.380)
- [x] **Pipeline-Lock freigeben** — `rm -f wiki/_pending.json` als ALLERLETZTER Schritt
  (SKILL.md Z.381)

---

## Governance-Vertrag

**Quelle:** SKILL.md Z.6-26

| Gate | Status | Durchsetzung | Quelle |
|------|--------|-------------|--------|
| KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG | N/A | Synthese liest Kapitel, nicht ganze Buecher | Z.14 |
| KEIN-INHALT-OHNE-SEITENANGABE | Aktiv | Phase 1 + 2: Seitenangaben bei jeder Aussage | Z.15 |
| KEIN-ZAHLENWERT-OHNE-QUELLE | Aktiv | Phase 1: Zahlenwerte recherchiert + verglichen | Z.16 |
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | Aktiv (bedingt) | Phase 1: Norm-Paragraphen exakt identifiziert | Z.17 |
| KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS | N/A | Synthese traegt bei, setzt nicht | Z.18 |
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | Aktiv | Phase 2e: Worker schreibt Vokabular + patcht Quellen, Gate 3 Part D verifiziert | Z.19 |
| KEIN-UPDATE-OHNE-DIFF | Aktiv | Phase 2: Diffs zwischen Alt + Neu dokumentiert | Z.20 |
| KEIN-WIDERSPRUCH-OHNE-MARKIERUNG | Aktiv | Phase 2: ALLE Widersprueche mit `[WIDERSPRUCH]` markiert | Z.21 |
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | Aktiv | Wiki-first-Strategie (4-Gate-geprueft), PDF-Spot-Check bei Bedarf | Z.22 |
| KORREKTE-UMLAUTE | Delegiert | Gate 1 (quellen-pruefer), Part C | Z.23 |

EXTERNER-INHALT-Marker erforderlich weil Synthese PDFs liest (SKILL.md Z.25).

---

## Split-Synthese (>700K Tokens)

**Quelle:** SKILL.md Z.395-403

Wenn das Token-Budget in Phase 0 ueberschritten wird:

1. Phase 0 plant: Quellen 1-2 (Durchgang 1), Quellen 3-4 (Durchgang 2)
2. Durchgang 1: Quellen 1-2 verarbeiten, Zwischen-Seite mit `[SPLIT]`-Marker speichern
3. Durchgang 2: Zwischen-Seite laden, Quellen 3-4 hinzufuegen
4. Final: Konsolidierung, `[SPLIT]`-Marker entfernen
5. 2-Gate-Review auf finale Seite

---

## Batch-Modus + Concurrency-Limit

**Quelle:** SKILL.md Z.405-418

### Nicht-verhandelbar (SKILL.md Z.407-408)

**Concurrency-Limit: Max 4 Agents gleichzeitig.**

### Sequentielle Verarbeitung

Bei mehreren Konzepten: Pro Konzept der vollstaendige Ablauf:
Synthese-Worker → 3 Gate-Agents → Nebeneffekte → naechstes Konzept.

### Verbotene Parallelitaet (SKILL.md Z.413-417)

- KEIN paralleles Dispatchen mehrerer Synthese-Workers
- KEIN paralleles Dispatchen von Gates verschiedener Konzepte
- Bei Gate-Nachholung: SEQUENTIELL pro Konzept abarbeiten

### Einzige erlaubte Parallelitaet

Die 3 Gates EINES Konzepts (SKILL.md Z.418).

---

## Dispatch-Template: Architektur

**Quelle:** Dispatch-Template Z.1-374, synthese-worker.md Z.1-52

### Design-Entscheidung

Der Hauptagent (Orchestrator) liest das Template, ersetzt Platzhalter und
uebergibt das Ergebnis als Agent-Prompt. Der Subagent liest die Template-Datei
nie direkt. (Dispatch-Template Z.5-6)

### Prompt-Struktur (Dispatch-Template Z.33-374)

Der Worker-Prompt besteht aus 14 benannten Sektionen:

| Sektion | Inhalt | Template-Zeilen |
|---------|--------|-----------------|
| KONTEXT | Konzeptname, Datei, Wiki-Root, Vokabular | Z.38-49 |
| QUELLENSEITEN | Inline-Quellenseiten als Primaerbasis | Z.51-59 |
| DISCOVERY-KONTEXT | `_konzept-reife.md` + `_schlagwort-vorschlaege.md` inline | Z.61-69 |
| AUFTRAG | 5-Punkte-Auftrag | Z.71-81 |
| LESESTRATEGIE | 4-Schritte Wiki-first, nicht verhandelbar | Z.83-104 |
| KEIN INFORMATIONSVERLUST | Pflicht-Regeln fuer Vollstaendigkeit | Z.106-115 |
| PROMPT-INJECTION-SCHUTZ | `<EXTERNER-INHALT>`-Wrapper fuer PDFs | Z.117-127 |
| KONZEPTSEITE | Exakte Frontmatter- + Body-Struktur | Z.129-206 |
| LINK-KONVENTIONEN | 3 Link-Typen (PDF, Konzept, Quellen) | Z.208-222 |
| TABELLEN | PDF-Links in Tabellen, Pipe-Escaping, Norm-§ als Links | Z.228-248 |
| NORM-LABELS | (E)-Konvention, Autor Jahr Pflicht, kein CEN/TC | Z.250-260 |
| PAGE-OFFSET-WARNUNG | Variabel, nie selbst umrechnen | Z.262-266 |
| KONZEPT-KANDIDATEN PRUEFEN | Mindestens 2 Quellen fuer neue Seite | Z.224-233 |
| REGELN | Nicht-verhandelbare Einzelregeln | Z.235-252 |
| DOMAIN-GATES | `{{DOMAIN_GATES}}` Platzhalter | Z.254-258 |
| DATEINAMEN/RECHTSCHREIB-REGELN | ASCII-Dateinamen, deutsche Wiki-Texte | Z.260-276 |
| SELBST-CHECK | `check-wiki-output.sh` + Ergebnis-Meldung | Z.286-300 |
| PHASE 2e: DISCOVERY | Nicht-verhandelbar, [DISCOVERY]-Block Pflicht | Z.304-374 |

### Synthese-Worker Agent (synthese-worker.md)

- Keine eigenen Gates — Worker fuehrt aus, prueft nicht selbst
  (synthese-worker.md Z.34-36)
- Kein Re-Review-Limit — gilt nur fuer Gate-Agents
  (synthese-worker.md Z.39-42)
- `subagent_type: "bibliothek:synthese-worker"` ist die einzige Wirkung
  der Agent-Datei — `guard-pipeline-lock.sh` matcht darauf
  (synthese-worker.md Z.46-50)
- Tools: Read, Write, Edit, Grep, Glob, Bash
  (synthese-worker.md Z.4)

---

## Konzept-Kandidaten-Pruefung (neue Seiten)

**Quelle:** Dispatch-Template Z.224-233

Wenn `{{KONZEPT_DATEI}}` = "NEU":
- Mindestens 2 Quellen muessen das Konzept substanziell behandeln → Seite anlegen
- Weniger als 2 → KEINE Seite anlegen, nur melden:
  `"[NICHT ERSTELLT] {{KONZEPT_NAME}} — nur X Quelle(n), Minimum 2 erforderlich."`

---

## Konflikt + Eskalation

**Quelle:** SKILL.md Z.385-392

Wenn ein Widerspruch so fundamental ist, dass er nicht aufloesbar ist:
1. Dokumentieren mit `[WIDERSPRUCH]`-Marker
2. Kommentar: "Requires manual review — siehe _log"
3. Dispatch: `struktur-reviewer` (Nutzer konsultiert dann selbst)

---

## Umlaut-Check

**Quelle:** SKILL.md Z.422-426

Umlaut-Pruefung laeuft nicht per Shell-Script (braucht Kontext).
Gate 1 (quellen-pruefer, Part C) prueft und korrigiert Umlaute kontextuell.
Rechtschreibung im Wiki-Text: normale deutsche Sprache mit Umlauten.
Dateinamen: ASCII lowercase mit Bindestrichen.
(Dispatch-Template Z.268-276)

---

## Akzeptanzkriterien

> Alle Kriterien dokumentieren bestehenden Code (Ist-Zustand).
> Zeilennummern beziehen sich auf die Quelldateien zum Zeitpunkt der Erstellung.

### Phasen-Vollstaendigkeit
- [x] Phase 0.0 liest `_konzept-reife.md` als primaere Quelle — SKILL.md Z.33-34
- [x] Phase 0.0 synchronisiert Quellenseiten-Kandidaten (Rueckwaertskompatibilitaet) — SKILL.md Z.36-39
- [x] Phase 0.0 Bootstrap fuer `_konzept-reife.md` + `_schlagwort-vorschlaege.md` — SKILL.md Z.60-63
- [x] Phase 0 Token-Budget-Pruefung mit Split-Schwelle 700K — SKILL.md Z.81-83
- [x] Phase 0.5a EnterPlanMode vor erstem Write — SKILL.md Z.87-96
- [x] Phase 0.5b Wiki-first-Lesestrategie als BLOCKIERENDES GATE 9 — SKILL.md Z.97-108
- [x] Phase 0.6 Template-Pflicht fuer Worker-Prompt — SKILL.md Z.131-132
- [x] Phase 0.6 alle 9 Platzhalter dokumentiert — SKILL.md Z.136-144, Dispatch-Template Z.16-28
- [x] Phase 0.6 `subagent_type: "bibliothek:synthese-worker"` — SKILL.md Z.145-147
- [x] Phase 0.6 Modell Opus fuer maximalen Context — SKILL.md Z.149

### Vergleichende Analyse (Phase 1)
- [x] 7 Analyse-Schritte definiert (1a-1g) — SKILL.md Z.157-203
- [x] Formeln mit Quelle, Herleitung, Annahmen, Gueltigkeitsbereich — SKILL.md Z.158-166
- [x] Zahlenwerte mit Quelle, Kontext, Toleranzbereich — SKILL.md Z.168-173
- [x] Norm-Paragraphen mit exakten Abschnitten — SKILL.md Z.175-179
- [x] Widerspruch-Dokumentation mit Kontext — SKILL.md Z.186-189
- [x] Domain-Analyse mit Strukturierung nach Domain — SKILL.md Z.198-203

### Seitenstruktur (Phase 2)
- [x] KEIN INFORMATIONSVERLUST als nicht-verhandelbares Prinzip — SKILL.md Z.208-215
- [x] Update-Modus: BEWAHREN + HINZUFUEGEN, nicht ersetzen — SKILL.md Z.220-225
- [x] 9-teilige Body-Struktur (Zusammenfassung bis Quellen) — SKILL.md Z.228-283
- [x] Randbedingungen VOR Formeln — Dispatch-Template Z.150-151
- [x] Pflicht-Frontmatter mit 12 Feldern — Dispatch-Template Z.133-148
- [x] `reviewed: false` nach jeder Synthese — SKILL.md Z.295
- [x] Diff-Dokumentation bei Updates ([DIFF ADDED/MODIFIED/REMOVED]) — SKILL.md Z.285-288
- [x] 3 Link-Konventionen (PDF, Konzept, Quellen) — Dispatch-Template Z.208-222
- [x] PDF-Deeplinks in Tabellen (nicht Quellen-Wikilinks) — Dispatch-Template Z.228-248
- [x] Pipe-Escaping (\|) in Markdown-Tabellen — Dispatch-Template Z.234-236
- [x] Norm-§ als klickbare PDF-Links in Norm-Referenzen-Tabelle — Dispatch-Template Z.238-240
- [x] Norm-Labels: (E) fuer Entwuerfe, Autor Jahr Pflicht — Dispatch-Template Z.250-260
- [x] Page-Offset-Warnung: variabel, nie selbst umrechnen — Dispatch-Template Z.262-266
- [x] Alle stuetzenden Quellen zitieren (Sammelzitate) — Dispatch-Template Z.120-144, SKILL.md Z.211

### Gate-Review (Phase 3)
- [x] Pipeline-Lock erst in Phase 3, nicht frueher — SKILL.md Z.321-327
- [x] 3 Gates: quellen-, konsistenz-, vokabular-pruefer — SKILL.md Z.335-343
- [x] Modellwahl: Opus fuer quellen-pruefer, Sonnet fuer andere — SKILL.md Z.331-332
- [x] Max 3 Iterationen bei FAIL — SKILL.md Z.345
- [x] PASS/FAIL ohne Mittelweg — SKILL.md Z.346

### Nebeneffekte (Phase 5)
- [x] 7-Punkte-Checkliste in definierter Reihenfolge — SKILL.md Z.353-381
- [x] `_log.md` mit Discovery-Zusammenfassung — SKILL.md Z.356-365
- [x] MOC-Eintrag bei neuer Konzeptseite — SKILL.md Z.366
- [x] Discovery-Persistierung (Tracking-Metadaten) — SKILL.md Z.367-379
- [x] Pipeline-Lock-Freigabe als allerletzter Schritt — SKILL.md Z.381

### Split-Synthese
- [x] Schwelle bei >700K Tokens — SKILL.md Z.395
- [x] Durchgangsbasiert mit `[SPLIT]`-Marker — SKILL.md Z.398-400
- [x] Konsolidierung + 2-Gate-Review auf Finale — SKILL.md Z.401-402

### Batch-Modus
- [x] Concurrency-Limit: max 4 Agents gleichzeitig — SKILL.md Z.408
- [x] Sequentielle Verarbeitung: ein Konzept komplett vor dem naechsten — SKILL.md Z.410-412
- [x] Einzige Parallelitaet: 3 Gates eines Konzepts — SKILL.md Z.418
- [x] Kein paralleler Worker-Dispatch — SKILL.md Z.413-414

### Dispatch-Template
- [x] 9 Platzhalter definiert und dokumentiert — Dispatch-Template Z.16-28
- [x] 14 benannte Prompt-Sektionen — Dispatch-Template Z.33-374
- [x] Prompt-Injection-Schutz (`<EXTERNER-INHALT>`) — Dispatch-Template Z.117-127
- [x] Selbst-Check mit `check-wiki-output.sh` — Dispatch-Template Z.286-300
- [x] `[DISCOVERY]`-Block als Pflicht-Output — Dispatch-Template Z.304-374
- [x] `[SYNTHESE-ID]` als Pflicht-Zeile am Ende — Dispatch-Template Z.369-374

### Worker-Agent
- [x] Keine eigenen Gates — synthese-worker.md Z.34-36
- [x] `subagent_type` dient ausschliesslich Hook-Matching — synthese-worker.md Z.46-50
- [x] Tools explizit aufgelistet (Read, Write, Edit, Grep, Glob, Bash) — synthese-worker.md Z.4

---

## Edge Cases

- **Erster Synthese-Lauf:** `_konzept-reife.md` und `_schlagwort-vorschlaege.md`
  werden per Bootstrap angelegt (SKILL.md Z.60-63)
- **Konzept mit <2 Quellen:** Worker meldet `[NICHT ERSTELLT]`, keine Seite angelegt
  (Dispatch-Template Z.229-233)
- **Kontext-Budget erschoepft:** `[SYNTHESE UNVOLLSTAENDIG]`-Marker, ehrlicher Abbruch
  (SKILL.md Z.121-124)
- **Fundamentaler Widerspruch:** Eskalation via `struktur-reviewer` + `[WIDERSPRUCH]`-Marker
  (SKILL.md Z.387-391)
- **Parallel-Schutz:** `guard-pipeline-lock.sh` verhindert gleichzeitige Synthesen/Ingests,
  `_pending.json` blockiert mechanisch (SPEC-002)
- **Split bei grossen Quellmengen:** Automatische Aufteilung in Durchgaenge,
  `[SPLIT]`-Marker fuer Zwischen-Seiten (SKILL.md Z.395-403)
- **Worker-Prompt nie frei formuliert:** Template-Pflicht verhindert Prompt-Drift
  (SKILL.md Z.131-132)
