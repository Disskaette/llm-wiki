# SPEC-015: Split-Ingest Pipeline-Lock-Fix + Advance-Counter-Bug

**Status:** Planned
**Version:** 1.0
**Erstellt:** 2026-04-17
**Aktualisiert:** 2026-04-17

> Entdeckt waehrend der Wiki-Sanierungs-Session (Projekt Masterarbeit, 53 Quellen Re-Ingest).
> Zwei separate Bugs in der Pipeline-Lock-Mechanik (SPEC-002) die bei Split-Ingest zusammenwirken.

---

## Zusammenfassung

Beim Ausfuehren eines Split-Ingests (PDF > 10 MB, mehrere sequentielle `bibliothek:ingest-worker`-Dispatches fuer dieselbe Quelle) treten zwei Probleme auf:

1. **Split-Block-Blocker:** Der `guard-pipeline-lock.sh`-PreToolUse-Hook blockiert Block 2..N weil nach Block 1 bereits `_pending.json` auf `stufe: "gates"` steht. Die Auto-Lock-Logik aus SPEC-002 v2.0 weiss nicht, dass es sich um einen Split handelt und die naechsten Bloecke noch kommen.
2. **Advance-Counter-Stillstand:** Der `advance-pipeline-lock.sh`-SubagentStop-Hook auf Gate-Agents inkrementiert den `gates_passed`-Counter im `_pending.json` nicht. Beobachtet waehrend der Wiki-Sanierung 2026-04-17: Fuer `auer_verbundmodell` und `blass_flaig_blockscheren` wurden alle 4 Gates dispatcht und PASS gemeldet, aber der Counter blieb die gesamte Zeit auf `0/4`. Damit funktioniert der mechanische Uebergang `gates` → `sideeffects` nicht.

Ergebnis: Der Orchestrator muss `_pending.json` manuell mit `rm` entfernen (Option 3 aus `guard-pipeline-lock.sh`) — damit wird der Lock-Schutz fuer Split-Ingests de facto ausser Kraft gesetzt, und die Nachvollziehbarkeit der Gate-Ergebnisse haengt an der manuellen Dokumentation durch den Orchestrator, nicht am Lock-Counter.

---

## Beobachtungen (aus Session 2026-04-17)

### Szenario 1: auer_verbundmodell (Split opus 4 Bloecke)

1. Block 1 Worker → Exit → Hook setzt `_pending.json: {typ:"ingest", quelle:"auer_verbundmodell", stufe:"gates", gates_passed:0, gates_total:4}`
2. Block 2 Worker dispatchen → `guard-pipeline-lock.sh` blockiert (exit 2): "PIPELINE-LOCK: Neuer Dispatch blockiert. Offene Quelle: auer_verbundmodell ..."
3. Orchestrator muss `rm wiki/_pending.json` ausfuehren
4. Block 2..4 analog — bei jedem Worker-Exit Lock neu, bei jedem Block-Start manuell geloescht
5. Nach Block 4 → 4 Gate-Agents parallel dispatcht
6. Alle 4 Gates liefern PASS in ihren Abschlussberichten mit `[INGEST-ID:auer_verbundmodell.md]`
7. Counter blieb waehrend der gesamten Gate-Phase `gates_passed:0` — Hook `advance-pipeline-lock.sh` hat nicht inkrementiert
8. Orchestrator muss Phase-4-Nebeneffekte manuell machen und `_pending.json` am Ende loeschen

### Szenario 2: blass_flaig_blockscheren (Split sonnet 2 Bloecke + Gate-Re-Dispatch)

Analog zu Szenario 1. Zusaetzlich: Gate 3 und Gate 4 hatten FAIL → Re-Dispatch → PASS. Auch hier: Counter blieb `0/4` trotz 4 × PASS + 2 erfolgreiche Re-Dispatches.

---

## Ursachenanalyse (zu verifizieren)

### Problem 1: Split-Block-Blocker

`guard-pipeline-lock.sh` kennt nur drei `stufe`-Werte: `gates` und `sideeffects` blocken, alles andere laesst durch. Es gibt keinen Zustand `"split-in-progress"` der signalisiert: "Dieselbe Quelle darf weiter Worker-Dispatches starten".

### Problem 2: Advance-Counter-Stillstand

Moegliche Ursachen:
- `advance-pipeline-lock.sh` ist nicht auf die korrekten Gate-Agent-Types registriert (`bibliothek:vollstaendigkeits-pruefer`, `bibliothek:quellen-pruefer`, `bibliothek:konsistenz-pruefer`, `bibliothek:vokabular-pruefer`)
- Der Hook liest `last_assistant_message` falsch — die INGEST-ID ist zwar im Bericht, aber das JSON-Parsing des Transcripts schlaegt fehl
- Der PASS-Detektor im Hook matcht "Gesamtergebnis: PASS" nicht zuverlaessig (z. B. weil Gate 4 "Kapitel wird freigegeben." schreibt statt klarem PASS-Statement, und der Hook dann nicht inkrementiert)
- Das `jq`-Schreiben zurueck in `_pending.json` scheitert silent

Debugging-Schritt: Hook-Logs (falls aktiv) in der Session 2026-04-17 nachlesen, oder einen Test-Gate-Run mit Debug-Output laufen lassen.

---

## Zieldesign

### Split-fuehrender Zustand im Lock

`_pending.json`-Stufen erweitern:

```json
{
  "typ": "ingest",
  "quelle": "auer_verbundmodell",
  "stufe": "split-in-progress",
  "split_block": 1,
  "split_total": 4,
  "gates_passed": 0,
  "gates_total": 4,
  "timestamp": "2026-04-17T14:07:50Z"
}
```

`guard-pipeline-lock.sh` laesst Ingest-Worker-Dispatches durch, wenn:
- `stufe == "split-in-progress"` **UND** `tool_input.prompt` enthaelt `[INGEST-ID:<quelle>]` identisch zur Lock-Quelle

So kann ein Split-Ingest Block 2..N ohne `rm` durchlaufen, aber ein *anderer* Ingest wird weiterhin blockiert.

### Signalisierung vom Worker an den Lock

Split-Worker mueste im Abschlussbericht melden, ob es der **letzte** Block ist:

- Block 1..N-1: `[SPLIT-BLOCK:N/M continuing]` → Hook erhaelt `stufe` = `split-in-progress`, inkrementiert `split_block`
- Block M (final): `[SPLIT-BLOCK:M/M final]` → Hook wechselt `stufe` auf `gates`

Alternative: Worker meldet in seinem Output explizit `[INGEST-STATUS:split-continued]` vs. `[INGEST-STATUS:ready-for-gates]`.

### Advance-Counter-Fix

- Audit des `advance-pipeline-lock.sh`: welche Agent-Types sind im Hook-Matcher? Passt das zu den aktuellen Subagent-Type-Namen?
- PASS-Detektor universeller machen: Regex `(?i)gesamt(?:ergebnis|befund|resultat)\s*:?\s*\*\*?\s*pass\*\*?` — matcht verschiedene Schreibweisen
- `jq`-Fehler hart logen statt silent zu fallen lassen
- Nach Stufe = `gates`, gates_passed == gates_total: automatisches Wechseln auf `stufe: sideeffects` (ist theoretisch in SPEC-002 v2.0 vorgesehen, funktioniert aber offenbar nicht)

---

## Workaround bis SPEC-015 gefixt ist

Bei Split-Ingests muss der Orchestrator:

1. Nach jedem Ingest-Worker-Exit manuell `rm wiki/_pending.json` ausfuehren (Option 3 aus `guard-pipeline-lock.sh` ist dafuer dokumentiert).
2. Nach Block M (letzter Block) NICHT loeschen — da ist der Lock korrekt gesetzt.
3. Die 4 Gate-Agents dispatchen; deren PASS/FAIL-Bewertung erfolgt durch Lesen der Abschlussberichte (nicht durch den kaputten Counter).
4. Nach allen 4 Gates PASS: Phase-4-Nebeneffekte ausfuehren, dann `_pending.json` endgueltig loeschen.
5. Den gesamten Ablauf manuell dokumentieren (Quelle, Bloecke, Agent-IDs, Gate-Ergebnisse, Datum) in einem projektseitigen Tracker-Dokument — der Pipeline-Lock-Zustand ist nicht vertrauenswuerdig als Audit-Trail.

---

## Anforderungen

- [ ] `guard-pipeline-lock.sh`: neue Stufe `split-in-progress` verstehen, bei gleicher Quelle Ingest-Worker durchlassen
- [ ] Ingest-Dispatch-Template oder Worker-Protokoll: Block-Index und Total explizit im Prompt und im Abschlussbericht
- [ ] `advance-pipeline-lock.sh`: root-cause-Fix fuer Counter-Stillstand (Audit + Fix)
- [ ] Automatischer Stufen-Uebergang `gates` → `sideeffects` bei `gates_passed == gates_total`
- [ ] Automatische Loeschung von `_pending.json` nach Phase 4 (oder mindestens aktiver Reminder via Hook)
- [ ] Integration-Test: simulierter Split-Ingest mit 3 Bloecken, alle Gates PASS, `_pending.json` sollte am Ende nicht existieren — ohne manuelles `rm`

---

## Akzeptanzkriterien

- [ ] Bei Split-Ingest muessen keine `rm _pending.json`-Kommandos manuell ausgefuehrt werden
- [ ] `gates_passed`-Counter inkrementiert verlaesslich bei jedem PASS-Gate
- [ ] Bei Re-Dispatch eines FAIL-Gates wird der Counter korrekt gefuehrt (kein Doppel-Inkrement)
- [ ] Integration-Test besteht ohne Hand-Eingriff

---

## Edge Cases

- Split-Ingest bei dem Block N mit Worker-Fehler abbricht: wie wird Block N+1 differenziert (abbruch vs. legitime Fortsetzung)?
- Mehrere Split-Ingests in Folge (z. B. beer2015 fertig, danach lissner2016 Block 1): Lock muss zwischen Quellen strikt zuruecksetzen.
- Gate-Re-Dispatch nach FAIL: der bereits einmal PASS-gelieferte Counter darf nicht fallen, wenn ein anderes Gate FAIL liefert.
- `Nebeneffekt`-Stufe: fehlende automatische Einleitung — welches Signal triggert den Wechsel `gates` → `sideeffects`?
