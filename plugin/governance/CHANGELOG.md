# Changelog — Bibliothek-Plugin

## [2.0.1] — 2026-04-16

### SPEC-014: Enforcement-Haertung + Quellen-Zuordnung

**Neuer Skill:**
- `/zuordnung` — Quellen-Zuordnungs-Matrix, Schlagwort-Audit, Konzept-Rueckverweise
- `zuordnung-worker` (Opus, 1M) — sieht alle Quellen + alle Konzepte gleichzeitig
- `zuordnung-dispatch-template.md` — 6 Platzhalter, 3 Jobs (Mapping, Audit, Patches)
- `wiki/_quellen-mapping.md` — zentrales Artefakt, Single Source of Truth fuer Synthese

**Neue Hooks:**
- `guard-dispatch-template.sh` (PreToolUse Agent) — blockiert Worker-Dispatches ohne Template-Read
- `guard-mapping-freshness.sh` (PreToolUse Agent) — blockiert Synthese bei veraltetem Mapping

**Shell-Check-Haertung:**
- Check 15: Regex fuer WIDERSPRUCH-Marker erweitert (ISB, CEN/TS, Zilch/Zehetmaier)
- Check 19: Pandoc-Zitat-Syntax `[@key]` auf Konzeptseiten = FAIL
- Check 20: ASCII-Umlaute im Body-Text = FAIL (deterministische Woerterliste)
- Check 21: Dual-Link-Pflicht (PDF-Link ohne Quellenseiten-Link = FAIL)
- `config/umlaut-woerter.txt` — 27 Woerter ohne Homographen-Risiko

**Prompt-Haertung:**
- Context-Budget 1M explizit in allen Dispatch-Templates
- Phase-5-Guard: Nebeneffekte nur wenn stufe=sideeffects
- Gate-Collect-All: Gates sammeln ALLE Maengel, brechen nicht nach erstem FAIL ab
- Manuelles Fixen ist kein Gate-PASS (erfordert Re-Dispatch)
- Konsistenz-Pruefer: globale Link-Suche (nicht nur konzepte/ + quellen/)
- Tabellen-Sonderregel gestrichen: Dual-Link ueberall

**Pipeline-Integration:**
- Synthese Phase 0 liest Mapping statt Schlagwort-Suche
- guard-wiki-writes.sh: +zuordnung in Whitelist
- guard-pipeline-lock.sh: +zuordnung-worker in Worker-Liste

**Tests:**
- 33 neue Shell-Check-Tests (test-check-wiki-output-haertung.sh)
- 10 guard-dispatch-template Tests
- 10 guard-mapping-freshness Tests

**Statistiken:**
- Befehle: 8 | Skills: 11 | Agents: 10 | Hard Gates: 10
- Output-Checks: 21 (19 aktiv + 2 deferred) | Konsistenz-Checks: 22
- Aktive Hooks: 8 | Tests gesamt: 53 neu (+ 276 bestehend = 329)

---

## [2.0.0] — 2026-04-14

### Cache-Drift-Fix + Spec-Bereinigung

**Kritisch:**
- Plugin-Registrierung auf `scope: "user"` vereinheitlicht (kein `scope: "local"` mehr)
- Verwaister Cache unter `~/.claude/plugins/cache/llm-wiki-local/bibliothek/2.0.0/`
  war 22 Dateien hinter dem Repo — Discovery-Logik, Domain-Agnostik, Multi-Format
  fehlten im Runtime. Ursache: local-scope erzeugt Cache-Snapshot ohne Auto-Sync.
- commands/ingest.md + synthese.md Gate-Nummerierung aktualisiert (altes 1-10 Schema → benannte Gates)
- vokabular/SKILL.md: Discovery-Rueckkanal (`_schlagwort-vorschlaege.md`) als Input in Phase 0

**Spec-Bereinigung:**
- CHANGELOG nachgefuehrt (fehlende Eintraege fuer SPEC-002 bis SPEC-006)
- CLAUDE.md Plugin-Installations-Doku aktualisiert (Warnung vor local-scope)

**Statistiken:**
- Befehle: 10 | Skills: 10 | Agents: 9 | Hard Gates: 10
- Output-Checks: 18 (16 aktiv + 2 deferred) | Konsistenz-Checks: 22
- Aktive Hooks: 6 (SessionStart + 2 PreToolUse + 2 SubagentStop + 1 UserPromptSubmit)

---

## 2026-04-14 — SPEC-004: Wiki-Review-Skill

- Neuer Skill `/wiki-review` (semantische Analyse + Discovery-Gesundheit)
- Zweistufig: Quick-Scan (exhaustiv Obsidian-Layer + Stichprobe Content-Layer) → Full-Audit (batchweise)
- Self-Referential: Pflicht-Felder dynamisch aus aktuellen Templates extrahiert
- Discovery-Gesundheit (v1.1): 6 Checks (DATEIEN, STALE, REIFE, RUECKSTAU, KONSISTENZ, GHOST)
- Reports in `wiki/_reviews/review-YYYY-MM-DD.md`
- Neuer Command: `/obsidian-setup` (Vault-Konfiguration aus Governance-Dateien)
- guard-wiki-writes.sh: `/wiki-review` + `/obsidian-setup` als erlaubte Schreib-Skills

---

## 2026-04-13 — SPEC-003 v2.0: Discovery-Logik

- `[DISCOVERY]`-Block als Pflicht-Output im Synthese-Worker (4 Sektionen)
- `{{KONZEPT_REIFE_INHALT}}` + `{{SCHLAGWORT_VORSCHLAEGE_INHALT}}` Platzhalter
- Phase 2e: Worker schreibt `_vokabular.md` (additiv) + patcht Quellenseiten-Schlagworte
- konsistenz-pruefer Part D: Discovery-Vollstaendigkeits-Check (nur bei SYNTHESE-ID)
- check-wiki-output.sh Check 18: Discovery-Dateien-Existenz fuer type:konzept
- check-consistency.sh Check 22: Synthese-Template Discovery-Platzhalter
- Ingest Phase 4: Konzept-Kandidaten → `_konzept-reife.md` (Reife-Berechnung)
- Synthese Phase 0.0: `_konzept-reife.md` als primaere Discovery-Quelle
- Synthese Phase 5: Discovery-Persistierung (Tracking-Metadaten nach Gate-Verifikation)

---

## 2026-04-13 — SPEC-002: Pipeline-Lock-Enforcement

- `guard-pipeline-lock.sh` (PreToolUse Agent): blockiert neue Worker-Dispatches bei offenem Lock
- `advance-pipeline-lock.sh` (SubagentStop auf Gate-Agents): Counter-Inkrement + Stufen-Wechsel
- `create-pipeline-lock.sh` (SubagentStop auf Worker-Agents): Auto-Lock nach Worker-Ende
- INGEST-ID/SYNTHESE-ID Matching: Counter nur bei korrekter Pipeline-Zuordnung
- Gate-FAIL-Detection: Counter wird bei FAIL nicht inkrementiert
- Gegenseitige Blockade: Ingest blockiert Synthese und umgekehrt
- 10/10 + 30/30 + 20/20 Hook-Tests + 164/164 Integration-Tests

---

## 2026-04-13 — SPEC-006: Multi-Format-Ingest

- Format-Erkennung in Phase 0 (PDF/Markdown/URL)
- {{QUELLEN_FORMAT}} und {{QUELLEN_PFAD}} Platzhalter in Dispatch-Template
- Frontmatter: pdf: / quelle-datei: / url: + abgerufen: je nach Format
- 5 Link-Typen (+ Markdown-Beleg, URL-Beleg)
- Gate 1+2 Format-spezifische Pruefstrategien
- check-wiki-output.sh Check 17: Quellpfad-Validierung
- Split-Trigger: PDF >10 MB, Markdown >500 KB

---

## 2026-04-13 — SPEC-005: Domain-Agnostik

- Core/Domain-Split in seitentypen.md (2 Core + N Domain-Typen)
- Bedingte Gates in hard-gates.md (KEIN-NORMBEZUG-OHNE-ABSCHNITT bedingt)
- Dynamische Kategorien via Vokabular-Oberbegriffe (Level-1 = Kategorien)
- Bootstrap nur Core-Verzeichnisse, Domain on-demand (Phase 2g)
- {{DOMAIN_GATES}} Platzhalter in Dispatch-Templates
- Agent-Beispiele domain-agnostisch parametrisiert
- valid-types Sync-Check + domain-gates.txt (Check 20+21)
- _pdfs/ → pdfs/ Vereinheitlichung

---

## [1.0.0] — 2026-04-08

### Erstversion

- **7 Befehle:** /ingest, /katalog, /wiki-lint, /vokabular, /synthese, /normenupdate, /export
- **8 Skills:** ingest, katalog, wiki-lint, vokabular, synthese, normenupdate, export, using-bibliothek
- **7 Agents:** vollstaendigkeits-pruefer, quellen-pruefer, konsistenz-pruefer, vokabular-pruefer, struktur-reviewer, norm-reviewer, duplikat-validator
- **Hard Gates:** 10 inhaltliche Regeln (definiert in governance/hard-gates.md)
  - Typ-Verteilung: 8 × Machine-Law, 2 × Hybrid
- **Output-Checks:** 16 Markdown- und Struktur-Validierungen (check-wiki-output.sh)
  - Abdeckung: Syntax, Metadaten, Links, Zitate, Vokabular, Formatierung
- **Konsistenz-Checks:** 12 Datenintegritäts-Tests (check-consistency.sh)
  - Abdeckung: Deduplikation, Quellentracing, Bidirektionalität, Metadaten-Sync
- **Session-Start-Hook:** using-bibliothek injiziert Governance-Context
- **Kontrolliertes Vokabular:** wiki/_vokabular.md mit Gate-Enforcement
- **Split-Ingest-Protokoll:** Automatische Aufteilung großer Dokumente (>800K Tokens) für mehrstufige Verarbeitung
- **Katalog-Deduplikation:** Hashbasierte Erkennung von Duplikaten in literatur.bib
- **Quellentracing:** Synthese-Texte mit vollständiger Quellenmarkierung und Konflikt-Flaggung
- **Norm-Versionstracking:** Differenz-Berichte zwischen Normenversionen
- **Export-Integration:** BibTeX-Link zu literatur.bib, Pandoc-bereit

### Governance-Architektur

- **4 Schichten:** Session-Hook → Using-Block → Skill-Gate → Subagent-Dispatch
- **Automatische Checks:** Pre-Dispatch und Post-Output validations
- **Fallback-Handling:** Hard Gates stoppen sofort; Hybrid Gates flaggen und fordern Bestätigung
- **Audit-Trail:** Alle Gate-Verstöße werden protokolliert

### Dokumentation

- `ARCHITECTURE.md` — Vollständige Pipeline-, Gate-, und Datenfluss-Dokumentation
- 7 Befehls-Routen in `commands/*.md`
- Governance-Dokumentation in `governance/CHANGELOG.md`

---

**Status:** Produktionsbereit | **Erstellt:** 2026-04-08

---

## [1.0.1] — 2026-04-09

### Code-Review Fixes (Production-Level Audit)

**Kritisch:**
- Plugin in Marketplace registriert (marketplace.json + settings.json)
- Marketplace-Pfad von stale iCloud-Pfad auf lokales Verzeichnis korrigiert
- Wiki-Bootstrap in /ingest Phase 0 integriert (erstellt wiki/ + Unterverzeichnisse)
- Umlaut-Gate (Hard Gate 10) komplett neu geschrieben — war selbstreferenziell
- Korrupte UTF-8 in vokabular/SKILL.md und wiki-lint/SKILL.md repariert

**Dokumentation:**
- ARCHITECTURE.md Agent-Taxonomie an tatsaechliche Agents angepasst (per-Gate statt per-Skill)
- Gate-Count von "7" auf korrekte "10" korrigiert (ARCHITECTURE.md + CHANGELOG.md)
- Split-Threshold vereinheitlicht auf 800K Tokens (war: 1M, 800K, 50KB)
- Wiki-Pfad-Widerspruch aufgeloest (einheitlich: `wiki/` relativ zu Projekt-Root)
- Daten-Flow-Artefakte-Tabelle aktualisiert

**Shell-Scripts:**
- check-wiki-output.sh Check 9 (Umlaute): Systematischer Regex statt 30-Wort-Liste
- check-wiki-output.sh Check 3 (Vokabular): Robusteres YAML-Parsing (inline + list)
- check-wiki-output.sh Check 14 (Wikilinks): O(n) statt O(n×m) Performance
- check-wiki-output.sh Checks 12+13: Als deferred markiert statt stiller PASS
- check-consistency.sh Check 3 (Agent-Count): Robusterer Zaehler
- check-wiki-output.sh Default-Vokabular-Pfad korrigiert

**Skills + Governance:**
- Wiki-Lint Rolle praezisiert (diagnostisch mit optionalem Dispatch)
- Commands mit YAML-Frontmatter versehen
- plugin.json Versionsnummer auf 1.0.1

**Status:** Produktionsbereit | **Aktualisiert:** 2026-04-09

---

## [1.1.0] — 2026-04-09

### Runde 3: Halluzinationsschutz + Obsidian + Mechanische Enforcement

**Kritisch (G-01):**
- PostToolUse Hook implementiert — check-wiki-output.sh wird automatisch nach
  jedem Write/Edit auf wiki/**/*.md ausgefuehrt (check-wiki-write.sh)
- Direct-Write-Verbot in using-bibliothek als NICHT-VERHANDELBAR Block

**Halluzinationsschutz (I-01, I-02, I-03):**
- quellen-pruefer um Part E (Semantische Treue) und Part F (Cross-Source-Kontamination) erweitert
- Spot-Check skaliert jetzt mit Zitationsanzahl (min 5, 10% Coverage)
- Auswahl-Bias: bevorzugt ungewoehnliche Seitenzahlen und Einzelbelege

**Obsidian-Integration (H-02, H-01, H-04, H-05):**
- governance/obsidian-setup.md mit Vault-Config, Dataview-Queries, Index-Templates
- Dateinamen-Eindeutigkeit als NICHT-VERHANDELBAR Regel
- MOC-Pfad in struktur-reviewer korrigiert (MOC-*.md → moc/*.md)
- governance/wiki-claude-md.md Template fuer wiki/CLAUDE.md

**Shell-Scripts (A-01, A-02, I-04):**
- Check 4: Erweiterte Einheitenliste (mm², kN/m, N/mm², dimensionslose Koeffizienten)
- Check 4+6: Pandoc-Citation-Pattern [@key, S. N] erkannt
- Check 15: WIDERSPRUCH-Marker von WARN auf FAIL hochgestuft

**Dokumentation:**
- ARCHITECTURE.md: 12 Konsistenz-Checks korrekt beschrieben (Plugin-intern, nicht Wiki-Daten)
- Synthese Re-Review-Limit auf 3 angeglichen (konsistent mit Ingest)
- Suchstrategien in using-bibliothek dokumentiert

**PDF-Workflow:**
- `wiki/pdfs/neu/` als Eingangsordner — PDFs reinwerfen, "/ingest" oder "neue Quelle" sagen
- Auto-Sortierung nach Ingest: `pdfs/<kategorie>/` (holzbau, stahlbeton, normen, etc.)
- Obsidian PDF-Links im Frontmatter: `pdf: [[pdfs/kategorie/datei.pdf]]`
- Trigger-Phrase "neue Quelle im Ordner" scannt automatisch `pdfs/neu/`

**Neutralisierung:**
- Alle Namensreferenzen (Maximilian/Maxi) durch "Nutzer" ersetzt
- Plugin veroeffentlichungsfaehig

**Statistiken:**
- Befehle: 7 | Skills: 8 | Agents: 7 | Hard Gates: 10
- Output-Checks: 16 (14 aktiv + 2 deferred) | Konsistenz-Checks: 12
- PostToolUse-Hook: 1 (check-wiki-write.sh)
- Governance-Dateien: 9 (inkl. obsidian-setup.md, wiki-claude-md.md)

**Status:** Produktionsbereit | **Aktualisiert:** 2026-04-09

---

## [1.2.0] — 2026-04-11

### Plugin-Struktur-Refactor

- Plugin-Dateien in `plugin/`-Unterverzeichnis verschoben (Commit 4766b13)
- Direkte Plugin-Registrierung auf `plugin/`-Pfad (Commit 99d7eb6, installed_plugins.json)
- Cache-Verzeichnis wird nicht mehr verwendet (verwaist mit .orphaned_at-Marker)
- Plugin liest aus `/Users/maximilianstark/Projects/llm-wiki/plugin` direkt — kein Sync-Script noetig

### Hook-Infrastruktur neu (SPEC-001 — Passive Hooks)

**Kritisch — Machine-Law-Wiederbelebung nach Schema-Incident:**

Die bisherigen Hooks `check-wiki-write.sh` (PostToolUse) und `check-gates-pending.sh` (PreToolUse) nutzten das veraltete JSON-Response-Schema `{"decision":"block"}`, das die Claude Code Hooks API seit der 2026-Umstellung nicht mehr akzeptiert. Jeder Hook-Call produzierte "JSON validation failed", unabhaengig davon ob eine Wiki-Datei tatsaechlich betroffen war. Die Hooks wurden in den Commits 12e8a3c (PostToolUse) und 19e23c7 (PreToolUse) deaktiviert — Machine-Law-Schicht komplett offline, nur Prompt-Law + Subagent-Review aktiv.

SPEC-001 baut zwei Ersatz-Hooks nach dem Website_v2-Referenzpattern (exit-code + stderr, jq fuer stdin-Parsing):

- `plugin/hooks/guard-wiki-writes.sh` (PreToolUse Edit|Write): blockiert Writes auf `wiki/**/*.md` wenn kein Schreib-Skill in der Session geladen ist (Transcript-Grep nach `/ingest`, `/synthese`, `/normenupdate`, `/vokabular`). 5/5 Tests gruen.
- `plugin/hooks/inject-lock-warning.sh` (UserPromptSubmit): passive Warnung als `hookSpecificOutput.additionalContext` wenn `wiki/_pending.json` offen ist. Blockiert nie. 7/7 Tests gruen.
- `plugin/hooks/check-wiki-write.sh` geloescht (Commit f58055c)
- `tests/test-wiki-write-hook.sh` geloescht

### Gate-Drift-Reparatur (Bugfix aus Debug-Session 2026-04-10)

- `vollstaendigkeits-pruefer` Part C/D umgeschrieben:
  - Alte Pruefung: `relevanz: high` im Frontmatter + YAML-Feld `zusammenfassung:`
  - Echtes Ingest-Template-Schema: `relevanz: hoch|mittel|niedrig` im `kapitel-index:`-Array + Body-Section `## Kapitel [Nr]: [Titel]`
  - Folge: False-FAIL bei Blass-Uibel Gate 1 — der Agent meldete FAIL obwohl der Ingest korrekt war
- `ingest-dispatch-template.md` um explizite Pflicht-Regel ergaenzt: `schlagworte:` muss mindestens 3 Eintraege enthalten (war nur im Pruefer-Agent verankert, Template zeigte es nur als Beispiel-Wert)
  - Folge: PRB 4.14 Gate 1 FAIL weil Ingest nur 2 Schlagworte generiert hatte
- FAIL-Kriterien in `vollstaendigkeits-pruefer` auf die korrekten Feldnamen angepasst

### Modellwahl im Ingest

- >200 Seiten → `model: "opus"` (1M Context noetig)
- ≤200 Seiten → `model: "sonnet"` (guenstig, reicht)
- Hauptagent setzt beim Dispatch `model:`-Parameter entsprechend (Commit 5f7757f)

### Statistiken

- Befehle: 7 | Skills: 8 | Agents: 7 | Hard Gates: 10
- Output-Checks: 16 (14 aktiv + 2 deferred) | Konsistenz-Checks: 19
- Aktive Hooks: 3 (SessionStart + PreToolUse Edit|Write + UserPromptSubmit)
- Geplante Hooks: +2 (SPEC-002: guard-pipeline-lock.sh + advance-pipeline-lock.sh)

### SPECs

- `docs/specs/SPEC-001-passive-hooks.md` — Passive Hooks (Done nach Session-Restart + E2E-Tests)
- `docs/specs/SPEC-002-pipeline-lock-enforcement.md` — Aktive Pipeline-Lock-Enforcement (Planned, baut auf SPEC-001)

**Status:** Produktionsbereit | **Aktualisiert:** 2026-04-11
