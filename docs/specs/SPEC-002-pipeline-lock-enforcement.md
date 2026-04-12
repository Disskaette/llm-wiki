# SPEC-002: Aktive Pipeline-Lock-Enforcement + Subagent-Type-Refactor

**Status:** In Progress
**Version:** 2.0
**Erstellt:** 2026-04-10
**Aktualisiert:** 2026-04-13

> **Fuer agentische Worker:** REQUIRED SUB-SKILL — `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`. Task-Steps verwenden `- [ ]` Checkbox-Syntax.

**Ziel:** Den versprochenen "Pipeline-Lock" aus CLAUDE.md mechanisch durchsetzen — neue Ingest-Dispatches werden blockiert solange `wiki/_pending.json` offen ist, und der Lock-Zustand wird automatisch durch `SubagentStop`-Hooks auf die Gate-Agents weitergeschaltet.

**Architektur:** (a) Dedizierter Subagent-Type `bibliothek:ingest-worker` damit der `PreToolUse`-Hook Ingest-Dispatches eindeutig von anderen Agent-Calls unterscheiden kann. (b) `PreToolUse`-Hook auf `Agent`-Tool, der `_pending.json` prueft. (c) `SubagentStop`-Hook auf die vier Gate-Agents, der den Lock-Counter inkrementiert und die Stufe wechselt.

**Tech Stack:** Bash (`set -euo pipefail`), `jq`, Claude Code Hooks API 2026 (`SubagentStop`-Event mit Agent-Type-Matcher).

**Voraussetzung:** SPEC-001 ist Done. Ohne `guard-wiki-writes.sh` und saubere `hooks.json`-Struktur macht dieser Spec keinen Sinn.

---

## Zusammenfassung

CLAUDE.md behauptet seit Version 1.0 dass `wiki/_pending.json` den naechsten Ingest mechanisch blockiert:

> Pipeline-Lock: `wiki/_pending.json` blockiert den naechsten Ingest bis Gates + Nebeneffekte fertig.

Das war nie wahr. Der Lock-Check war in `check-wiki-write.sh` versteckt, der auf PostToolUse registriert war und eh nicht blocken konnte. In der Session 2026-04-10 ist das aufgeflogen: der Main-Agent wollte 5 Ingests in Folge starten ohne Gates dazwischen laufen zu lassen, und **nur die manuelle Intervention des Users** hat die Reihenfolge gerettet.

Dieser Spec baut den mechanischen Lock wirklich:
1. Ingest-Dispatches bekommen einen eindeutigen `subagent_type`, damit der Hook sie identifizieren kann
2. Vor jedem Ingest-Dispatch prueft ein PreToolUse-Hook `_pending.json`
3. Nach jedem Gate-Agent (SubagentStop) wird der Lock-Counter aktualisiert
4. Wenn alle 4 Gates einer Quelle durch sind, wechselt die Lock-Stufe auf `sideeffects`
5. Wenn der Nebeneffekt-Abschluss erkannt wird (naechster `/ingest`-Start oder expliziter Ingest-Phase-4-Abschluss), wird die Datei geloescht

Hook D aus SPEC-001 (passive UserPromptSubmit-Warnung) bleibt unveraendert — sie liest denselben `_pending.json` und zeigt dem User den aktuellen Stand an.

### v2.0: Auto-Pipeline-Lock (2026-04-13)

In Session 2026-04-13 hat der Orchestrator nach einem Ingest-Worker-Return Phase 3
(Gate-Dispatch) uebersprungen und direkt zum naechsten Ingest gewollt. Die Machine-Law
hat nicht gegriffen weil `_pending.json` nie angelegt wurde — die gesamte Enforcement-Kette
haengt an einer Datei die der LLM-Orchestrator erstellen soll.

**Fix:** Neuer Hook `create-pipeline-lock.sh` auf SubagentStop fuer Worker-Agents.
Erzeugt `_pending.json` mechanisch nach Worker-Ende. Damit blockiert `guard-pipeline-lock.sh`
den naechsten Dispatch auch wenn der Orchestrator Phase 3 ueberspringt.

## Anforderungen

1. **Neuer Agent `bibliothek:ingest-worker`** als Dispatch-Ziel fuer alle Ingest-Arbeiten. Bestehende Ingest-Prompts laufen weiter wie bisher, nur der Dispatch-Pfad aendert sich.

2. **`ingest-dispatch-template.md` + `ingest/SKILL.md`** setzen beim Agent-Call explizit `subagent_type: "bibliothek:ingest-worker"`.

3. **Hook B — `guard-pipeline-lock.sh`** (PreToolUse, Matcher: `Agent`):
   - Allow wenn `subagent_type` nicht `bibliothek:ingest-worker`
   - Deny wenn `wiki/_pending.json` existiert
   - Allow sonst

4. **Hook C — `advance-pipeline-lock.sh`** (SubagentStop, Matcher: `bibliothek:(vollstaendigkeits|quellen|konsistenz|vokabular)-pruefer`):
   - Liest aktuellen `_pending.json`
   - Inkrementiert `gates_passed`-Counter um 1
   - Wenn `gates_passed >= gates_total` (4): setzt `stufe` auf `sideeffects`
   - Blockiert nie

5. **`_pending.json`-Format erweitert:**
   ```json
   {
     "typ": "ingest",
     "stufe": "gates",
     "quelle": "fingerloos-ec2-2016",
     "timestamp": "2026-04-10T12:00:00Z",
     "gates_passed": 0,
     "gates_total": 4
   }
   ```
   Schema-Aenderung ist rueckwaertskompatibel: alte Eintraege ohne `gates_passed` werden beim ersten SubagentStop repariert.

6. **Nebeneffekt-Abschluss entfernt den Lock.** Die Ingest-Skill Phase 4 schreibt nach Abschluss aller Pflicht-Nebeneffekte `rm -f wiki/_pending.json` als letzten Schritt. Bleibt manuell im Skill, kein zusaetzlicher Hook.

7. **Tests fuer Hook B und Hook C** in `tests/`.

8. **CLAUDE.md** beschreibt nach SPEC-002 die vollstaendige 3-Schichten-Enforcement ehrlich, ohne Einschraenkung.

## Technische Details

### Agent `bibliothek:ingest-worker`

**Pfad:** `plugin/agents/ingest-worker.md`

Neuer Agent, dessen einzige Aufgabe der Ingest-Prozess aus dem `ingest-dispatch-template` ist. Der Agent-Prompt ist minimal — der eigentliche Arbeits-Prompt kommt vom Template ueber den `prompt`-Parameter beim Dispatch. Der Agent existiert **nur** damit ein eindeutiger `subagent_type` beim Dispatch gesetzt werden kann, auf den der Pre-Hook matchen kann.

```markdown
---
name: ingest-worker
description: "Fuehrt einen einzelnen Ingest-Auftrag aus dem ingest-dispatch-template aus. Wird vom /ingest Skill dispatcht."
tools: Read, Write, Edit, Grep, Glob, Bash
---

# Ingest-Worker

Du bist der Ingest-Worker des Bibliothek-Plugins.

Dein Auftrag wird dir als Dispatch-Prompt uebergeben — er folgt dem Ingest-Dispatch-Template
(`plugin/governance/ingest-dispatch-template.md`). Halte dich strikt an das Template.

Du bist NICHT frei in der Ausgestaltung — das Template ist verbindlich.
```

**Namespace:** Claude Code praefixt Plugin-Agents automatisch mit dem Plugin-Namen. Der vollstaendige Subagent-Type wird also `bibliothek:ingest-worker` (Plugin heisst laut `plugin.json` bereits `bibliothek`).

### `ingest-dispatch-template.md` — Dispatch-Anweisung ergaenzt

Im Abschnitt "Prompt-Template (ab hier wird an den Subagent uebergeben)" bleibt alles unveraendert. Was sich aendert ist das **Dispatch-Verfahren** das in `ingest/SKILL.md` Phase 0.6 dokumentiert ist:

Vorher (aktuell):
```
4. Dispatche Agent mit ausgefuelltem Template als Prompt + gewaehltem Modell
```

Nachher:
```
4. Dispatche Agent mit:
   - subagent_type: "bibliothek:ingest-worker"   (PFLICHT — PreToolUse-Hook matcht auf diesen Wert)
   - prompt: ausgefuelltes Template
   - model: "opus" oder "sonnet" nach Seitenzahl
   - description: "Ingest: <Quellen-Kurzname>"
```

### Hook B — guard-pipeline-lock.sh

**Pfad:** `plugin/hooks/guard-pipeline-lock.sh`

**Input (stdin JSON):**
```json
{
  "session_id": "...",
  "transcript_path": "...",
  "cwd": "/Users/maximilianstark/Projects/llm-wiki",
  "hook_event_name": "PreToolUse",
  "tool_name": "Agent",
  "tool_input": {
    "subagent_type": "bibliothek:ingest-worker",
    "description": "Ingest: fingerloos-ec2-2016",
    "prompt": "Du bist ein Ingest-Subagent ...",
    "model": "opus"
  }
}
```

**Entscheidungslogik:**
```
SUBAGENT_TYPE = jq .tool_input.subagent_type
IF nicht "bibliothek:ingest-worker":
    exit 0 (nicht unser Fall)

PENDING = ${CLAUDE_PROJECT_DIR}/wiki/_pending.json
IF PENDING existiert:
    QUELLE = jq .quelle PENDING
    STUFE = jq .stufe PENDING
    stderr: "Pipeline-Lock offen: Quelle=$QUELLE, Stufe=$STUFE. ..."
    exit 2

exit 0
```

### Hook C — advance-pipeline-lock.sh

**Pfad:** `plugin/hooks/advance-pipeline-lock.sh`

**Input (stdin JSON):**
```json
{
  "session_id": "...",
  "transcript_path": "...",
  "cwd": "/Users/maximilianstark/Projects/llm-wiki",
  "hook_event_name": "SubagentStop",
  "agent_id": "agent-abc123",
  "agent_type": "bibliothek:vollstaendigkeits-pruefer",
  "stop_hook_active": false,
  "agent_transcript_path": "/.../subagents/....jsonl",
  "last_assistant_message": "...Gesamtergebnis: PASS..."
}
```

**Entscheidungslogik:**
```
PENDING = ${CLAUDE_PROJECT_DIR}/wiki/_pending.json
IF PENDING existiert nicht:
    exit 0 (kein aktiver Lock)

STUFE = jq .stufe PENDING
IF STUFE != "gates":
    exit 0 (Lock ist schon weiter)

GATES_PASSED = jq '.gates_passed // 0' PENDING
GATES_TOTAL = jq '.gates_total // 4' PENDING
NEW_PASSED = GATES_PASSED + 1

jq --argjson n $NEW_PASSED '.gates_passed = $n' PENDING > PENDING.tmp

IF NEW_PASSED >= GATES_TOTAL:
    jq '.stufe = "sideeffects"' PENDING.tmp > PENDING.tmp2
    mv PENDING.tmp2 PENDING
ELSE:
    mv PENDING.tmp PENDING

exit 0
```

**Wichtig:** Kein Re-Matching auf `last_assistant_message` fuer PASS/FAIL. Der Hook **zaehlt nur** — ein FAIL-Gate wird auch als "durchgelaufen" gezaehlt, weil der Re-Review-Mechanismus des Gate-Systems (max 3 Iterationen) im Skill liegt, nicht im Hook. Wenn ein Gate FAIL meldet und der Main-Agent es neu dispatcht, wird Hook C zweimal feuern und der Counter sprengt das Limit — das ist **bewusst:** der Hook ist kein Qualitaets-Gate, er ist ein Reihenfolge-Gate.

**Edge-Case Counter-Ueberlauf:** Wenn Hook C bei `gates_passed >= gates_total` nochmal feuert (z.B. weil ein Re-Review laeuft), wird die Stufe schon `sideeffects` sein → Hook steigt frueh aus. Der Counter laeuft zwar ueber, stoert aber nichts.

### Format-Migration `_pending.json`

Bestehende Eintraege haben moeglicherweise nur `{typ, stufe, quelle, timestamp}`. Hook C faellt bei `.gates_passed // 0` auf Default 0 zurueck — automatische Migration. Keine separate Migrations-Task noetig.

**`guard-wiki-writes.sh` aus SPEC-001 muss nicht geaendert werden** — er liest `_pending.json` nicht, sondern prueft nur Transcript-Skill-Marker.

**`inject-lock-warning.sh` aus SPEC-001 liest `.quelle` und `.stufe`** — beide Felder bleiben im neuen Format erhalten. Keine Aenderung noetig, aber man koennte optional `.gates_passed/.gates_total` in die Lock-Warnung einbauen (nicht erforderlich, optional in Task 7).

### hooks.json nach SPEC-002

```json
{
  "hooks": {
    "SessionStart": [ ... wie SPEC-001 ... ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/guard-wiki-writes.sh\"",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/guard-pipeline-lock.sh\"",
            "timeout": 5
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "bibliothek:(vollstaendigkeits|quellen|konsistenz|vokabular)-pruefer",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/advance-pipeline-lock.sh\"",
            "timeout": 10
          }
        ]
      }
    ],
    "UserPromptSubmit": [ ... wie SPEC-001 ... ]
  }
}
```

## Akzeptanzkriterien

- [ ] `plugin/agents/ingest-worker.md` existiert und ist als `bibliothek:ingest-worker` ansprechbar
- [ ] `plugin/skills/ingest/SKILL.md` Phase 0.6 beschreibt Dispatch mit `subagent_type: "bibliothek:ingest-worker"`
- [ ] `plugin/hooks/guard-pipeline-lock.sh` existiert, `jq`-basiert, `set -euo pipefail`
- [ ] `plugin/hooks/advance-pipeline-lock.sh` existiert, `jq`-basiert, `set -euo pipefail`
- [ ] `plugin/hooks/hooks.json` registriert beide neuen Hooks
- [ ] `tests/test-guard-pipeline-lock.sh`: alle Cases gruen
- [ ] `tests/test-advance-pipeline-lock.sh`: alle Cases gruen
- [ ] Integration-Test in frischer Session: Ingest-Start → `_pending.json` entsteht (durch Ingest-Skill Phase 0.4 oder Nebeneffekt), zweiter Ingest-Dispatch wird blockiert
- [ ] Nach Gate-Abschluss: `_pending.json` hat `gates_passed: 4, stufe: sideeffects`
- [ ] Nach Phase 4 des Ingest-Skills: `_pending.json` ist geloescht, neuer Ingest geht
- [ ] CLAUDE.md reflektiert die vollstaendige 3-Schichten-Enforcement
- [ ] `plugin/hooks/create-pipeline-lock.sh` existiert, `jq`-basiert, `set -euo pipefail`
- [ ] hooks.json: SubagentStop-Matcher fuer `bibliothek:(ingest|synthese)-worker` registriert
- [ ] `ingest-dispatch-template.md` enthaelt `[INGEST-ID:...]` im Prompt
- [ ] `tests/test-create-pipeline-lock.sh`: alle Cases gruen
- [ ] Integration-Test: Worker-Stop → `_pending.json` entsteht automatisch → zweiter Dispatch blockiert
- [ ] SKILL.md Phase 3 Step 1: "verify" statt "create"

## Edge Cases

- **Parallele Ingests durch expliziten User-Wunsch:** Bisher hat der Skill `/ingest` in der Batch-Modus-Sektion geschrieben "KEIN paralleles Dispatchen — ausser der Nutzer fordert es explizit". Mit Hook B wuerde das nicht mehr funktionieren — jeder zweite parallele Ingest wird blockiert. Das ist beabsichtigt: der Lock ist **hart**. Wenn der User wirklich parallel will, muss er `_pending.json` haendisch loeschen oder den Ingest-Skill um einen `--force`-Flag erweitern (nicht in diesem Spec).
- **Gate-FAIL triggert Re-Review:** Wenn ein Gate FAIL meldet und der Main-Agent das Gate erneut dispatcht, feuert Hook C zweimal fuer dasselbe Gate. Counter laeuft ueber Target, aber weil Hook C bei `stufe != "gates"` frueh aussteigt sobald die Stufe auf `sideeffects` wechselt, ist das harmlos. Dokumentiert im Tech-Details-Abschnitt.
- **Hook C feuert auf einen Gate-Agent der NICHT zum aktuellen Ingest gehoert:** Szenario: User dispatcht manuell einen Gate-Agent (z.B. fuer Debug) waehrend ein Ingest laeuft. Hook C sieht `_pending.json` mit `stufe: gates`, inkrementiert den Counter — falsch. Mitigation: Hook C koennte die Quellen-ID aus dem Gate-Output pruefen und nur matchen. Fuer v1.0 akzeptieren wir die Naivetaet, weil manueller Gate-Dispatch selten ist. Dokumentieren in CLAUDE.md als "Do nicht: manueller Gate-Dispatch waehrend aktivem Ingest".
- **`jq` nicht installiert:** SPEC-001 Preflight sollte das bereits gefangen haben. Wenn nicht: Hook C crashed mit `set -euo pipefail` → Exit ungleich 0 und 2 → "non-blocking error" per Doku → Stufe wechselt nicht automatisch, manuell korrigierbar.
- **`_pending.json` kaputt:** Hook B und C muessen defensiv parsen (`jq ... // empty`). Bei kaputtem JSON schweigen sie und blockieren nicht — das ist sicher: besser Ingest laeuft als dass nix mehr geht.
- **SubagentStop feuert nicht (API-Aenderung):** Dann bleibt `gates_passed` auf 0 und `stufe` auf `gates`. Folge: keine weiteren Ingests moeglich. Mitigation: Hard-Override per `rm wiki/_pending.json`. Dokumentiert im Troubleshooting-Abschnitt von CLAUDE.md.
- **Subagent-Type-Matcher funktioniert nicht wie erwartet:** Laut Doku ist der `SubagentStop`-Matcher "agent_type (Agent name like 'Explore')". Plugin-Namespace-Praefix ist nicht 100% dokumentiert. Fallback: Matcher auf `.*-pruefer$` als Regex. Wird im Test verifiziert (Task 7).

---

## Task-Zerlegung

### Task 0: Preflight

**Files:** Keine

- [ ] **Step 0.1: SPEC-001 ist Done?**

```bash
grep "^\*\*Status:\*\*" docs/specs/SPEC-001-passive-hooks.md
```

Expected: `**Status:** Done`. Wenn nicht → STOPP. SPEC-001 zuerst abschliessen.

- [ ] **Step 0.2: `jq` + Shell-Profile wie in SPEC-001 Task 0 pruefen**

Falls seitdem nichts geaendert wurde, nur Sanity-Check.

- [ ] **Step 0.3: Aktuelles Agent-Namespace verifizieren**

```bash
cat plugin/.claude-plugin/plugin.json
ls plugin/agents/
```

Expected: `plugin.json` hat `"name": "bibliothek"`, Agents liegen in `plugin/agents/*.md`. Die Gate-Agents muessen in frischer Session als `bibliothek:vollstaendigkeits-pruefer` etc. ansprechbar sein.

- [ ] **Step 0.4: SubagentStop-Matcher-Verhalten klaeren**

Laut Claude Code Doku matcht `SubagentStop` auf `agent_type`. Wir wissen nicht zu 100% ob der Matcher-String den Plugin-Praefix braucht oder nicht. Strategie: wir schreiben den Hook so dass er **intern** den `agent_type` aus stdin liest und selbst prueft, statt sich 100% auf den Matcher zu verlassen. Das ist robuster.

---

### Task 1: Neuer Agent `ingest-worker`

**Files:**
- Create: `plugin/agents/ingest-worker.md`

- [ ] **Step 1.1: Agent-Datei schreiben**

Datei: `plugin/agents/ingest-worker.md`

```markdown
---
name: ingest-worker
description: "Fuehrt einen einzelnen Ingest-Auftrag aus dem ingest-dispatch-template aus. Wird vom /ingest Skill dispatcht. Nie direkt aufrufen."
tools: Read, Write, Edit, Grep, Glob, Bash
---

# Subagent: Ingest-Worker

## Rolle

Der Ingest-Worker ist der technische Ausfuehrungs-Agent des `/ingest` Skills.
Er empfaengt einen vollstaendig ausgefuellten Prompt aus dem Ingest-Dispatch-Template
(`plugin/governance/ingest-dispatch-template.md`) und arbeitet diesen ab.

## Auftrag

Du fuehrst den dir uebergebenen Dispatch-Prompt strikt aus. Der Prompt folgt
dem Template und enthaelt alle Regeln, Kontexte und Qualitaetsanforderungen.

**Du formulierst den Auftrag nicht neu. Du ergaenzt ihn nicht. Du kuerzt ihn nicht.**

Das Template definiert:
- Wie du die PDF liest (vollstaendig, kein Skip)
- Welches Wiki-Verzeichnis du beschreibst
- Welche Hard Gates zu beachten sind
- Welches Output-Format die Quellenseite hat
- Wie du bei Kontext-Engpass stoppst

Halte dich daran.

## Bedeutung des Subagent-Types

Dein Subagent-Type `bibliothek:ingest-worker` ist die **einzige** Wirkung dieses Agent-Files —
das PreToolUse Hook `guard-pipeline-lock.sh` matcht genau auf diesen String, um neue
Ingest-Dispatches zu blockieren wenn `wiki/_pending.json` offen ist.

Aendere diesen Namen nicht ohne den Hook gleichzeitig anzupassen.
```

- [ ] **Step 1.2: Commit**

```bash
git add plugin/agents/ingest-worker.md
git commit -m "feat: Neuer Subagent bibliothek:ingest-worker

Dedizierter Agent fuer Ingest-Dispatches, damit Hook B (guard-pipeline-lock)
sie eindeutig identifizieren kann. Der Agent ist absichtlich minimal — die
eigentliche Arbeit kommt vom Dispatch-Prompt aus dem Template."
```

---

### Task 2: `/ingest` Skill + Template umstellen

**Files:**
- Modify: `plugin/skills/ingest/SKILL.md` (Phase 0.6)
- Modify: `plugin/governance/ingest-dispatch-template.md` (nur Kommentar-Ergaenzung)

- [ ] **Step 2.1: `ingest/SKILL.md` Phase 0.6 aendern**

Suche den Block:
```
4. Dispatche Agent mit ausgefuelltem Template als Prompt + gewaehltem Modell
5. Warte auf Ergebnis, dann weiter mit Phase 3 (Gate-Review)
```

Ersetze durch:
```
4. Dispatche Agent mit:
   - `subagent_type: "bibliothek:ingest-worker"` (PFLICHT — PreToolUse-Hook
     guard-pipeline-lock.sh matcht auf diesen String, um parallele Ingests zu
     blockieren solange _pending.json offen ist)
   - `prompt`: ausgefuelltes Template aus Schritt 2
   - `model`: "opus" oder "sonnet" nach Seitenzahl (Schritt 3)
   - `description`: "Ingest: <Quellen-Kurzname>"
5. Warte auf Ergebnis, dann weiter mit Phase 3 (Gate-Review)
```

- [ ] **Step 2.2: Template-Kommentar ergaenzen (optional aber empfehlenswert)**

In `plugin/governance/ingest-dispatch-template.md`, ganz oben nach dem ersten Absatz:

```markdown
> **Dispatch-Hinweis:** Subagent-Type ist `bibliothek:ingest-worker`. Der
> PreToolUse-Hook `guard-pipeline-lock.sh` nutzt diesen String als Matcher.
```

- [ ] **Step 2.3: Consistency-Check**

```bash
bash plugin/hooks/check-consistency.sh plugin/
```

Expected: 19/19 PASS (oder neue Zahl wenn Checks hinzugekommen sind). Wenn was bricht → lesen und fixen.

- [ ] **Step 2.4: Commit**

```bash
git add plugin/skills/ingest/SKILL.md plugin/governance/ingest-dispatch-template.md
git commit -m "feat: /ingest dispatcht bibliothek:ingest-worker mit explizitem subagent_type

Phase 0.6 im Skill und Template-Header dokumentieren den Dispatch-Zwang.
Vorbereitung fuer Hook B (guard-pipeline-lock)."
```

---

### Task 3: Hook B — guard-pipeline-lock.sh

**Files:**
- Create: `plugin/hooks/guard-pipeline-lock.sh`
- Create: `tests/test-guard-pipeline-lock.sh`

- [ ] **Step 3.1: Failing Test schreiben**

Datei: `tests/test-guard-pipeline-lock.sh`

```bash
#!/usr/bin/env bash
# Tests fuer guard-pipeline-lock.sh (Hook B)
set -uo pipefail

HOOK="$(dirname "$0")/../plugin/hooks/guard-pipeline-lock.sh"
PASS=0; FAIL=0

assert() {
  if [ "$2" = "$3" ]; then
    echo "  PASS: $1"; PASS=$((PASS+1))
  else
    echo "  FAIL: $1 — expected=$2 actual=$3"; FAIL=$((FAIL+1))
  fi
}

# Sandbox mit wiki/
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/wiki"

run_hook() {
  CLAUDE_PROJECT_DIR="$SANDBOX" echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK" >/dev/null 2>&1
  return $?
}

# --- Case 1: Nicht-Ingest-Worker Agent → allow ---
JSON='{"tool_input":{"subagent_type":"general-purpose","description":"random task"},"hook_event_name":"PreToolUse","tool_name":"Agent"}'
run_hook "$JSON"
assert "non-ingest-worker allowed" "0" "$?"

# --- Case 2: Ingest-Worker + kein Pending → allow ---
JSON='{"tool_input":{"subagent_type":"bibliothek:ingest-worker","description":"Ingest: foo"},"hook_event_name":"PreToolUse","tool_name":"Agent"}'
run_hook "$JSON"
assert "ingest-worker without pending allowed" "0" "$?"

# --- Case 3: Ingest-Worker + Pending existiert → deny ---
echo '{"typ":"ingest","stufe":"gates","quelle":"test-q","gates_passed":0,"gates_total":4}' > "$SANDBOX/wiki/_pending.json"
run_hook "$JSON"
assert "ingest-worker with pending blocked" "2" "$?"

# --- Case 4: Pending auf Stufe sideeffects → trotzdem blocked ---
echo '{"typ":"ingest","stufe":"sideeffects","quelle":"test-q","gates_passed":4,"gates_total":4}' > "$SANDBOX/wiki/_pending.json"
run_hook "$JSON"
assert "ingest-worker with sideeffects pending blocked" "2" "$?"

# --- Case 5: Pending geloescht → wieder allow ---
rm "$SANDBOX/wiki/_pending.json"
run_hook "$JSON"
assert "ingest-worker after cleanup allowed" "0" "$?"

# --- Case 6: Kaputtes _pending.json → defensiv allow ---
echo 'garbage' > "$SANDBOX/wiki/_pending.json"
run_hook "$JSON"
assert "ingest-worker with broken pending allowed (defensive)" "0" "$?"

rm -rf "$SANDBOX"
echo ""
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 3.2: Test ausfuehren → MUSS scheitern**

```bash
bash tests/test-guard-pipeline-lock.sh
```

Expected: 6 FAILs.

- [ ] **Step 3.3: Hook B schreiben**

Datei: `plugin/hooks/guard-pipeline-lock.sh`

```bash
#!/usr/bin/env bash
# guard-pipeline-lock.sh — PreToolUse Hook auf Agent-Dispatches
# Blockiert neue Ingest-Worker-Dispatches solange wiki/_pending.json existiert.
#
# Exit 0 = allow, Exit 2 = deny + stderr.

set -euo pipefail

INPUT=$(cat)

SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')

# Nur Ingest-Worker-Dispatches betrachten
if [ "$SUBAGENT_TYPE" != "bibliothek:ingest-worker" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PENDING="${PROJECT_DIR}/wiki/_pending.json"

# Kein Lock → allow
if [ ! -f "$PENDING" ]; then
  exit 0
fi

# Defensiv parsen — bei kaputtem JSON: durchlassen (lieber laufen als tot sein)
QUELLE=$(jq -r '.quelle // empty' "$PENDING" 2>/dev/null || echo "")
STUFE=$(jq -r '.stufe // empty' "$PENDING" 2>/dev/null || echo "")
PASSED=$(jq -r '.gates_passed // 0' "$PENDING" 2>/dev/null || echo "0")
TOTAL=$(jq -r '.gates_total // 4' "$PENDING" 2>/dev/null || echo "4")

if [ -z "$QUELLE" ] || [ -z "$STUFE" ]; then
  exit 0
fi

cat >&2 << BLOCK_MSG
PIPELINE-LOCK: Neuer Ingest blockiert.

Offene Quelle: ${QUELLE}
Stufe:          ${STUFE}
Gates:          ${PASSED}/${TOTAL}

Handlungsoptionen:
  1. Wenn stufe=gates: laufende Gate-Agents abwarten / fehlende nachdispatchen
  2. Wenn stufe=sideeffects: Phase 4 des /ingest Skills abschliessen
     (PDF sortieren, _index aktualisieren, _log Eintrag, _pending.json loeschen)
  3. Im Notfall: haendisch 'rm wiki/_pending.json' — nur wenn der vorherige
     Ingest abgebrochen wurde und nicht fortgefuehrt wird.
BLOCK_MSG
exit 2
```

- [ ] **Step 3.4: Ausfuehrbar machen**

```bash
chmod +x plugin/hooks/guard-pipeline-lock.sh
```

- [ ] **Step 3.5: Test ausfuehren → MUSS gruen sein**

```bash
bash tests/test-guard-pipeline-lock.sh
```

Expected: `Ergebnis: 6 passed, 0 failed`

- [ ] **Step 3.6: Commit**

```bash
git add plugin/hooks/guard-pipeline-lock.sh tests/test-guard-pipeline-lock.sh
git commit -m "feat: Hook B guard-pipeline-lock.sh — PreToolUse Agent-Lock

Blockiert bibliothek:ingest-worker Dispatches solange wiki/_pending.json
existiert. Defensiv gegen kaputtes JSON. 6/6 Tests gruen."
```

---

### Task 4: Hook C — advance-pipeline-lock.sh

**Files:**
- Create: `plugin/hooks/advance-pipeline-lock.sh`
- Create: `tests/test-advance-pipeline-lock.sh`

- [ ] **Step 4.1: Failing Test schreiben**

Datei: `tests/test-advance-pipeline-lock.sh`

```bash
#!/usr/bin/env bash
# Tests fuer advance-pipeline-lock.sh (Hook C)
set -uo pipefail

HOOK="$(dirname "$0")/../plugin/hooks/advance-pipeline-lock.sh"
PASS=0; FAIL=0

assert() {
  if [ "$2" = "$3" ]; then
    echo "  PASS: $1"; PASS=$((PASS+1))
  else
    echo "  FAIL: $1 — expected=$2 actual=$3"; FAIL=$((FAIL+1))
  fi
}

SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/wiki"
PENDING="$SANDBOX/wiki/_pending.json"

run_hook() {
  CLAUDE_PROJECT_DIR="$SANDBOX" echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK" >/dev/null 2>&1
  return $?
}

# --- Case 1: Kein Pending → exit 0 silent ---
JSON='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop"}'
run_hook "$JSON"
assert "no pending → exit 0" "0" "$?"

# --- Case 2: Pending mit Counter 0 → Counter wird 1 ---
echo '{"typ":"ingest","stufe":"gates","quelle":"q1","gates_passed":0,"gates_total":4}' > "$PENDING"
run_hook "$JSON"
assert "first gate → exit 0" "0" "$?"
COUNT=$(jq -r '.gates_passed' "$PENDING")
assert "counter incremented to 1" "1" "$COUNT"
STUFE=$(jq -r '.stufe' "$PENDING")
assert "stufe stays gates" "gates" "$STUFE"

# --- Case 3: Drei weitere Gates → Counter 4, Stufe wechselt ---
for i in 1 2 3; do run_hook "$JSON" >/dev/null; done
COUNT=$(jq -r '.gates_passed' "$PENDING")
assert "counter after 4 gates" "4" "$COUNT"
STUFE=$(jq -r '.stufe' "$PENDING")
assert "stufe wechselt zu sideeffects" "sideeffects" "$STUFE"

# --- Case 4: Erneute SubagentStop auf stufe=sideeffects → keine Aenderung ---
run_hook "$JSON"
COUNT2=$(jq -r '.gates_passed' "$PENDING")
assert "counter bleibt 4 nach sideeffects" "4" "$COUNT2"
STUFE2=$(jq -r '.stufe' "$PENDING")
assert "stufe bleibt sideeffects" "sideeffects" "$STUFE2"

# --- Case 5: Alte Pending ohne gates_passed → defensive Default 0 → 1 ---
echo '{"typ":"ingest","stufe":"gates","quelle":"q2"}' > "$PENDING"
run_hook "$JSON"
COUNT3=$(jq -r '.gates_passed' "$PENDING")
assert "legacy pending migriert zu counter 1" "1" "$COUNT3"

# --- Case 6: Kaputtes Pending → exit 0 ohne Crash ---
echo 'garbage' > "$PENDING"
run_hook "$JSON"
assert "broken pending → exit 0" "0" "$?"

rm -rf "$SANDBOX"
echo ""
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 4.2: Test ausfuehren → MUSS scheitern**

```bash
bash tests/test-advance-pipeline-lock.sh
```

- [ ] **Step 4.3: Hook C schreiben**

Datei: `plugin/hooks/advance-pipeline-lock.sh`

```bash
#!/usr/bin/env bash
# advance-pipeline-lock.sh — SubagentStop Hook
# Inkrementiert gates_passed-Counter in wiki/_pending.json nach jedem Gate-Agent.
# Bei gates_passed >= gates_total: wechselt stufe auf "sideeffects".
# Blockiert nie. Exit 0 immer.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PENDING="${PROJECT_DIR}/wiki/_pending.json"

# Kein Lock → nichts zu tun
if [ ! -f "$PENDING" ]; then
  exit 0
fi

# Defensiv lesen — bei kaputtem JSON: nichts machen
if ! jq -e . "$PENDING" >/dev/null 2>&1; then
  exit 0
fi

STUFE=$(jq -r '.stufe // empty' "$PENDING" 2>/dev/null || echo "")
if [ "$STUFE" != "gates" ]; then
  # Lock ist schon in sideeffects oder unbekanntem Zustand — nicht anfassen
  exit 0
fi

PASSED=$(jq -r '.gates_passed // 0' "$PENDING" 2>/dev/null || echo "0")
TOTAL=$(jq -r '.gates_total // 4' "$PENDING" 2>/dev/null || echo "4")
NEW_PASSED=$((PASSED + 1))

TMP="${PENDING}.tmp.$$"

if [ "$NEW_PASSED" -ge "$TOTAL" ]; then
  jq --argjson n "$NEW_PASSED" '.gates_passed = $n | .stufe = "sideeffects"' "$PENDING" > "$TMP" && mv "$TMP" "$PENDING"
else
  jq --argjson n "$NEW_PASSED" '.gates_passed = $n' "$PENDING" > "$TMP" && mv "$TMP" "$PENDING"
fi

exit 0
```

- [ ] **Step 4.4: Ausfuehrbar machen**

```bash
chmod +x plugin/hooks/advance-pipeline-lock.sh
```

- [ ] **Step 4.5: Test ausfuehren → MUSS gruen sein**

```bash
bash tests/test-advance-pipeline-lock.sh
```

Expected: alle 10 Cases gruen.

- [ ] **Step 4.6: Commit**

```bash
git add plugin/hooks/advance-pipeline-lock.sh tests/test-advance-pipeline-lock.sh
git commit -m "feat: Hook C advance-pipeline-lock.sh — SubagentStop Lock-Transition

Inkrementiert gates_passed-Counter nach jedem Gate-Agent SubagentStop.
Bei 4/4: Stufe wechselt auf sideeffects. Legacy-Pending ohne Counter
wird automatisch migriert. 10/10 Tests gruen."
```

---

### Task 5: Hooks in hooks.json registrieren

**Files:**
- Modify: `plugin/hooks/hooks.json`

- [ ] **Step 5.1: Aktuelles hooks.json lesen**

```bash
cat plugin/hooks/hooks.json
```

Expected: `SessionStart`, `PreToolUse[Edit|Write]`, `UserPromptSubmit` (aus SPEC-001).

- [ ] **Step 5.2: Erweitern**

Neuer Inhalt:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
            "async": false
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/guard-wiki-writes.sh\"",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/guard-pipeline-lock.sh\"",
            "timeout": 5
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "bibliothek:(vollstaendigkeits|quellen|konsistenz|vokabular)-pruefer",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/advance-pipeline-lock.sh\"",
            "timeout": 10
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/inject-lock-warning.sh\"",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 5.3: JSON-Syntax verifizieren**

```bash
jq . plugin/hooks/hooks.json >/dev/null && echo "JSON ok"
```

- [ ] **Step 5.4: Commit**

```bash
git add plugin/hooks/hooks.json
git commit -m "feat: Hook B + C in hooks.json registriert

PreToolUse Agent -> guard-pipeline-lock.sh
SubagentStop bibliothek:(4 Gates) -> advance-pipeline-lock.sh"
```

---

### Task 6: Phase-4-Cleanup im Ingest-Skill

**Files:**
- Modify: `plugin/skills/ingest/SKILL.md` (Phase 4 Nebeneffekte)

- [ ] **Step 6.1: Phase-4-Nebeneffekt-Checkliste pruefen**

```bash
grep -n "Nebeneffekte\|_pending.json" plugin/skills/ingest/SKILL.md
```

- [ ] **Step 6.2: Loesch-Schritt hinzufuegen**

In der Phase-4-Checkliste von `ingest/SKILL.md`, nach dem letzten Pflicht-Nebeneffekt ergaenzen:

```markdown
- [ ] **Pipeline-Lock freigeben** — `rm -f wiki/_pending.json` als ALLERLETZTEN Schritt,
      erst NACHDEM alle anderen Nebeneffekte nachweislich durchgelaufen sind.
      Solange die Datei existiert blockt guard-pipeline-lock.sh jeden neuen Ingest.
```

- [ ] **Step 6.3: Konsistenz-Check**

```bash
bash plugin/hooks/check-consistency.sh plugin/
```

- [ ] **Step 6.4: Commit**

```bash
git add plugin/skills/ingest/SKILL.md
git commit -m "feat: /ingest Phase 4 schliesst mit rm _pending.json ab

Der Pipeline-Lock wird erst als letzter Nebeneffekt freigegeben —
nach PDF-Sortierung, _index-Update, _log-Eintrag und MOCs. Damit
kann der naechste /ingest nur starten wenn der vorige vollstaendig
abgeschlossen ist."
```

---

### Task 7: Integration-Test in frischer Session

**Files:** Keine Aenderungen — nur Verifikation

- [ ] **Step 7.1: Session-Neustart**

Hooks sind gecached, also neuer claude-code Aufruf im Repo.

- [ ] **Step 7.2: Test A — SubagentStop-Matcher funktioniert wirklich**

Simulation: Dispatche manuell einen Gate-Agent (z.B. `vollstaendigkeits-pruefer`) auf irgendeine Test-Wiki-Datei. Vor dem Dispatch `wiki/_pending.json` anlegen:

```bash
mkdir -p wiki
echo '{"typ":"ingest","stufe":"gates","quelle":"test","gates_passed":0,"gates_total":4}' > wiki/_pending.json
```

Dann im Chat:
```
Dispatche bibliothek:vollstaendigkeits-pruefer auf wiki/quellen/irgendwas.md
```

Nach Agent-Abschluss pruefen:
```bash
jq . wiki/_pending.json
```

Expected: `gates_passed: 1`.

Wenn der Counter auf 0 bleibt → der SubagentStop-Matcher hat nicht gematcht. Fallback-Plan: Matcher auf `.*-pruefer$` ohne Plugin-Praefix aendern.

- [ ] **Step 7.3: Test B — Zweiter Ingest wird blockiert**

```bash
# Mit _pending.json noch da:
```

Im Chat:
```
/ingest wiki/_pdfs/neu/any.pdf
```

Expected: Der Ingest startet Phase 0, kommt zu Phase 0.6 (Dispatch Ingest-Worker) und das Agent-Tool wird von `guard-pipeline-lock.sh` blockiert. Der Main-Agent bekommt die Block-Meldung und meldet dem User.

- [ ] **Step 7.4: Test C — Lock-Cleanup erlaubt wieder**

```bash
rm wiki/_pending.json
```

Im Chat nochmal:
```
/ingest wiki/_pdfs/neu/any.pdf
```

Expected: Dispatch geht durch.

- [ ] **Step 7.5: Test D — Ende-zu-Ende Happy-Path auf kleinem PDF**

Kleinstes PDF im `_pdfs/neu/` Ordner:
```
/ingest
```

Beobachte:
1. Phase 0.4 schreibt `[INGEST UNVOLLSTAENDIG]` Marker ins `_log.md` und legt `_pending.json` an
2. Phase 0.6 dispatcht `bibliothek:ingest-worker` — kommt durch weil Pending noch nicht existiert beim ersten Dispatch (Reihenfolge-Frage!)

**Achtung:** Phase 0.4 (Marker setzen) vs. Phase 0.6 (Dispatch) — wenn `_pending.json` bereits in Phase 0.4 geschrieben wird, blockt der Hook den ersten Dispatch. Das ist ein Design-Problem. Fix: Phase 0.4 legt NUR den `_log.md` Marker an, `_pending.json` wird erst **nachdem** der Ingest-Worker zurueckkommt geschrieben (in Phase 3 Beginn).

Das bedeutet Task 6 muss erweitert werden — siehe Step 7.6.

- [ ] **Step 7.6: Design-Fix im Ingest-Skill**

Wenn Test D zeigt, dass Phase 0.4 bereits `_pending.json` schreibt: in `ingest/SKILL.md` Phase 0.4 aendern auf "nur _log.md Marker setzen" und `_pending.json` in Phase 3 (direkt vor Gate-Dispatch) erstellen lassen.

Das ist ein non-trivialer Skill-Flow-Refactor. Wenn der Test ihn erzwingt → eigenen Commit machen:

```bash
git add plugin/skills/ingest/SKILL.md
git commit -m "fix: _pending.json erst nach Ingest-Worker-Rueckkehr schreiben

Phase 0.4 setzt nur den _log.md Marker. _pending.json entsteht erst in
Phase 3 (Gate-Review), damit guard-pipeline-lock den ERSTEN Ingest-Dispatch
nicht selbst blockiert."
```

- [ ] **Step 7.7: Nach Fix: Test D wiederholen**

Frische Session, kleines PDF, `/ingest`, Beobachtung:
1. Ingest-Worker startet
2. Quellenseite wird geschrieben
3. Phase 3 Beginn: `_pending.json` angelegt mit `stufe=gates, gates_passed=0`
4. 4 Gate-Agents parallel dispatcht
5. Nach jedem Gate: `gates_passed` inkrementiert
6. Nach dem vierten Gate: `stufe = sideeffects`
7. Phase 4 laeuft durch, letzter Step: `rm _pending.json`
8. Kein Lock mehr → naechster `/ingest` geht

---

### Task 8: CLAUDE.md final aktualisieren

**Files:**
- Modify: `CLAUDE.md` (Projekt-Root)

- [ ] **Step 8.1: Enforcement-Sektion**

Jetzt ehrlich "3 Schichten" schreiben:

```markdown
## Enforcement — 3 Schichten

1. **Prompt-Law** — Skill-Anweisungen, Hard Gates, Dispatch-Templates
2. **Subagent-Review** — 4 Pruefer (Ingest) + 2 Reviewer (Synthese) + 1 Validator
3. **Machine-Law:**
   - `guard-wiki-writes.sh` (PreToolUse Edit|Write): blockiert Wiki-Writes ausserhalb /ingest, /synthese, /normenupdate, /vokabular
   - `guard-pipeline-lock.sh` (PreToolUse Agent): blockiert neue Ingest-Worker-Dispatches solange _pending.json offen ist
   - `advance-pipeline-lock.sh` (SubagentStop auf 4 Gate-Agents): inkrementiert Counter, wechselt Stufe nach 4/4 Gates
   - `inject-lock-warning.sh` (UserPromptSubmit): passive Warnung wenn Lock offen
   - `check-wiki-output.sh`: wird von Gate-Agents selbst aufgerufen

Alle Schichten sind jetzt aktiv.
```

- [ ] **Step 8.2: Troubleshooting-Sektion**

Neuer Abschnitt:

```markdown
## Troubleshooting

### "Pipeline-Lock: neuer Ingest blockiert" aber vorheriger wurde abgebrochen

```bash
rm wiki/_pending.json
```

Nur wenn der vorige Ingest nachweislich nicht fortgefuehrt wird.
Ueberpruefe _log.md auf offene [INGEST UNVOLLSTAENDIG] Marker.

### SubagentStop feuert nicht, Counter bleibt auf 0

Pruefe:
1. Claude Code Version (SubagentStop wurde spaet 2025 eingefuehrt)
2. Matcher in hooks.json — mit `bash tests/test-advance-pipeline-lock.sh` verifizieren
3. Hook-Script ist ausfuehrbar: `ls -la plugin/hooks/advance-pipeline-lock.sh`
```

- [ ] **Step 8.3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md final Enforcement-Sektion nach SPEC-002

3 Schichten jetzt vollstaendig dokumentiert. Troubleshooting-Abschnitt
fuer die haeufigsten Lock-Probleme hinzugefuegt."
```

---

### Task 9: Abschluss

- [ ] **Step 9.1: Alle Tests durchlaufen lassen**

```bash
bash tests/test-guard-wiki-writes.sh
bash tests/test-inject-lock-warning.sh
bash tests/test-guard-pipeline-lock.sh
bash tests/test-advance-pipeline-lock.sh
bash plugin/hooks/check-consistency.sh plugin/
```

Expected: alle gruen, Konsistenz 19+/19+ PASS.

- [ ] **Step 9.2: SPEC-002 Status aktualisieren**

In `docs/specs/SPEC-002-pipeline-lock-enforcement.md`:
```
**Status:** Done
**Aktualisiert:** <heutiges Datum>
```

In `docs/specs/INDEX.md` die Zeile aktualisieren.

- [ ] **Step 9.3: Final Commit**

```bash
git add docs/specs/SPEC-002-pipeline-lock-enforcement.md docs/specs/INDEX.md
git commit -m "docs: SPEC-002 als Done markiert — Pipeline-Lock-Enforcement live"
```

---

## Abschluss-Checkliste

- [ ] Agent `bibliothek:ingest-worker` existiert und wird vom /ingest Skill dispatcht
- [ ] `guard-pipeline-lock.sh` blockiert parallele Ingest-Worker-Dispatches
- [ ] `advance-pipeline-lock.sh` zaehlt Gates und wechselt Stufe
- [ ] `_pending.json` wird von /ingest Phase 3 angelegt und Phase 4 geloescht
- [ ] Alle 4 Hook-Tests gruen
- [ ] End-zu-End Integration-Test auf kleinem PDF erfolgreich
- [ ] CLAUDE.md reflektiert die vollstaendige 3-Schichten-Enforcement
- [ ] SPEC-002 Status: Done

**Dauer:** ½ bis 1 Tag, hauptsaechlich wegen Session-Restart-Zyklen beim Debuggen und dem Phase-0.4-vs-Phase-3 Lock-Timing (Task 7.6 kann unterschaetzt sein).
