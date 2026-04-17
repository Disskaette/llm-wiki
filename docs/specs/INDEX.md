# Spec-Index — LLM-Wiki Plugin

Uebersicht aller Feature-Specs. Neue Specs werden hier eingetragen.
Bestehende Specs werden bei neuen Anforderungen aktualisiert, nicht dupliziert.

## Specs

| Nr | Titel | Status | Version | Letzte Aktualisierung |
|----|-------|--------|---------|----------------------|
| [SPEC-001](SPEC-001-passive-hooks.md) | Passive Hook-Infrastruktur (Schreibschutz + Lock-Warnung) | Done | 1.0 | 2026-04-11 |
| [SPEC-002](SPEC-002-pipeline-lock-enforcement.md) | Aktive Pipeline-Lock-Enforcement + Auto-Lock nach Worker-Stop | Done | 2.0 | 2026-04-13 |
| [SPEC-003](SPEC-003-synthese-enforcement.md) | Synthese-Enforcement + Discovery-Logik | Done (v2.0 verifiziert) | 2.0 | 2026-04-14 |
| [SPEC-004](SPEC-004-wiki-review-skill.md) | Wiki-Review-Skill (semantische Analyse + Discovery-Gesundheit) | Done | 1.2 | 2026-04-15 |
| [SPEC-005](SPEC-005-domain-agnostik.md) | Domain-Agnostik — Universelles Wiki-Plugin | Done | 1.0 | 2026-04-13 |
| [SPEC-006](SPEC-006-multi-format-ingest.md) | Multi-Format-Ingest — PDF, Markdown, URL | Done | 1.0 | 2026-04-13 |
| [SPEC-007](SPEC-007-future-scaling.md) | Future — Skalierung, Lifecycle, Visualisierung | Backlog | 1.0 | 2026-04-13 |
| [SPEC-008](SPEC-008-ingest-pipeline.md) | Ingest-Pipeline (Phasen, Dispatch, Gates, Split, Batch) | Done | 1.2 | 2026-04-17 |
| [SPEC-009](SPEC-009-synthese-pipeline.md) | Synthese-Pipeline (Phasen, Dispatch, Discovery, Split, Batch) | Done | 1.3 | 2026-04-17 |
| [SPEC-010](SPEC-010-wiki-lint.md) | Wiki-Lint (8 Checks, Link-Graph, Spot-Checks) | Done | 1.0 | 2026-04-14 |
| [SPEC-011](SPEC-011-vokabular.md) | Vokabular (Term-Lifecycle, Hierarchie, Discovery-Rueckkanal) | Done | 1.0 | 2026-04-14 |
| [SPEC-012](SPEC-012-normenupdate.md) | Normenupdate (Editions-Wechsel, Multi-File-Propagation) | Done | 1.1 | 2026-04-17 |
| [SPEC-013](SPEC-013-wiki-bridge.md) | Wiki-Bridge — Unidirektionale Integration Wiki → Wissenschafts-Plugin | Done | 1.0 | 2026-04-15 |
| [SPEC-014](SPEC-014-zuordnung-und-haertung.md) | Quellen-Zuordnung + Enforcement-Haertung | Planned | 1.0 | 2026-04-16 |
| [SPEC-015](SPEC-015-split-ingest-lock-fix.md) | Split-Ingest Pipeline-Lock-Fix + Advance-Counter-Bug | Planned | 1.0 | 2026-04-17 |

## Aussenstehende Arbeiten (nicht spec-wuerdig)

- **Gate-Drift-Fix (Bugfix):** `vollstaendigkeits-pruefer` + `ingest-dispatch-template` — siehe Debug-Befund Session 2026-04-10. Reine Text-Korrektur, wird direkt per Commit erledigt, kein Spec.
- **Ingest-Schlagwort-Luecke (Bugfix):** Ingest vergibt unvollstaendige Schlagwoerter — Quellen mit "Finite Element" im Titel bekamen kein Schlagwort "Finite-Elemente-Methode" (betraf oudjene2013, oudjene2018, polus2019, du2022, winter2021, holschemacher2021, sieder2025_bbsr). Ursache: Ingest-Worker leitet Schlagwoerter aus Inhalt ab, prueft aber nicht systematisch Titel-Keywords gegen das kontrollierte Vokabular. Fix: Ingest-Dispatch-Template oder Ingest-Skill um Titel-Keyword-Matching gegen _vokabular.md ergaenzen. Befund 2026-04-15.
