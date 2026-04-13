# Spec-Index — LLM-Wiki Plugin

Uebersicht aller Feature-Specs. Neue Specs werden hier eingetragen.
Bestehende Specs werden bei neuen Anforderungen aktualisiert, nicht dupliziert.

## Specs

| Nr | Titel | Status | Version | Letzte Aktualisierung |
|----|-------|--------|---------|----------------------|
| [SPEC-001](SPEC-001-passive-hooks.md) | Passive Hook-Infrastruktur (Schreibschutz + Lock-Warnung) | Done | 1.0 | 2026-04-11 |
| [SPEC-002](SPEC-002-pipeline-lock-enforcement.md) | Aktive Pipeline-Lock-Enforcement + Auto-Lock nach Worker-Stop | Done | 2.0 | 2026-04-13 |
| [SPEC-003](SPEC-003-synthese-enforcement.md) | Synthese-Enforcement + Heuristik-Bereinigung | Done | 1.0 | 2026-04-11 |
| [SPEC-004](SPEC-004-wiki-review-skill.md) | Wiki-Review-Skill (semantische Analyse + Verbesserungsplaene) | Done | 1.0 | 2026-04-11 |
| [SPEC-005](SPEC-005-domain-agnostik.md) | Domain-Agnostik — Universelles Wiki-Plugin | Planned | 1.0 | 2026-04-13 |
| [SPEC-006](SPEC-006-multi-format-ingest.md) | Multi-Format-Ingest — PDF, Markdown, URL | Planned | 1.0 | 2026-04-13 |

## Aussenstehende Arbeiten (nicht spec-wuerdig)

- **Gate-Drift-Fix (Bugfix):** `vollstaendigkeits-pruefer` + `ingest-dispatch-template` — siehe Debug-Befund Session 2026-04-10. Reine Text-Korrektur, wird direkt per Commit erledigt, kein Spec.
