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
│   ├── agents/          ← 8 Subagent-Definitionen
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
3. **Machine-Law:**
   - `guard-wiki-writes.sh` (PreToolUse Edit|Write) — blockiert Wiki-Writes ausserhalb von `/ingest`, `/synthese`, `/normenupdate`, `/vokabular` via zwei-stufigem Transcript-Check (Skill-Tool-Call, nicht blankes Wort)
   - `guard-pipeline-lock.sh` (PreToolUse Agent) — blockiert neue `bibliothek:ingest-worker`- und `bibliothek:synthese-worker`-Dispatches solange `wiki/_pending.json` offen ist (gegenseitige Blockade)
   - `advance-pipeline-lock.sh` (SubagentStop auf Gate-Agents) — inkrementiert `gates_passed`-Counter, wechselt Stufe auf `sideeffects` nach gates_total Gates. Verifiziert INGEST-ID/SYNTHESE-ID gegen `_pending.json.quelle` (bei Mismatch: Counter nicht inkrementieren). Bei Gate-FAIL (`Ergebnis:.*FAIL` im Output): Counter wird NICHT inkrementiert — erzwingt Re-Gate-Dispatch nach Korrektur maschinell.
   - `create-pipeline-lock.sh` (SubagentStop auf Worker-Agents) — erzeugt `wiki/_pending.json` automatisch nach Ingest-/Synthese-Worker-Ende. Extrahiert quelle aus `[INGEST-ID:xxx]` / `[SYNTHESE-ID:xxx]` im Worker-Output. Ueberschreibt bestehende Locks nicht.
   - `inject-lock-warning.sh` (UserPromptSubmit) — injiziert passive Lock-Warnung mit Typ, Quelle, Stufe und Gates-Zaehler als `additionalContext`
   - `check-wiki-output.sh` — wird von den Gate-Agents selbst aufgerufen (seit Commit `f7b08d7`)

Heuristische Checks (Zahlenwerte, Normbezuege, Seitenangaben, Umlaute) wurden
aus `check-wiki-output.sh` entfernt — sie brauchen Kontext den Shell nicht liefern
kann. Die Gate-Agents (quellen-pruefer, konsistenz-pruefer) pruefen kontextuell.

## Dispatch-Templates

3 Templates in `plugin/governance/` standardisieren Subagent-Prompts:
- `ingest-dispatch-template.md` — 1 Agent = 1 PDF, nie batchen
- `synthese-dispatch-template.md` — Wiki-first, kein Informationsverlust
- `gate-dispatch-template.md` — 4 Gate-Agents mit kontextuellen Checks

**WICHTIG:** Subagent-Prompts werden NICHT frei formuliert. IMMER Templates verwenden.

## Pipeline-Lock

`wiki/_pending.json` blockiert den naechsten Ingest/Synthese **mechanisch** (via `guard-pipeline-lock.sh`):
- `stufe: "gates"` → Gate-Agents muessen laufen, `advance-pipeline-lock.sh` zaehlt mit
- `stufe: "sideeffects"` → Nebeneffekte muessen abgeschlossen werden
- (Datei geloescht) → naechste Pipeline frei

Ingest und Synthese blockieren sich gegenseitig (nur ein `_pending.json`).

Format:
```json
{"typ":"ingest|synthese","stufe":"gates","quelle":"<kurzname>","timestamp":"<ISO>","gates_passed":0,"gates_total":4|3}
```

Ingest: `gates_total: 4` (vollstaendigkeits-, quellen-, konsistenz-, vokabular-pruefer).
Synthese: `gates_total: 3` (quellen-, konsistenz-, vokabular-pruefer).

`_pending.json` wird automatisch durch `create-pipeline-lock.sh` (SubagentStop-Hook)
nach Worker-Rueckkehr angelegt. Phase 3 verifiziert die Datei und dispatcht die Gates.
In der Nebeneffekte-Phase (nach allen Seiteneffekten) wird die Datei geloescht.

## Entwicklung

Nach jeder Aenderung IMMER:
```bash
bash plugin/hooks/check-consistency.sh plugin/    # 21/21 PASS?
diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' plugin/skills/using-bibliothek/SKILL.md | sed '1d;$d') plugin/governance/hard-gates.md   # Sync?
bash tests/test-guard-wiki-writes.sh               # 6/6 PASS?
bash tests/test-inject-lock-warning.sh             # 7/7 PASS?
bash tests/test-guard-pipeline-lock.sh             # 10/10 PASS?
bash tests/test-advance-pipeline-lock.sh           # 20/20 PASS?
bash tests/test-create-pipeline-lock.sh            # 30/30 PASS?
bash tests/test-integration-pipeline.sh            # 137/137 PASS?
```

Session-Neustart noetig nach Hook-Aenderungen (Claude Code cached im RAM).

**Orphaned Tests (nicht Teil der Pflicht-Checkliste):**
`tests/test-gates-pending-hook.sh` testet `plugin/hooks/check-gates-pending.sh`,
der in `hooks.json` nicht registriert ist. Beide Dateien sind Relikte aus der
SPEC-002-Vorarbeit — `guard-pipeline-lock.sh` und `advance-pipeline-lock.sh`
haben diese Funktionalitaet uebernommen.

## Troubleshooting

### "PIPELINE-LOCK: Neuer Ingest blockiert" aber vorheriger wurde abgebrochen

```bash
rm wiki/_pending.json
```

Nur wenn der vorige Ingest nachweislich nicht fortgefuehrt wird.
Ueberpruefe `_log.md` auf offene `[INGEST UNVOLLSTAENDIG]` Marker.

### SubagentStop feuert nicht, Counter bleibt auf 0

Pruefe:
1. Claude Code Version (SubagentStop wurde spaet 2025 eingefuehrt)
2. Matcher in hooks.json — mit `bash tests/test-advance-pipeline-lock.sh` verifizieren
3. Hook-Script ist ausfuehrbar: `ls -la plugin/hooks/advance-pipeline-lock.sh`

### Worker-Stop erzeugt _pending.json nicht (Hook-Fehler)

Pruefe:
1. hooks.json hat SubagentStop-Matcher fuer `bibliothek:(ingest|synthese)-worker`
2. `create-pipeline-lock.sh` ist ausfuehrbar: `ls -la plugin/hooks/create-pipeline-lock.sh`
3. `wiki/` Verzeichnis existiert (Bootstrap gelaufen?)
4. Manuell anlegen: `echo '{"typ":"ingest","stufe":"gates","quelle":"...","timestamp":"...","gates_passed":0,"gates_total":4}' > wiki/_pending.json`

### Manueller Gate-Dispatch waehrend aktivem Ingest/Synthese

NICHT empfohlen — obwohl `advance-pipeline-lock.sh` seit SPEC-003 INGEST-ID/SYNTHESE-ID
aus `last_assistant_message` verifiziert (Mismatch → Counter nicht inkrementiert),
ist manueller Gate-Dispatch ein Sonderfall der nicht getestet ist.

## Bekannte Patterns

- `set -euo pipefail` in neuen Hooks OK, wenn Exit-Code-basiert (exit 0/2 + stderr) — siehe `guard-wiki-writes.sh`. Nur veraltete JSON-Response-Hooks brauchten den ERR-Trap-Workaround.
- macOS awk hat kein `/i` Flag → `tolower()` verwenden
- `grep -c` gibt Exit 1 bei 0 Matches → `|| VAR=0`
- Inline-Kopie von hard-gates.md in using-bibliothek MUSS synchron bleiben
- Heuristische Checks gehoeren in Agents, nicht in Shell-Regex (keine Endlos-Ausnahmelisten)
- JSON-Parsing in Hooks: `jq -r '.tool_input.file_path // empty'` statt sed-Hacks. `jq` ist auf macOS Standard.
- Hook-Output-Format: Claude Code Hooks API 2026 erwartet `hookSpecificOutput.permissionDecision` bei PreToolUse, NICHT mehr das alte `{"decision":"block"}`. Exit 2 + stderr ist der einfachere Pfad fuer Blockieren (siehe Website_v2 Referenz).
- Plugin-Cache ist Symlink auf plugin/ → kein manuelles Kopieren
