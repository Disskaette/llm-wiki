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

**Cache-Symlink:** `~/.claude/plugins/cache/.../1.1.0 → plugin/`
Aenderungen an plugin/ greifen nach Session-Neustart.

## Architektur-Prinzipien

- **Eigenstaendigkeit:** Kennt keine anderen Plugins, schreibt nichts ausserhalb wiki/
- **Token-Last ist gewollt:** 1M Context-Fenster, Qualitaet vor Sparsamkeit
- **Obsidian als Frontend:** Wikilinks, YAML-Frontmatter, Graph View, Dataview
- **Deutsche Rechtschreibung:** Nomen gross in Schlagworten und Wiki-Text.
  Dateinamen lowercase ASCII. Governance-Dateien ASCII (Shell-Kompatibilitaet).

## Enforcement — 3 Schichten

1. **Prompt-Law** — Skill-Anweisungen, Hard Gates, Dispatch-Templates
2. **Subagent-Review** — 4 Pruefer + 2 Reviewer + 1 Validator (parallel, unabhaengig)
3. **Machine-Law** — PostToolUse-Hook (mechanische Checks) + PreToolUse-Hook (Pipeline-Lock)

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
bash tests/test-wiki-write-hook.sh                 # 14/14 PASS?
bash tests/test-gates-pending-hook.sh              # 12/12 PASS?
```

Session-Neustart noetig nach Hook-Aenderungen (Claude Code cached im RAM).

## Bekannte Patterns

- `set -uo pipefail` NIE in Hooks verwenden → ERR-Trap mit default-allow JSON
- macOS awk hat kein `/i` Flag → `tolower()` verwenden
- `grep -c` gibt Exit 1 bei 0 Matches → `|| VAR=0`
- Inline-Kopie von hard-gates.md in using-bibliothek MUSS synchron bleiben
- Heuristische Checks gehoeren in Agents, nicht in Shell-Regex (keine Endlos-Ausnahmelisten)
- JSON-Parsing in Hooks: escaped Quotes (`\"`) mit DBLQUOTE-Workaround
- Plugin-Cache ist Symlink auf plugin/ → kein manuelles Kopieren
