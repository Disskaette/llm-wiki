# SPEC-003: Synthese-Enforcement + Discovery-Logik

**Status:** Done
**Version:** 2.0
**Erstellt:** 2026-04-11
**Aktualisiert:** 2026-04-14

## Zusammenfassung

v1.0: Synthese-Pipeline bekommt Machine-Law-Infrastruktur (Pipeline-Lock,
Gate-Counter, Cross-Block, ID-Matching, Heuristik-Bereinigung). **Done.**

v2.0: Synthese wird um persistente Konzept-Discovery und Schlagwort-Rueckkanal
erweitert. Zwei neue Dateien (`_konzept-reife.md`, `_schlagwort-vorschlaege.md`)
tracken Erkenntnisse ueber Sessions hinweg. Synthese bekommt erweiterte
Schreibrechte (Vokabular additiv, Quellenseiten-Schlagworte additiv).
Dreischichtige Enforcement-Kette stellt sicher, dass Discovery tatsaechlich
passiert. Wiki-Review erkennt wenn die Logik nicht implementiert ist.

## Hintergrund: Die Luecke

Ingest liest EIN Buch und meldet `konzept-kandidaten` im Frontmatter der
Quellenseite — hat aber keinen Ueberblick ueber das Wiki. Synthese vergleicht
mehrere Quellen und sieht Muster, die ein Einzelingest nicht erkennen kann.

Probleme im bisherigen Zustand:
1. **Keine persistente Aggregation:** `konzept-kandidaten` in Quellenseiten sind
   verteilt, werden nur bei `/synthese` Phase 0.0 per grep zusammengefuehrt.
   Kein sessionuebergreifendes Tracking.
2. **Keine Cross-Source-Discovery:** Synthese arbeitet nur auf bereits bekannten
   Konzepten. Neue Konzepte werden nur entdeckt wenn genug Ingest-Agents
   unabhaengig denselben Term flaggen — mit moeglicherweise unterschiedlichen
   Begriffen.
3. **Kein Schlagwort-Rueckkanal:** Synthese sieht beim Quellenvergleich fehlende
   Schlagworte auf Quellenseiten, kann aber nichts tun (Ingest-Territorium).
4. **Keine Vokabular-Erweiterung:** Neue Terme die Synthese entdeckt, koennen
   nicht ins Vokabular aufgenommen werden, was nachfolgende Schlagwort-Zuordnung
   blockiert.

## Anforderungen v2.0

### Persistente Discovery-Dateien

1. `wiki/_konzept-reife.md` — Konzept-Kandidaten-Tracker mit YAML-Frontmatter
2. `wiki/_schlagwort-vorschlaege.md` — Vokabular-Rueckkanal mit YAML-Frontmatter
3. Beide Dateien werden von Synthese UND Ingest befuellt (additiv)
4. YAML-Frontmatter ist maschinenlesbare Quelle der Wahrheit
5. Markdown-Body wird bei jedem Update aus YAML regeneriert (Obsidian-Lesbarkeit)

### Discovery im Synthese-Worker

6. Synthese-Worker MUSS `[DISCOVERY]`-Block im Output liefern (Pflicht)
7. Block enthaelt: Konzept-Kandidaten, Schlagwort-Vorschlaege, Vokabular-Ergaenzungen, Schlagwort-Patches
8. Leerer Block erfordert `KEINE-DISCOVERY-BEGRUENDUNG` (Pflicht)
9. Neuer Platzhalter `{{KONZEPT_REIFE_INHALT}}` im Dispatch-Template
10. Neuer Platzhalter `{{SCHLAGWORT_VORSCHLAEGE_INHALT}}` im Dispatch-Template

### Erweiterte Synthese-Schreibrechte

11. `_vokabular.md` — nur additiv (neue Terme eintragen, keine loeschen)
12. Quellenseiten `schlagworte:`-Feld — nur additiv (ergaenzen, nie entfernen)
13. Jede Aenderung wird in `_log.md` dokumentiert

### Enforcement-Kette (3 Schichten)

14. Schicht 1 (Prompt-Law): Dispatch-Template erzwingt `[DISCOVERY]`-Block
15. Schicht 2 (Agent-Law): konsistenz-pruefer Part D prueft Discovery-Vollstaendigkeit
16. Schicht 3 (Machine-Law): check-wiki-output.sh Check 10 prueft Datei-Existenz

### Rueckkopplung

17. Phase 0.0 Rewrite: `_konzept-reife.md` als primaere Quelle statt grep
18. Rueckwaertskompatibilitaet: Quellenseiten-Kandidaten die nicht in Reife-Datei stehen → nachtragen
19. Reife-Schwelle: >=2 Quellen → status: reif

### Ingest-Integration

20. Ingest Phase 5: Kandidaten aus Quellenseiten-Frontmatter in `_konzept-reife.md` eintragen
21. Ingest-Worker-Template bleibt unveraendert

### Wiki-Review-Integration

22. Neue Pruefkategorie: Discovery-Gesundheit (6 Checks)

## Technische Details

### Neue Dateien

#### `wiki/_konzept-reife.md`

```yaml
---
kandidaten:
  - term: "Rollschub"
    quellen:
      - datei: fingerloos-ec2-2016
        kontext: "Kap. 3, S. 67-89 — Versagensmechanismus bei kurzen Spannweiten"
        entdeckt-bei: "synthese:querkraft-holz"
        datum: 2026-04-10
      - datei: colling-holzbau-2023
        kontext: "Kap. 5, S. 112 — Bemessungsformel nach EC5"
        entdeckt-bei: "synthese:querkraft-holz"
        datum: 2026-04-10
    status: reif
    erstellt-am: 2026-04-10
    aktualisiert: 2026-04-13
---

# Konzept-Reife-Tracker

Automatisch gepflegt durch Synthese (Phase 2e) und Ingest (Phase 5).
Nicht manuell editieren.

## Reife Kandidaten (>=2 Quellen)

- **Rollschub** — 2 Quellen — reif seit 2026-04-10

## Unreife Kandidaten (<2 Quellen)

(keine)
```

**Regeln:**
- `status`: `unreif` (<2 Quellen) | `reif` (>=2) | `erstellt` (Konzeptseite angelegt)
- `entdeckt-bei`: Trackt welche Synthese oder welcher Ingest den Kandidaten entdeckt hat
- Duplikat-Erkennung: Vor Eintrag pruefen ob Term oder Synonym schon existiert
- `status: erstellt` wird gesetzt wenn Konzeptseite angelegt — Eintrag bleibt als Historie

#### `wiki/_schlagwort-vorschlaege.md`

```yaml
---
neue-terme:
  - term: "Hirnholzpressung"
    grund: "3 Quellen verwenden diesen Begriff, nicht im Vokabular"
    quellen: [fingerloos-ec2-2016, colling-holzbau-2023, blass-holzbau-2022]
    vorgeschlagen-bei: "synthese:druckbeanspruchung"
    datum: 2026-04-13
    status: offen

fehlende-zuordnungen:
  - quellenseite: fingerloos-ec2-2016
    fehlende-schlagworte: ["Rollschub", "Querkraft"]
    grund: "Kapitel 3 behandelt Rollschub ausfuehrlich, Schlagwort fehlt"
    vorgeschlagen-bei: "synthese:querkraft-holz"
    datum: 2026-04-13
    status: offen
---

# Schlagwort-Vorschlaege

Automatisch gepflegt durch Synthese (Phase 2e).

## Neue Terme (nicht im Vokabular)

- **Hirnholzpressung** — 3 Quellen, offen seit 2026-04-13

## Fehlende Zuordnungen (Quellenseite hat Schlagwort nicht)

- **fingerloos-ec2-2016** — fehlt: Rollschub, Querkraft
```

**Regeln:**
- `status`: `offen` | `umgesetzt` | `abgelehnt`
- `umgesetzt` wird gesetzt wenn `/vokabular` den Term aufnimmt bzw. Schlagwort ergaenzt
- Synthese darf `fehlende-zuordnungen` direkt umsetzen (Schlagwort-Patch auf Quellenseite)
- `/vokabular` liest `neue-terme` als Input fuer Vokabular-Erweiterung

### Erweitertes Synthese-Schreibrechte-Modell

| Was | Wo | Eingriff | Bisherig | Neu |
|-----|----|----------|----------|-----|
| Konzeptseite schreiben/updaten | `wiki/konzepte/` | Voll | Ja | — |
| `_konzept-reife.md` pflegen | `wiki/` | Voll | — | Ja |
| `_schlagwort-vorschlaege.md` pflegen | `wiki/` | Voll | — | Ja |
| `_vokabular.md` ergaenzen | `wiki/` | Nur additiv (neue Terme) | — | Ja |
| Quellenseiten-Frontmatter | `wiki/quellen/` | Nur `schlagworte:` additiv | — | Ja |
| `_log.md` Eintrag | `wiki/` | Append | Ja | — |
| `_index/` aktualisieren | `wiki/_index/` | Update | Ja | — |

`guard-wiki-writes.sh` braucht keine Aenderung — erlaubt Writes waehrend `/synthese` bereits.

### Verantwortlichkeiten: Worker vs. Orchestrator

| Aktion | Wer | Wann |
|--------|-----|------|
| `_vokabular.md` ergaenzen (neue Terme) | **Worker** | Waehrend Phase 2e (im Subagent) |
| Quellenseiten `schlagworte:` patchen | **Worker** | Waehrend Phase 2e (im Subagent) |
| `[DISCOVERY]`-Block melden | **Worker** | Am Ende des Outputs |
| `_konzept-reife.md` aktualisieren | **Orchestrator** | Phase 5 (Nebeneffekte) |
| `_schlagwort-vorschlaege.md` aktualisieren | **Orchestrator** | Phase 5 (Nebeneffekte) |
| `_log.md` Discovery-Eintraege | **Orchestrator** | Phase 5 (Nebeneffekte) |

Grund: Der Worker hat den Kontext (welche Terme, welche Quellenseiten) und
kann `_vokabular.md` und Quellenseiten direkt schreiben. Die Gates verifizieren
dass diese Writes korrekt waren. Der Orchestrator persistiert danach nur die
Tracking-Metadaten in den Discovery-Dateien.

### Discovery im Synthese-Worker: [DISCOVERY]-Block

Pflicht-Output-Block am Ende des Worker-Ergebnisses:

```
═══════════════════════════════════════════════════════
[DISCOVERY]
═══════════════════════════════════════════════════════

KONZEPT-KANDIDATEN:
- term: "Rollschub"
  quellen: fingerloos-ec2-2016 (Kap. 3, S. 67-89), colling-holzbau-2023 (Kap. 5, S. 112)
- term: "Gamma-Verfahren"
  quellen: blass-holzbau-2022 (Kap. 7, S. 201-215)

SCHLAGWORT-VORSCHLAEGE:
- neu: "Hirnholzpressung" — 3 Quellen verwenden den Begriff, fehlt im Vokabular
- fehlend: fingerloos-ec2-2016 → [Rollschub, Querkraft]

VOKABULAR-ERGAENZUNGEN:
- "Hirnholzpressung" → in _vokabular.md eingetragen

SCHLAGWORT-PATCHES:
- fingerloos-ec2-2016 → schlagworte: +Rollschub, +Querkraft

KEINE-DISCOVERY-BEGRUENDUNG: null
```

Wenn nichts entdeckt — Begruendung Pflicht:

```
KONZEPT-KANDIDATEN: keine
SCHLAGWORT-VORSCHLAEGE: keine
VOKABULAR-ERGAENZUNGEN: keine
SCHLAGWORT-PATCHES: keine
KEINE-DISCOVERY-BEGRUENDUNG: "Alle im Quellenvergleich aufgetretenen
Fachbegriffe existieren bereits als Konzeptseiten. Keine Terme identifiziert
die im Vokabular fehlen."
```

### Enforcement-Kette

#### Schicht 1: Dispatch-Template (Prompt-Law)

`synthese-dispatch-template.md` bekommt:
- Neuen Abschnitt `PHASE 2e: DISCOVERY — NICHT VERHANDELBAR`
- Pflicht-Output: `[DISCOVERY]`-Block
- Neue Platzhalter: `{{KONZEPT_REIFE_INHALT}}`, `{{SCHLAGWORT_VORSCHLAEGE_INHALT}}`
- Dokumentierte Schreibrechte: `_vokabular.md` additiv, Quellenseiten-`schlagworte:` additiv

#### Schicht 2: Gate-Check (Agent-Law)

`gate-dispatch-template.md` — konsistenz-pruefer bekommt neuen Part D
(nur aktiv bei Synthese-Gates, nicht bei Ingest-Gates):

```
Part D — Discovery-Check:
1. Hat der Worker einen [DISCOVERY]-Block geliefert?
   → FEHLT komplett: FAIL
2. Wenn "keine" bei Kandidaten/Vorschlaegen:
   Gibt es eine KEINE-DISCOVERY-BEGRUENDUNG?
   → FEHLT: FAIL
   → Ist die Begruendung plausibel? (nicht nur "nichts gefunden")
3. Wenn Kandidaten gemeldet:
   → Ist fuer jeden Kandidat mindestens eine Quelle mit Kontext angegeben?
   → Existiert der Term bereits als Konzeptseite? Dann ist er KEIN Kandidat.
4. Wenn Schlagwort-Vorschlaege gemeldet:
   → Sind die vorgeschlagenen Terme tatsaechlich nicht im Vokabular?
   → Sind die fehlenden Zuordnungen plausibel?
5. Wenn Vokabular-Ergaenzungen gemeldet:
   → Wurde _vokabular.md tatsaechlich geschrieben?
   → Steht der neue Term jetzt drin?
6. Wenn Schlagwort-Patches gemeldet:
   → Wurde das schlagworte:-Feld der Quellenseite tatsaechlich ergaenzt?
   → Nur additiv? (keine bestehenden Schlagworte entfernt?)

Ergebnis: PASS oder FAIL (mit konkretem Befund)
```

#### Schicht 3: Shell-Check (Machine-Law)

`check-wiki-output.sh` — neuer Check 10 (nur bei Konzeptseiten-Output):

```bash
# Check 10: Discovery-Dateien existieren
# Prueft nur Datei-Existenz, kein Inhalt (Kontext-Entscheidungen → Gate-Agents)
# Aktiv wenn: type: konzept im Frontmatter
```

### Synthese-Skill Aenderungen

#### Phase 0.0 (Rewrite)

Bisherig:
```
1. grep "konzept-kandidaten:" wiki/quellen/*.md
2. Zaehle pro Kandidat
3. >=2 → Synthese-Liste
```

Neu:
```
1. Lies _konzept-reife.md (YAML-Frontmatter parsen)
   → Liste aller Kandidaten mit Status
2. Rueckwaertskompatibilitaet: Scanne Quellenseiten-Frontmatter
   → Kandidaten die NICHT in _konzept-reife.md stehen → dort nachtragen
3. Reife-Bericht an Nutzer:
   "Reife Kandidaten (>=2 Quellen): [Liste mit Quellenanzahl]
    Unreife Kandidaten (1 Quelle): [Liste]
    Seit letzter Synthese neu hinzugekommen: [Liste]"
4. Nutzer waehlt welche reifen Kandidaten synthetisiert werden
5. _schlagwort-vorschlaege.md pruefen:
   → Offene Vorschlaege melden:
   "N offene Schlagwort-Vorschlaege. /vokabular empfohlen?"
```

#### Phase 0.6 (Dispatch vorbereiten)

Neue Platzhalter befuellen:
- `{{KONZEPT_REIFE_INHALT}}`: Read `_konzept-reife.md` → inline einfuegen
- `{{SCHLAGWORT_VORSCHLAEGE_INHALT}}`: Read `_schlagwort-vorschlaege.md` → inline einfuegen

#### Phase 5 (Nebeneffekte — erweitert)

Bisherig:
- [ ] Seite speichern
- [ ] _index aktualisieren
- [ ] _log.md Eintrag
- [ ] MOC pruefen
- [ ] check-wiki-output.sh
- [ ] Pipeline-Lock freigeben

Neu (eingefuegt vor check-wiki-output.sh):
- [ ] Seite speichern
- [ ] _index aktualisieren
- [ ] _log.md Eintrag (inkl. Discovery-Zusammenfassung: N Kandidaten, M Patches)
- [ ] MOC pruefen
- [ ] **Discovery persistieren** (Worker hat _vokabular.md + Quellenseiten-Patches
  bereits geschrieben und Gates haben verifiziert — jetzt nur Tracking-Metadaten):
  - `[DISCOVERY]`-Block aus Worker-Output parsen
  - Konzept-Kandidaten → `_konzept-reife.md` (Duplikat-Check, Status-Berechnung)
  - Schlagwort-Vorschlaege → `_schlagwort-vorschlaege.md`
  - Bereits umgesetzte Patches als `status: umgesetzt` markieren
  - Markdown-Body beider Dateien aus YAML regenerieren
- [ ] check-wiki-output.sh (inkl. Check 10)
- [ ] Pipeline-Lock freigeben (bleibt letzter Schritt)

**Persistierungs-Logik fuer _konzept-reife.md:**
```
Fuer jeden Konzept-Kandidat aus [DISCOVERY]-Block:
1. Existiert Term schon in _konzept-reife.md?
   JA → Neue Quellen ergaenzen, aktualisiert-Datum setzen, Status neu berechnen
   NEIN → Neuen Eintrag anlegen
2. Existiert bereits Konzeptseite fuer den Term?
   JA → Nicht eintragen (kein Kandidat mehr)
3. Status-Berechnung: >=2 Quellen → reif, <2 → unreif
4. Markdown-Body aus YAML regenerieren
```

### Ingest-Skill Aenderungen

Phase 5 (Nebeneffekte) — ein neuer Schritt:

```
NEU: Kandidaten in _konzept-reife.md eintragen

Fuer jeden konzept-kandidat aus dem Frontmatter der neuen Quellenseite:
1. Existiert Term schon in _konzept-reife.md?
   JA → Neue Quelle ergaenzen, Datum aktualisieren, Status neu berechnen
   NEIN → Neuen Eintrag mit entdeckt-bei: "ingest:<quellenseite>" anlegen
2. Status-Berechnung: >=2 Quellen → reif, <2 → unreif
3. Markdown-Body regenerieren
```

Falls `_konzept-reife.md` noch nicht existiert (erster Ingest vor erster Synthese):
Datei mit leerem `kandidaten: []` Bootstrap anlegen.

### Wiki-Review Aenderungen

Neue Pruefkategorie: **Discovery-Gesundheit**

| Check | Prueft | Ergebnis bei Versagen |
|-------|--------|-----------------------|
| DATEIEN-CHECK | `_konzept-reife.md` + `_schlagwort-vorschlaege.md` existieren | "Discovery-Dateien nicht angelegt. Wurde /synthese schon einmal ausgefuehrt?" |
| STALE-CHECK | Letztes Update vs. Synthese-Laeufe seit letztem Update (aus `_log.md`) | "N Synthese-Laeufe seit letztem Discovery-Update. Discovery wird moeglicherweise uebersprungen." |
| REIFE-CHECK | Reife Kandidaten (>=2 Quellen) ohne Konzeptseite seit >2 Synthese-Laeufen | "Rollschub ist seit 2026-04-10 reif (3 Quellen), aber noch keine Konzeptseite." |
| RUECKSTAU-CHECK | Offene Eintraege in `_schlagwort-vorschlaege.md` aelter als 3 Synthese-Laeufe | "12 offene Schlagwort-Vorschlaege, aeltester seit 2026-04-10. /vokabular empfohlen." |
| KONSISTENZ-CHECK | `konzept-kandidaten` in Quellenseiten die NICHT in `_konzept-reife.md` stehen | "5 Kandidaten aus Quellenseiten fehlen in _konzept-reife.md. Phase 0.0 Sync nicht gelaufen." |
| GHOST-CHECK | Eintraege mit `status: erstellt` wo Konzeptseite nicht existiert | "Rollschub als 'erstellt' markiert, aber wiki/konzepte/rollschub.md existiert nicht." |

## Was sich NICHT aendert

- `guard-wiki-writes.sh` — erlaubt Writes waehrend `/synthese` bereits
- `guard-pipeline-lock.sh` — Pipeline-Lock-Mechanik unveraendert
- `advance-pipeline-lock.sh` — Counter-Logik unveraendert, `gates_total` bleibt 3
- `create-pipeline-lock.sh` — Worker-Stop-Logik unveraendert
- `hard-gates.md` — kein neues Hard Gate
- `seitentypen.md` — kein neuer Seitentyp
- Ingest-Worker-Template — unveraendert (Persistierung passiert im Skill, nicht im Worker)

## Akzeptanzkriterien v1.0 (erledigt)

- [x] synthese-worker blockiert bei offenem Ingest-Lock
- [x] ingest-worker blockiert bei offenem Synthese-Lock
- [x] Synthese gates_total=3 → sideeffects nach 3 Gate-Stops
- [x] INGEST-ID Match → Counter steigt
- [x] INGEST-ID Mismatch → Counter bleibt
- [x] Kein ID-Marker → Counter steigt (Rueckwaertskompatibilitaet)
- [x] Heuristische Checks entfernt, 12 deterministische bleiben
- [x] Unit-Tests: 10/10 + 16/16 + 7/7 + 6/6
- [x] Integration-Test: 137/137
- [x] Konsistenz: 19/19

## Akzeptanzkriterien v2.0

### Discovery-Dateien
- [ ] `_konzept-reife.md` wird beim ersten Synthese-Lauf angelegt (Bootstrap)
- [ ] `_konzept-reife.md` wird beim ersten Ingest angelegt wenn noch nicht vorhanden
- [ ] YAML-Frontmatter ist parsbar und entspricht dem definierten Schema
- [ ] Markdown-Body wird bei jedem Update aus YAML regeneriert
- [ ] Duplikat-Erkennung: gleicher Term wird nicht doppelt eingetragen

### Discovery im Worker
- [ ] Synthese-Worker liefert `[DISCOVERY]`-Block im Output
- [ ] Leerer Block hat `KEINE-DISCOVERY-BEGRUENDUNG`
- [ ] Konzept-Kandidaten enthalten Quellen mit Kontext
- [ ] Schlagwort-Vorschlaege unterscheiden neue Terme und fehlende Zuordnungen
- [ ] Vokabular-Ergaenzungen werden tatsaechlich in `_vokabular.md` geschrieben
- [ ] Schlagwort-Patches sind nur additiv (bestehende Schlagworte nicht entfernt)

### Enforcement
- [ ] konsistenz-pruefer Part D: FAIL wenn `[DISCOVERY]`-Block fehlt
- [ ] konsistenz-pruefer Part D: FAIL wenn leerer Block ohne Begruendung
- [ ] konsistenz-pruefer Part D: Prueft Vokabular-Ergaenzungen und Schlagwort-Patches
- [ ] check-wiki-output.sh Check 10: FAIL wenn Discovery-Dateien nicht existieren (bei Konzeptseiten)

### Rueckkopplung
- [ ] Phase 0.0 liest `_konzept-reife.md` als primaere Quelle
- [ ] Phase 0.0 synchronisiert Quellenseiten-Kandidaten in Reife-Datei (Rueckwaertskompatibilitaet)
- [ ] Reife-Bericht an Nutzer mit reifen/unreifen Kandidaten
- [ ] Schlagwort-Vorschlaege-Bericht an Nutzer

### Ingest-Integration
- [ ] Ingest Phase 5 traegt Kandidaten in `_konzept-reife.md` ein
- [ ] Status-Berechnung korrekt (>=2 Quellen → reif)
- [ ] Ingest-Worker-Template bleibt unveraendert

### Wiki-Review
- [ ] DATEIEN-CHECK: Erkennt fehlende Discovery-Dateien
- [ ] STALE-CHECK: Erkennt wenn Discovery nicht aktualisiert wird
- [ ] REIFE-CHECK: Meldet reife Kandidaten ohne Konzeptseite
- [ ] RUECKSTAU-CHECK: Meldet alte offene Schlagwort-Vorschlaege
- [ ] KONSISTENZ-CHECK: Findet Kandidaten die nicht in Reife-Datei stehen
- [ ] GHOST-CHECK: Findet "erstellt"-Eintraege ohne existierende Konzeptseite

### Tests
- [ ] Bestehende Tests weiterhin grueen (258 Tests)
- [ ] check-wiki-output.sh Check 10 getestet
- [ ] Konsistenz-Check 21/21 PASS (oder mehr, falls neue Checks)

## Edge Cases

- **Erster Ingest vor erster Synthese:** `_konzept-reife.md` wird mit leerem
  `kandidaten: []` angelegt. `_schlagwort-vorschlaege.md` wird erst bei erster
  Synthese angelegt.
- **Synthese auf Konzept das noch "unreif" ist:** Worker prueft Quellenanzahl.
  Wenn <2 Quellen substanziell → `[NICHT ERSTELLT]` melden (bestehende Logik).
- **Synonyme:** Ingest meldet "Querkraftuebertragung", Synthese entdeckt dass das
  dasselbe wie "Querkraft-Transfer" ist → zusammenfuehren in `_konzept-reife.md`
  (manuell oder durch Synthese-Worker).
- **Abgelehnte Terme:** `/vokabular` kann Terme ablehnen → `status: abgelehnt`
  in `_schlagwort-vorschlaege.md`. Synthese schlaegt abgelehnte Terme nicht
  erneut vor.
- **Concurrent Sessions:** `guard-pipeline-lock.sh` verhindert parallele
  Synthese-Laeufe — Discovery-Dateien koennen nicht gleichzeitig geschrieben werden.
- **Grosse Wikis (100+ Quellen):** `_konzept-reife.md` YAML kann lang werden.
  Kein Problem — wird komplett ins Context geladen (<<100K Tokens selbst bei
  500 Kandidaten). Falls es doch zu gross wird: SPEC-007 Hybrid-Suche.
