# Changelog — Bibliothek-Plugin

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
- `wiki/_pdfs/neu/` als Eingangsordner — PDFs reinwerfen, "/ingest" oder "neue Quelle" sagen
- Auto-Sortierung nach Ingest: `_pdfs/<kategorie>/` (holzbau, stahlbeton, normen, etc.)
- Obsidian PDF-Links im Frontmatter: `pdf: [[_pdfs/kategorie/datei.pdf]]`
- Trigger-Phrase "neue Quelle im Ordner" scannt automatisch `_pdfs/neu/`

**Neutralisierung:**
- Alle Namensreferenzen (Maximilian/Maxi) durch "Nutzer" ersetzt
- Plugin veroeffentlichungsfaehig

**Statistiken:**
- Befehle: 7 | Skills: 8 | Agents: 7 | Hard Gates: 10
- Output-Checks: 16 (14 aktiv + 2 deferred) | Konsistenz-Checks: 12
- PostToolUse-Hook: 1 (check-wiki-write.sh)
- Governance-Dateien: 9 (inkl. obsidian-setup.md, wiki-claude-md.md)

**Status:** Produktionsbereit | **Aktualisiert:** 2026-04-09
