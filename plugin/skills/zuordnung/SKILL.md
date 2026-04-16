---
name: zuordnung
description: "Quellen-Zuordnung — inhaltliches Matching, Schlagwort-Audit, Konzept-Rueckverweise"
user-invocable: true
---

## Governance-Vertrag

> Zuordnung laedt ALLE Quellen-Zusammenfassungen und ALLE Konzeptseiten in einen Worker
> und baut eine inhaltliche Zuordnungs-Matrix. Gleichzeitig: Schlagwort-Audit (fehlende
> Tags patchen, neue Terme vorschlagen) und Konzept-Rueckverweise (`relevant-fuer:`)
> auf Quellenseiten. Keine Gate-Pipeline, keine `_pending.json` — Verifikation per
> `check-zuordnung-output.sh` direkt im Orchestrator.

| Gate | Durchsetzung | Wie | Bedingung |
|------|-------------|-----|-----------|
| KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG | ⚪ N/A | Zuordnung liest Quellen-Zusammenfassungen, nicht ganze Buecher — kein Volllesung-Gate | — |
| KEIN-INHALT-OHNE-SEITENANGABE | ⚪ N/A | Zuordnung schreibt keine Content-Seiten mit Aussagen — nur Meta-Dateien und Frontmatter-Patches | — |
| KEIN-ZAHLENWERT-OHNE-QUELLE | ⚪ N/A | Zuordnung schreibt keine Zahlenwerte in Content-Seiten | — |
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | ⚪ N/A | Zuordnung schreibt keine Norm-Referenzen in Content-Seiten | norm-Typ aktiv |
| KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS | ⚪ N/A | Zuordnung schreibt keine Konzeptseiten | — |
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | ✅ Aktiv | Worker prueft Vokabular vor Schlagwort-Patch; `check-zuordnung-output.sh` verifiziert Patch-Terme | — |
| KEIN-UPDATE-OHNE-DIFF | ⚪ N/A | Zuordnung patcht nur Frontmatter-Felder; _log.md Eintrag dokumentiert alle Patches | — |
| KEIN-WIDERSPRUCH-OHNE-MARKIERUNG | ⚪ N/A | Zuordnung schreibt keine inhaltlichen Aussagen die Widersprueche erzeugen koennten | — |
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | ✅ Aktiv | Worker liest alle Quellenseiten vollstaendig (Frontmatter + erste 50 Zeilen Body) vor Patch | — |
| KORREKTE-UMLAUTE | 🔄 Delegiert | Worker-Instruktionen und Dispatch-Template schreiben Unicode-Umlaute vor | — |

**Wiki-Writes NUR ueber `bibliothek:zuordnung-worker`.**
`guard-wiki-writes.sh` Whitelist enthaelt `zuordnung`.
`guard-pipeline-lock.sh` blockiert `bibliothek:zuordnung-worker` wenn ein anderer Lock aktiv ist.
`guard-dispatch-template.sh` blockiert Dispatch wenn `governance/zuordnung-dispatch-template.md` nicht gelesen wurde.

**KEIN eigener Pipeline-Lock:** `/zuordnung` erzeugt kein `_pending.json` und
hat keine eigene Gate-Pipeline. Sie wird jedoch durch bestehende Locks blockiert
(laufender Ingest oder Synthese → `/zuordnung` muss warten).

---

## Context-Budget — Orchestrator

<NICHT-VERHANDELBAR>
DU (der Orchestrator, der diesen Skill ausfuehrt) hast ein Kontextfenster:
- **Opus:** 1.000.000 Tokens
- **Sonnet:** 200.000 Tokens

/zuordnung laedt ALLE Quellen + ALLE Konzepte in den Worker-Prompt.
Typische Groessenordnung: 94 Quellen × 55 Zeilen ≈ 150K Tokens.
Das passt in Opus locker. In Sonnet wird es knapp.

**Modellwahl fuer den Orchestrator:**
- Opus empfohlen (>50 Quellen → viel Sammelarbeit in Phase 0/1)
- Sonnet moeglich bei <30 Quellen — dann Zusammenfassungen kuerzen (30 statt 50 Zeilen)

**Regeln:**
1. Read-Tool liest max 2000 Zeilen pro Aufruf — mehrere Aufrufe machen.
2. Alle Zusammenfassungen INLINE in den Worker-Prompt einfuegen.
3. KEIN Ausweichen auf /tmp-Dateien oder "Worker liest selbst".
4. KEIN "das ist zu gross" — RECHNE NACH: Zeilen × 1.3 ≈ Tokens.
5. Der WORKER hat IMMER 1M Tokens (laeuft auf Opus).
</NICHT-VERHANDELBAR>

---

## Phasen

### Phase 0: Context laden

1. **Wiki-Verzeichnis pruefen:**
   - Existiert `wiki/`? Falls nein → Meldung: "Erst `/ingest` ausfuehren."
   - Existiert `wiki/quellen/`? Falls leer → Meldung: "Mindestens eine Quelle noetig."

2. **Vokabular laden:**
   - Lies `wiki/_vokabular.md` vollstaendig
   - Alle kontrollierten Terme extrahieren (fuer Schlagwort-Audit)

3. **Konzept-Reife-Status laden:**
   - Existiert `wiki/_konzept-reife.md`? Dann lesen (YAML-Frontmatter + Body)
   - Falls nicht vorhanden: wird im Worker neu angelegt (Bootstrap)
   - Reife Kandidaten (>= 2 Quellen) merken — Worker beruecksichtigt sie beim Mapping

4. **Alle Quellenseiten identifizieren:**
   - Glob `wiki/quellen/*.md` → Dateiliste
   - AUSSCHLIESSEN: Dateien mit `_`-Prefix (`_index.md`, `_template.md` etc.)
   - Zaehle exakt: `QUELLEN_ANZAHL` = Anzahl verbleibender Dateien
   - Fuer jede Quelle: Frontmatter + erste 50 Zeilen Body laden
   - Extrakt: `bibtex-key`, `titel`, `schlagworte`, `zusammenfassung`
   - Melde dem Nutzer: "N Quellenseiten gefunden."

5. **Alle Konzeptseiten identifizieren:**
   - Glob `wiki/konzepte/*.md` (falls Verzeichnis existiert) → Dateiliste
   - AUSSCHLIESSEN: Dateien mit `_`-Prefix
   - Zaehle exakt: `KONZEPTE_ANZAHL` = Anzahl verbleibender Dateien
   - Fuer jede Konzeptseite: Frontmatter + `## Zusammenfassung` Abschnitt laden
   - Extrakt: Dateiname, `title`, `schlagworte`, `quellen`, Zusammenfassungstext
   - Melde dem Nutzer: "M Konzeptseiten gefunden."

6. **Dispatch-Template laden:**
   - Lies `governance/zuordnung-dispatch-template.md` vollstaendig
   - PFLICHT vor Worker-Dispatch (guard-dispatch-template.sh prueft das)

---

### Phase 1: Worker-Dispatch

<NICHT-VERHANDELBAR>
Subagent-Prompts werden NICHT frei formuliert. IMMER Template verwenden.
</NICHT-VERHANDELBAR>

1. **Platzhalter befuellen** (6 Stueck):
   - `{{QUELLEN_ZUSAMMENFASSUNGEN}}`: Frontmatter + erste 50 Zeilen Body jeder Quelldatei
   - `{{KONZEPT_ZUSAMMENFASSUNGEN}}`: Frontmatter + Zusammenfassung jeder Konzeptseite
   - `{{KONZEPT_REIFE_INHALT}}`: Vollstaendiger Inhalt von `_konzept-reife.md` (oder leer)
   - `{{VOKABULAR_TERME}}`: Vollstaendiger Inhalt von `_vokabular.md`
   - `{{LOG_HASH}}`: Erster Satz des juengsten `_log.md`-Eintrags (fuer Drift-Erkennung)
   - `{{WIKI_VERZEICHNIS}}`: Absoluter Pfad zu `wiki/`

2. **Worker dispatchen:**
   - `subagent_type: "bibliothek:zuordnung-worker"` (PFLICHT — guard-pipeline-lock.sh
     matcht auf diesen String und blockiert wenn `_pending.json` von anderem Skill aktiv ist)
   - `prompt`: ausgefuelltes Template aus Schritt 1
   - `model`: "opus" (braucht ALLE Quellen im Kontext, 1M Tokens)
   - `description`: "Zuordnung: alle Quellen → alle Konzepte"

3. **Worker-Jobs (3 parallel im Worker):**
   - **Job 1 — Quelle→Konzept-Mapping:** Jede Quelle inhaltlich zuordnen (welche
     Konzepte/Kandidaten behandelt sie substanziell?), Begruendung pro Zuordnung
   - **Job 2 — Schlagwort-Audit:** Fehlende Tags auf Quellenseiten erkennen und
     patchen (nur additiv), neue Terme fuer `_vokabular.md` vorschlagen
   - **Job 3 — Konzept-Rueckverweise:** `relevant-fuer:` auf Quellenseiten-Frontmatter
     patchen (nur additiv), Obsidian-Graph-Kante Quelle→Konzept

4. **Worker-Schreibartefakte:**
   - `wiki/_quellen-mapping.md` (komplett neu, kein Merge)
   - `wiki/quellen/*.md` — Frontmatter-Patches (`schlagworte:` und `relevant-fuer:`, nur additiv)
   - `wiki/_vokabular.md` — neue Terme additiv
   - `wiki/_konzept-reife.md` — neue Kandidaten additiv

5. Warte auf Worker-Rueckkehr, dann weiter mit Phase 2

---

### Phase 2: Verifikation + Nebeneffekte

1. **`_quellen-mapping.md` pruefen:**
   - Frontmatter-Felder vorhanden: `quellen-stand`, `konzepte-stand`, `mapping-version`?
   - `updated` Datum aktuell?

2. **Vollstaendigkeits-Check:**
   - Zaehle Dateien in `wiki/quellen/`
   - Zaehle Quellen in der Mapping-Matrix
   - Jede Quelldatei muss in der Matrix auftauchen — kein Orphan erlaubt

3. **Konsistenz-Check relevant-fuer:**
   - Fuer jede Zuordnung in der Matrix: Hat die Quellenseite das Konzept in `relevant-fuer:`?
   - Bidirektionale Konsistenz: Mapping-Eintrag ↔ Frontmatter-Feld
   - Bei Diskrepanz: Meldung + manuelle Pruefung empfehlen (kein Auto-Patch)

4. **`check-zuordnung-output.sh` ausfuehren:**
   - Deterministischer Shell-Check (Orphan-Erkennung, Datei-Existenz-Pruefung,
     Vokabular-Check fuer Patch-Terme, Rueckverweis-Konsistenz)
   - Bei FAIL — korrekter Ablauf pro Check:

     <NICHT-VERHANDELBAR>
     **Check 06 (rueckverweis):** Fehlende `relevant-fuer:` auf Quellenseiten
     → NACHTRAGEN (Edit-Tool), nicht ignorieren.

     **Check 07 (vokabular-patch):** Terme in Audit-Tabelle die nicht im
     Vokabular stehen → IN `_vokabular.md` EINTRAGEN (Edit-Tool, additiv).
     NIEMALS die Terme aus der Audit-Tabelle loeschen um den Check zu bestehen.
     Die Audit-Tabelle ist das Ergebnis der Worker-Analyse. Wenn der Worker
     einen Term als fehlend identifiziert hat, ist die Loesung: Term ins
     Vokabular aufnehmen — nicht die Evidenz vernichten.

     **Allgemein:** FAIL bedeutet "behebe die Ursache", nicht "loesche die
     Daten bis der Check PASS zeigt".
     </NICHT-VERHANDELBAR>

5. **`_log.md` Eintrag schreiben:**
   ```markdown
   ## [DATUM] zuordnung | alle Quellen
   - Quellen gemapt: N
   - Konzepte abgedeckt: M
   - Neue Kandidaten: K
   - Schlagwort-Patches: P Quellenseiten
   - Neue Vokabular-Terme: V
   - check-zuordnung-output.sh: PASS
   ```

6. **Abschlussmeldung:**
   ```
   Zuordnung abgeschlossen. N Quellen → M Konzepte. K neue Kandidaten.
   Schlagwort-Patches: P Quellenseiten. Neue Vokabular-Terme: V.
   ```

---

## Trigger-Dokumentation

`/zuordnung` sollte ausgefuehrt werden:

1. **Nach jedem `/ingest`** (empfohlen) — neue Quelle bedeutet Mapping veraltet.
   Alle Konzepte muessen neu gegenueber der neuen Quelle geprueft werden.

2. **Nach neuer Konzeptseite** (via `/synthese` — neue Seite erzeugt) — Mapping
   zeigt noch nicht welche Quellen die neue Konzeptseite fuettern.

3. **Manuell** — Nutzer ruft `/zuordnung` auf oder sagt "Quellen zuordnen"
   oder "Mapping aktualisieren".

4. **Automatisch vor Synthese** — `guard-mapping-freshness.sh` blockiert
   `/synthese` wenn `quellen-stand` oder `konzepte-stand` nicht mehr stimmt.
   In dem Fall: erst `/zuordnung`, dann `/synthese`.

---

## Konflikt + Eskalation

**Problem: Worker kann Quelle keinem Konzept zuordnen.**

→ Quelle in "Nicht zugeordnete Quellen" Abschnitt des Mappings eintragen
→ Kein Fehler, keine Blockade — thematisch ausserhalb des Wiki-Fokus ist OK
→ Meldung an Nutzer: "N Quellen ohne Konzept-Zuordnung — Details in `_quellen-mapping.md`"

**Problem: Sehr grosses Wiki (>100 Quellen).**

→ Worker laedt Zusammenfassungen statt Volltext (100 Quellen × 50 Zeilen ≈ 50K Tokens)
→ Passt locker in 1M Opus-Context — KEIN Split noetig

**Problem: `_pending.json` blockiert `/zuordnung`.**

→ Laufender Ingest oder Synthese muss erst abgeschlossen werden
→ Meldung: `guard-pipeline-lock.sh` blockiert mit Hinweis auf aktiven Lock-Typ
→ Nach Abschluss des aktiven Workflows: `/zuordnung` erneut starten
