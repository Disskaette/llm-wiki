# SPEC-003: Synthese-Enforcement + Heuristik-Bereinigung

**Status:** Done
**Version:** 1.0
**Erstellt:** 2026-04-11
**Aktualisiert:** 2026-04-11

## Zusammenfassung

Synthese-Pipeline bekommt dieselbe Machine-Law-Infrastruktur wie Ingest:
Pipeline-Lock, Gate-Counter, Cross-Block, Lock-Warnung. Zusätzlich wird
INGEST-ID/SYNTHESE-ID Matching eingeführt und heuristische Shell-Checks
entfernt.

## Anforderungen

1. Synthese-Worker Agent-Type für Hook-Matching
2. guard-pipeline-lock.sh blockiert sowohl Ingest- als auch Synthese-Worker
3. Gegenseitige Blockade (Ingest blockiert Synthese und umgekehrt)
4. advance-pipeline-lock.sh mit ID-Matching gegen _pending.json.quelle
5. inject-lock-warning.sh zeigt Typ, Gates-Zähler
6. gate-dispatch-template.md mit PIPELINE_ID_MARKER
7. Heuristische Checks (04, 05, 06, 09) aus check-wiki-output.sh entfernt

## Technische Details

### Neue Dateien
- `plugin/agents/synthese-worker.md` — Subagent-Type für Hook-Matching
- `plugin/hooks/config/valid-types.txt` — Ausgelagerte Typen-Whitelist

### Geänderte Hooks
- `guard-pipeline-lock.sh` — case-Matching auf ingest-worker|synthese-worker, Typ in Fehlermeldung
- `advance-pipeline-lock.sh` — stdin lesen, INGEST-ID/SYNTHESE-ID aus last_assistant_message extrahieren, bei Mismatch Counter nicht inkrementieren
- `inject-lock-warning.sh` — Typ + Gates-Zähler in additionalContext
- `check-wiki-output.sh` — 16→12 Checks (heuristische entfernt), Config-Dir, Single-Quote-Fix, Duplikat-Substring-Fix

### Geänderte Templates/Skills
- `gate-dispatch-template.md` — {{PIPELINE_ID_MARKER}} in allen 4 Gate-Prompts
- `synthese-dispatch-template.md` — [SYNTHESE-ID:{{KONZEPT_NAME}}]
- `synthese/SKILL.md` — subagent_type in Phase 0.6, Pipeline-Lock in Phase 3, Lock-Cleanup in Phase 5

## Akzeptanzkriterien

- [x] synthese-worker blockiert bei offenem Ingest-Lock
- [x] ingest-worker blockiert bei offenem Synthese-Lock
- [x] Synthese gates_total=3 → sideeffects nach 3 Gate-Stops
- [x] INGEST-ID Match → Counter steigt
- [x] INGEST-ID Mismatch → Counter bleibt
- [x] Kein ID-Marker → Counter steigt (Rückwärtskompatibilität)
- [x] Heuristische Checks entfernt, 12 deterministische bleiben
- [x] Unit-Tests: 10/10 + 16/16 + 7/7 + 6/6
- [x] Integration-Test: 137/137
- [x] Konsistenz: 19/19
