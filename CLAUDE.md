# LLM-Wiki — Entwickler-Kontext

## Was ist das?

Eigenstaendiges Claude-Code-Plugin das Fachbuecher in ein strukturiertes,
Obsidian-kompatibles Wiki einliest. Arbeitet ausschliesslich in `wiki/`
des Projekts wo es installiert ist. Keine externen Abhaengigkeiten.

## Repo-Struktur

```
llm-wiki/
├── plugin/              ← Plugin-Laufzeit (wird gecacht/verlinkt)
│   ├── .claude-plugin/  ← Plugin-Manifest
│   ├── hooks/           ← Shell-Hooks (Pre/PostToolUse, SessionStart)
│   ├── skills/          ← 8 Skill-Definitionen (SKILL.md)
│   ├── agents/          ← 7 Subagent-Definitionen
│   ├── governance/      ← Hard Gates, Templates, Konventionen
│   └── commands/        ← Slash-Commands
├── docs/                ← Specs, Plans (Dev-only)
├── tests/               ← Hook-Tests (Dev-only)
├── scripts/             ← Dev-Scripts (sync-cache.sh)
├── CLAUDE.md            ← Diese Datei (Dev-Instruktionen)
└── ARCHITECTURE.md      ← Architektur-Doku (Dev-only)
```

**Plugin-Installation:** Claude Code laedt das Plugin direkt aus diesem Repo.
Registrierung in `~/.claude/plugins/installed_plugins.json`:
```
"bibliothek@llm-wiki-local" → installPath: /Users/maximilianstark/Projects/llm-wiki/plugin
```
Kein Cache-Symlink, kein Sync-Script. Aenderungen an `plugin/` greifen nach
Session-Neustart automatisch (Hooks werden im RAM gecacht).

Der Ordner `~/.claude/plugins/cache/llm-wiki-local/.../1.1.0/` ist verwaist
(`.orphaned_at`-Marker) und wird nicht mehr verwendet — Relikt aus der Zeit
vor dem `plugin/`-Subdirectory-Refactor (Commit 4766b13).

## Architektur-Prinzipien

- **Eigenstaendigkeit:** Kennt keine anderen Plugins, schreibt nichts ausserhalb wiki/
- **Token-Last ist gewollt:** 1M Context-Fenster, Qualitaet vor Sparsamkeit
- **Obsidian als Frontend:** Wikilinks, YAML-Frontmatter, Graph View, Dataview
- **Deutsche Rechtschreibung:** Nomen gross in Schlagworten und Wiki-Text.
  Dateinamen lowercase ASCII. Governance-Dateien ASCII (Shell-Kompatibilitaet).

## Enforcement — 3 Schichten

1. **Prompt-Law** — Skill-Anweisungen, Hard Gates, Dispatch-Templates
2. **Subagent-Review** — 4 Pruefer (Ingest) + 2 Reviewer (Synthese) + 1 Validator (parallel, unabhaengig)
3. **Machine-Law (teilweise — nach SPEC-001):**
   - `guard-wiki-writes.sh` (PreToolUse Edit|Write) — blockiert Wiki-Writes ausserhalb von `/ingest`, `/synthese`, `/normenupdate`, `/vokabular` via Transcript-Check
   - `inject-lock-warning.sh` (UserPromptSubmit) — injiziert passive Lock-Warnung als `additionalContext` wenn `wiki/_pending.json` offen ist
   - `check-wiki-output.sh` — wird von den Gate-Agents selbst aufgerufen (seit Commit `f7b08d7`)
   - **Noch ausstehend (SPEC-002):** mechanische Pipeline-Lock-Enforcement via `guard-pipeline-lock.sh` und `advance-pipeline-lock.sh`

Heuristische Checks (04 Zahlenwerte, 05 Normbezuege, 06 Seitenangaben, 09 Umlaute)
sind WARN im Shell-Script. Die echte Pruefung macht der quellen-pruefer Agent (Gate 2).

## Dispatch-Templates

3 Templates in `plugin/governance/` standardisieren Subagent-Prompts:
- `ingest-dispatch-template.md` — 1 Agent = 1 PDF, nie batchen
- `synthese-dispatch-template.md` — Wiki-first, kein Informationsverlust
- `gate-dispatch-template.md` — 4 Gate-Agents mit kontextuellen Checks

**WICHTIG:** Subagent-Prompts werden NICHT frei formuliert. IMMER Templates verwenden.

## Pipeline-Lock

`wiki/_pending.json` blockiert den naechsten Ingest bis Gates + Nebeneffekte fertig:
- `stufe: "gates"` → Gate-Agents muessen laufen
- `stufe: "sideeffects"` → Nebeneffekte muessen abgeschlossen werden
- (Datei geloescht) → naechster Ingest frei

## Entwicklung

Nach jeder Aenderung IMMER:
```bash
bash plugin/hooks/check-consistency.sh plugin/    # 19/19 PASS?
diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' plugin/skills/using-bibliothek/SKILL.md | sed '1d;$d') plugin/governance/hard-gates.md   # Sync?
bash tests/test-guard-wiki-writes.sh               # 5/5 PASS?
bash tests/test-inject-lock-warning.sh             # 7/7 PASS?
bash tests/test-gates-pending-hook.sh              # 12/12 PASS?
```

Session-Neustart noetig nach Hook-Aenderungen (Claude Code cached im RAM).

## Bekannte Patterns

- `set -euo pipefail` in neuen Hooks OK, wenn Exit-Code-basiert (exit 0/2 + stderr) — siehe `guard-wiki-writes.sh`. Nur veraltete JSON-Response-Hooks brauchten den ERR-Trap-Workaround.
- macOS awk hat kein `/i` Flag → `tolower()` verwenden
- `grep -c` gibt Exit 1 bei 0 Matches → `|| VAR=0`
- Inline-Kopie von hard-gates.md in using-bibliothek MUSS synchron bleiben
- Heuristische Checks gehoeren in Agents, nicht in Shell-Regex (keine Endlos-Ausnahmelisten)
- JSON-Parsing in Hooks: `jq -r '.tool_input.file_path // empty'` statt sed-Hacks. `jq` ist auf macOS Standard.
- Hook-Output-Format: Claude Code Hooks API 2026 erwartet `hookSpecificOutput.permissionDecision` bei PreToolUse, NICHT mehr das alte `{"decision":"block"}`. Exit 2 + stderr ist der einfachere Pfad fuer Blockieren (siehe Website_v2 Referenz).
- Plugin-Cache ist Symlink auf plugin/ → kein manuelles Kopieren
