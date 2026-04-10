# SPEC-001: Passive Hook-Infrastruktur

**Status:** Done
**Version:** 1.0
**Erstellt:** 2026-04-10
**Aktualisiert:** 2026-04-11

> **Fuer agentische Worker:** REQUIRED SUB-SKILL — `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`. Task-Steps verwenden `- [ ]` Checkbox-Syntax.

**Ziel:** Zwei nicht-blockierende Hooks nach dem Website_v2-Pattern einfuehren: (a) Schreibschutz fuer `wiki/**/*.md` der nur Writes innerhalb einer Skill-Session zulaesst, (b) passive `UserPromptSubmit`-Warnung wenn ein Pipeline-Lock offen ist.

**Architektur:** Exit-Code-basierte Hooks (`exit 0 = allow`, `exit 2 = deny + stderr`) statt JSON-Response. `jq` fuer robustes stdin-Parsing. Transcript-Check wie in `Website_v2/.claude/hooks/enforce-design-plugin.sh`. Keine Abhaengigkeit zum Subagent-Type — das ist SPEC-002.

**Tech Stack:** Bash (`set -euo pipefail`), `jq` (macOS Standard), Claude Code Hooks API 2026 (`hookSpecificOutput` nur fuer `UserPromptSubmit`-Kontext).

---

## Zusammenfassung

Das alte `check-wiki-write.sh` war als PostToolUse registriert, benutzte das veraltete `{"decision": "block"}` JSON-Schema und parste stdin mit fragilen `sed`-Hacks. Folge: Jeder Hook-Call produzierte "JSON validation failed", unabhaengig davon ob wirklich eine Wiki-Datei beruehrt wurde. Abgeschaltet in Commits `12e8a3c` + `19e23c7`. Damit ist Machine-Law (Schicht 3 der Enforcement aus CLAUDE.md) komplett offline.

Dieser Spec baut zwei neue, schlanke Hooks die das Website_v2-Pattern kopieren — nachweislich funktionierend seit Monaten. Keine JSON-Schema-Fallen, keine sed-Hacks, keine PostToolUse-Block-Illusion.

Die aktive Pipeline-Lock-Enforcement (Hook B + C aus dem Debug-Befund) bleibt SPEC-002 vorbehalten, weil sie einen Plugin-Refactor (dedizierter Subagent-Type) braucht.

## Anforderungen

1. **Hook A — Schreibschutz `guard-wiki-writes.sh`:**
   - Fires auf `PreToolUse` Matcher `Edit|Write`
   - Allow wenn `tool_input.file_path` nicht unter `wiki/`
   - Allow wenn Pfad unter `wiki/` UND eines der vier Skills (`ingest`, `synthese`, `normenupdate`, `vokabular`) im Session-Transcript geladen wurde
   - Deny (`exit 2` + stderr) sonst
   - Feuert auch auf Subagent-Tool-Calls (dieselbe Regel)

2. **Hook D — Lock-Warnung `inject-lock-warning.sh`:**
   - Fires auf `UserPromptSubmit` (kein Matcher)
   - Wenn `wiki/_pending.json` existiert → gibt JSON mit `hookSpecificOutput.additionalContext` aus, der dem Main-Agent Lock-Stufe + Quelle mitteilt
   - Wenn nicht → `exit 0` silent
   - Blockiert nie

3. **Hook-Registrierung:** `plugin/hooks/hooks.json` um beide Hooks erweitert, `SessionStart` bleibt wie ist.

4. **Cleanup:** Tote Datei `plugin/hooks/check-wiki-write.sh` wird geloescht.

5. **Tests:** Unit-Tests fuer beide Hooks in `tests/`. Ausfuehrbar via `bash tests/test-guard-wiki-writes.sh` und `bash tests/test-inject-lock-warning.sh`.

6. **Dokumentation:** `CLAUDE.md` Enforcement-Sektion beschreibt die neue Lage ehrlich (nicht "3 Schichten" wenn es aktuell nur 2 sind).

## Technische Details

### Hook A — guard-wiki-writes.sh

**Pfad:** `plugin/hooks/guard-wiki-writes.sh`

**Input (stdin JSON von Claude Code):**
```json
{
  "session_id": "...",
  "transcript_path": "/Users/.../transcript.jsonl",
  "cwd": "/Users/maximilianstark/Projects/llm-wiki",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/Users/.../wiki/quellen/foo.md",
    "content": "..."
  }
}
```

**Entscheidungslogik:**

```
FILE_PATH = jq .tool_input.file_path
IF leer ODER kein /wiki/ im Pfad ODER nicht auf .md endet:
    exit 0 (allow)

TRANSCRIPT_PATH = jq .transcript_path
IF TRANSCRIPT_PATH existiert nicht:
    exit 2 mit Warnung "Transcript nicht lesbar"

IF Zeilen mit "name":"Skill" im TRANSCRIPT_PATH existieren
   UND eine davon "skill":"(bibliothek:)?(ingest|synthese|normenupdate|vokabular)" enthaelt:
    exit 0 (allow)

ELSE:
    stderr: "Wiki-Writes sind nur innerhalb /ingest, /synthese, /normenupdate oder /vokabular erlaubt."
    exit 2
```

**Warum zwei-stufiger Transcript-Grep:** Claude Code speichert Skill-Invocations als `tool_use`-Events mit `"name":"Skill"` im Transcript. Ein einfacher Grep nach "ingest" genuegt NICHT — das Wort taucht auch in File-Reads und Gespraechen auf (False-Positive in E2E-Test entdeckt, 2026-04-11). Der zwei-stufige Grep filtert erst auf Skill-Tool-Calls, dann auf den Skill-Namen.

**Warum das auch fuer Subagents funktioniert:** Laut Claude Code Hooks Reference zeigt `transcript_path` auch bei Subagent-Calls auf das **Main-Transcript**. Ein `/ingest` das den Ingest-Worker dispatcht hinterlaesst den Marker im Main-Transcript, bevor der Subagent Write aufruft.

### Hook D — inject-lock-warning.sh

**Pfad:** `plugin/hooks/inject-lock-warning.sh`

**Input (stdin JSON):**
```json
{
  "session_id": "...",
  "transcript_path": "...",
  "cwd": "/Users/maximilianstark/Projects/llm-wiki",
  "hook_event_name": "UserPromptSubmit",
  "prompt": "..."
}
```

**Output wenn Lock offen:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "⚠️ Pipeline-Lock offen: Quelle=<name>, Stufe=<gates|sideeffects>. Bevor du einen neuen Ingest startest, schliesse die offenen Gates/Nebeneffekte ab."
  }
}
```

**Pfad-Aufloesung:** Das Wiki liegt in `${CLAUDE_PROJECT_DIR}/wiki/_pending.json`. `CLAUDE_PROJECT_DIR` ist immer gesetzt wenn Hooks laufen.

### hooks.json

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

### Test-Harness

Bestehendes `tests/`-Verzeichnis hat bereits Hook-Tests (`test-wiki-write-hook.sh`, `test-gates-pending-hook.sh`). Neue Tests folgen demselben Stil: Hook mit gebautem JSON per stdin aufrufen, Exit-Code + stderr pruefen.

**Helper-Pattern:**
```bash
run_hook() {
  local hook="$1"; local stdin_json="$2"
  echo "$stdin_json" | bash "$hook" 2>&1
  return $?
}
```

## Akzeptanzkriterien

- [ ] `plugin/hooks/guard-wiki-writes.sh` existiert, hat `set -euo pipefail`, parst mit `jq`
- [ ] `plugin/hooks/inject-lock-warning.sh` existiert, hat `set -euo pipefail`, parst mit `jq`
- [ ] Beide Hooks in `plugin/hooks/hooks.json` registriert
- [ ] `plugin/hooks/check-wiki-write.sh` geloescht
- [ ] `tests/test-guard-wiki-writes.sh` existiert und alle Cases gruen
- [ ] `tests/test-inject-lock-warning.sh` existiert und alle Cases gruen
- [ ] `tests/test-wiki-write-hook.sh` wurde entweder geloescht oder auf neuen Hook umgeschrieben
- [ ] `CLAUDE.md` im Projekt-Root spiegelt den neuen Enforcement-Stand wider
- [ ] In einer frischen Claude-Code-Session: manueller Test — Write auf `wiki/quellen/test.md` ohne `/ingest` wird geblockt mit der Meldung aus dem Hook
- [ ] In derselben Session: `/ingest` starten, dann Write auf Wiki-Datei wird durchgelassen
- [ ] Mit manuell angelegter `wiki/_pending.json`: naechster User-Prompt wird mit Lock-Warning im Kontext versehen

## Edge Cases

- **Shell-Profile printet Zeug in stdout:** Claude Code Doku warnt explizit davor. Hook-Scripts rufen nicht die Interactive-Shell auf, sondern werden direkt von bash ausgefuehrt. Kein Risiko solange `.zshrc`-Logik in `if [[ $- == *i* ]]; then`-Block steht. Preflight-Test (Task 1) verifiziert das.
- **`jq` nicht installiert:** macOS hat `jq` standardmaessig *nicht*. Preflight-Task prueft und installiert mit Homebrew falls noetig.
- **`transcript_path` ist `null` oder Datei existiert nicht:** Hook A faehrt auf deny (`exit 2`) — sicherer Default. Meldung: "Transcript nicht lesbar, Wiki-Schutz greift." Passiert selten, meistens nur in sehr frischen Sessions bevor das Transcript auf Disk geflusht wurde.
- **File-Pfad mit Leerzeichen/Umlauten:** `jq -r` liefert den String ohne Quote-Probleme, wir uebergeben ihn nie weiter an eval oder -x. Unproblematisch.
- **Legitimer Cleanup von `wiki/`:** Wenn du mal wirklich eine Wiki-Datei manuell per Hand loeschen willst, blockt der Hook das nicht — er greift nur auf `Edit|Write`, nicht auf `Bash(rm ...)`. Das ist bewusst: Loeschen per Hand ist selten und der Hook soll nicht in die Quere kommen. Dokumentiert in Akzeptanzkriterium #6.
- **Subagent schreibt in wiki/, aber Main-Agent hat kein Skill geladen:** Sollte nicht passieren wenn Dispatches nur aus Skills heraus erfolgen. Wenn doch → Hook blockt, Fehlermeldung landet im Subagent-Transcript und wird an Main-Agent als Tool-Error propagiert. Das ist das gewuenschte Verhalten.

---

## Task-Zerlegung

### Task 0: Preflight

**Files:** Keine Aenderungen — nur Checks

- [ ] **Step 0.1: `jq` verfuegbar?**

```bash
which jq && jq --version
```

Expected: Pfad + Version. Wenn "not found":
```bash
brew install jq
```

- [ ] **Step 0.2: Shell-Profile clean?**

```bash
bash -c 'echo test' 2>&1
```

Expected: **nur** `test`, keine anderen Ausgaben. Falls anderes kommt → `.bashrc`/`.zshrc` hat nicht-interaktive Ausgaben, muessen in `if [[ $- == *i* ]]` eingewrappt werden.

- [ ] **Step 0.3: Plugin-Cache-Symlink aktiv?**

```bash
ls -la ~/.claude/plugins/cache/.../plugin/ 2>/dev/null | head -3
```

Expected: Symlink zeigt auf dieses Repo. Wenn nicht: Session-Neustart noetig (siehe CLAUDE.md).

- [ ] **Step 0.4: Referenz-Pattern nochmal anschauen**

Lies `~/Projects/Website_v2/.claude/hooks/enforce-design-plugin.sh` komplett. Verstehe:
- Wie `INPUT=$(cat)` den stdin-JSON einfaengt
- Wie `jq -r '.tool_input.file_path // empty'` mit leeren Feldern umgeht
- Wie der Transcript-Check mit `grep -q` auf verschiedene Marker sucht
- Wann `exit 0` vs `exit 2` verwendet wird

---

### Task 1: Hook A — Schreibschutz

**Files:**
- Create: `plugin/hooks/guard-wiki-writes.sh`
- Create: `tests/test-guard-wiki-writes.sh`

- [ ] **Step 1.1: Failing Test schreiben**

Datei: `tests/test-guard-wiki-writes.sh`

```bash
#!/usr/bin/env bash
# Tests fuer guard-wiki-writes.sh (Hook A)
set -uo pipefail

HOOK="$(dirname "$0")/../plugin/hooks/guard-wiki-writes.sh"
PASS=0; FAIL=0

assert() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $name"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $name — expected=$expected actual=$actual"
    FAIL=$((FAIL+1))
  fi
}

run_hook() {
  # stdin-JSON -> Hook -> stdout+stderr gesammelt, Exit-Code zurueck
  echo "$1" | bash "$HOOK" 2>&1
  return $?
}

# --- Mock-Transcripts fuer Tests ---
MOCK_DIR=$(mktemp -d)
T_WITH_INGEST="$MOCK_DIR/t_ingest.jsonl"
T_EMPTY="$MOCK_DIR/t_empty.jsonl"
echo '{"role":"user","content":"/ingest"}' > "$T_WITH_INGEST"
echo '{"role":"user","content":"hello"}' > "$T_EMPTY"

# --- Case 1: Nicht-Wiki-Pfad wird durchgelassen ---
JSON1='{"transcript_path":"'"$T_EMPTY"'","tool_input":{"file_path":"/tmp/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_hook "$JSON1" >/dev/null
assert "non-wiki path allowed" "0" "$?"

# --- Case 2: Wiki-Pfad mit Skill-Marker im Transcript ---
JSON2='{"transcript_path":"'"$T_WITH_INGEST"'","tool_input":{"file_path":"/Users/x/wiki/quellen/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_hook "$JSON2" >/dev/null
assert "wiki path + ingest in transcript allowed" "0" "$?"

# --- Case 3: Wiki-Pfad ohne Skill-Marker → blockiert ---
JSON3='{"transcript_path":"'"$T_EMPTY"'","tool_input":{"file_path":"/Users/x/wiki/konzepte/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_hook "$JSON3" >/dev/null
assert "wiki path without skill marker blocked" "2" "$?"

# --- Case 4: Edit auf _vokabular.md (Sonderdatei) mit vokabular-Skill ---
T_VOKAB="$MOCK_DIR/t_vokab.jsonl"
echo '{"role":"user","content":"/vokabular"}' > "$T_VOKAB"
JSON4='{"transcript_path":"'"$T_VOKAB"'","tool_input":{"file_path":"/Users/x/wiki/_vokabular.md"},"hook_event_name":"PreToolUse","tool_name":"Edit"}'
run_hook "$JSON4" >/dev/null
assert "vokabular.md with /vokabular skill allowed" "0" "$?"

# --- Case 5: transcript_path fehlt ---
JSON5='{"tool_input":{"file_path":"/Users/x/wiki/quellen/foo.md"},"hook_event_name":"PreToolUse","tool_name":"Write"}'
run_hook "$JSON5" >/dev/null
assert "missing transcript_path blocks" "2" "$?"

rm -rf "$MOCK_DIR"
echo ""
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 1.2: Test ausfuehren → MUSS scheitern**

```bash
bash tests/test-guard-wiki-writes.sh
```

Expected: 5 FAILs (Hook existiert nicht, `bash: guard-wiki-writes.sh: No such file or directory`).

- [ ] **Step 1.3: Hook A schreiben**

Datei: `plugin/hooks/guard-wiki-writes.sh`

```bash
#!/usr/bin/env bash
# guard-wiki-writes.sh — PreToolUse Hook fuer Edit|Write
# Blockiert Writes auf wiki/**/*.md wenn kein Bibliothek-Skill in der Session geladen wurde.
# Exit 0 = allow, Exit 2 = deny + stderr.
#
# Pattern orientiert an Website_v2/.claude/hooks/enforce-design-plugin.sh

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Keine Datei? Nicht unser Fall.
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Nicht unter wiki/? Durchlassen.
case "$FILE_PATH" in
  */wiki/*.md) ;;  # weiter
  *) exit 0 ;;
esac

# Transcript laden
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "WIKI-GATE: Transcript nicht lesbar — Wiki-Schutz aktiv. Starte mit /ingest, /synthese, /normenupdate oder /vokabular." >&2
  exit 2
fi

# Wurde ein Bibliothek-Skill in dieser Session via Skill-Tool geladen?
# Zwei-stufig: erst Zeilen mit Skill-Tool-Calls filtern, dann Skill-Name pruefen.
if grep '"name":"Skill"' "$TRANSCRIPT_PATH" 2>/dev/null | grep -qE '"skill":"(bibliothek:)?(ingest|synthese|normenupdate|vokabular)"'; then
  exit 0
fi

cat >&2 << 'BLOCK_MSG'
WIKI-GATE: Direkte Wiki-Writes sind nicht erlaubt.

Wiki-Dateien (wiki/**/*.md) duerfen nur innerhalb eines der vier Schreib-Skills
geaendert werden:

  /ingest          — Neue Quellenseiten aus PDFs
  /synthese        — Konzeptseiten vertiefen
  /normenupdate    — Normseiten aktualisieren
  /vokabular       — _vokabular.md pflegen

Rufe zuerst eines davon auf, dann ist der Write erlaubt.
BLOCK_MSG
exit 2
```

- [ ] **Step 1.4: Ausfuehrbar machen**

```bash
chmod +x plugin/hooks/guard-wiki-writes.sh
```

- [ ] **Step 1.5: Test ausfuehren → MUSS gruen sein**

```bash
bash tests/test-guard-wiki-writes.sh
```

Expected: `Ergebnis: 5 passed, 0 failed`

- [ ] **Step 1.6: Commit**

```bash
git add plugin/hooks/guard-wiki-writes.sh tests/test-guard-wiki-writes.sh
git commit -m "feat: Hook A guard-wiki-writes.sh — PreToolUse Schreibschutz

PreToolUse-Hook fuer Edit|Write blockiert Wiki-Writes ausserhalb der
vier Bibliothek-Schreib-Skills. Transcript-Check via grep, Website_v2-Pattern.
5/5 Tests gruen."
```

---

### Task 2: Hook D — Lock-Warnung

**Files:**
- Create: `plugin/hooks/inject-lock-warning.sh`
- Create: `tests/test-inject-lock-warning.sh`

- [ ] **Step 2.1: Failing Test schreiben**

Datei: `tests/test-inject-lock-warning.sh`

```bash
#!/usr/bin/env bash
# Tests fuer inject-lock-warning.sh (Hook D)
set -uo pipefail

HOOK="$(dirname "$0")/../plugin/hooks/inject-lock-warning.sh"
PASS=0; FAIL=0

assert() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $name"; PASS=$((PASS+1))
  else
    echo "  FAIL: $name — expected='$expected' actual='$actual'"; FAIL=$((FAIL+1))
  fi
}

# --- Sandbox mit Wiki-Verzeichnis ---
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/wiki"

run_in_sandbox() {
  # Hook erwartet CLAUDE_PROJECT_DIR als cwd-Basis
  CLAUDE_PROJECT_DIR="$SANDBOX" echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK" 2>&1
  return $?
}

# --- Case 1: Kein _pending.json → silent, exit 0, keine Ausgabe ---
JSON='{"prompt":"hello","hook_event_name":"UserPromptSubmit"}'
OUT=$(run_in_sandbox "$JSON")
RC=$?
assert "no pending → exit 0" "0" "$RC"
assert "no pending → no output" "" "$OUT"

# --- Case 2: _pending.json mit stufe=gates → JSON mit additionalContext ---
echo '{"typ":"ingest","stufe":"gates","quelle":"fingerloos-ec2-2016","timestamp":"2026-04-10T12:00:00Z"}' > "$SANDBOX/wiki/_pending.json"
OUT=$(run_in_sandbox "$JSON")
RC=$?
assert "pending exists → exit 0" "0" "$RC"

# Output muss valides JSON sein
if echo "$OUT" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
  echo "  PASS: output is valid JSON with additionalContext"
  PASS=$((PASS+1))
else
  echo "  FAIL: output is not valid JSON: $OUT"
  FAIL=$((FAIL+1))
fi

# additionalContext muss Quellen-Name enthalten
CTX=$(echo "$OUT" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null || echo "")
case "$CTX" in
  *fingerloos-ec2-2016*) echo "  PASS: context mentions source name"; PASS=$((PASS+1));;
  *) echo "  FAIL: context missing source — got: $CTX"; FAIL=$((FAIL+1));;
esac

# hookEventName muss gesetzt sein
EVT=$(echo "$OUT" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null || echo "")
assert "hookEventName=UserPromptSubmit" "UserPromptSubmit" "$EVT"

# --- Case 3: Kaputtes _pending.json → silent fail, keine Exception ---
echo 'not json at all' > "$SANDBOX/wiki/_pending.json"
OUT=$(run_in_sandbox "$JSON")
RC=$?
assert "broken pending → still exit 0" "0" "$RC"

rm -rf "$SANDBOX"
echo ""
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2.2: Test ausfuehren → MUSS scheitern**

```bash
bash tests/test-inject-lock-warning.sh
```

Expected: Alle FAIL (Hook existiert nicht).

- [ ] **Step 2.3: Hook D schreiben**

Datei: `plugin/hooks/inject-lock-warning.sh`

```bash
#!/usr/bin/env bash
# inject-lock-warning.sh — UserPromptSubmit Hook
# Wenn wiki/_pending.json existiert: injiziere Lock-Hinweis als additionalContext.
# Blockiert nie. Exit 0 immer.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PENDING="${PROJECT_DIR}/wiki/_pending.json"

# Kein Lock? Silent.
if [ ! -f "$PENDING" ]; then
  exit 0
fi

# Lock lesen — defensiv, bei kaputtem JSON exit 0 ohne Output
QUELLE=$(jq -r '.quelle // "unbekannt"' "$PENDING" 2>/dev/null || echo "")
STUFE=$(jq -r '.stufe // "unbekannt"' "$PENDING" 2>/dev/null || echo "")

if [ -z "$QUELLE" ] || [ -z "$STUFE" ]; then
  # Kaputtes JSON — nicht crashen, einfach schweigen
  exit 0
fi

# additionalContext zurueckgeben
jq -n --arg q "$QUELLE" --arg s "$STUFE" '
{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: ("⚠️ Pipeline-Lock offen: Quelle=" + $q + ", Stufe=" + $s + ". Bevor du einen neuen Ingest startest, schliesse die offenen Gates bzw. Nebeneffekte fuer diese Quelle ab.")
  }
}'

exit 0
```

- [ ] **Step 2.4: Ausfuehrbar machen**

```bash
chmod +x plugin/hooks/inject-lock-warning.sh
```

- [ ] **Step 2.5: Test ausfuehren → MUSS gruen sein**

```bash
bash tests/test-inject-lock-warning.sh
```

Expected: `Ergebnis: 7 passed, 0 failed`

- [ ] **Step 2.6: Commit**

```bash
git add plugin/hooks/inject-lock-warning.sh tests/test-inject-lock-warning.sh
git commit -m "feat: Hook D inject-lock-warning.sh — UserPromptSubmit Lock-Hinweis

Passive Warnung: wenn wiki/_pending.json existiert, wird Lock-Info
als additionalContext in den naechsten User-Prompt injiziert.
Blockiert nie. 7/7 Tests gruen."
```

---

### Task 3: Hook-Registrierung in hooks.json

**Files:**
- Modify: `plugin/hooks/hooks.json`

- [ ] **Step 3.1: Aktuelles `hooks.json` lesen und verstehen**

```bash
cat plugin/hooks/hooks.json
```

Expected: Nur `SessionStart`-Hook aktiv (3 Objekte tief).

- [ ] **Step 3.2: `hooks.json` erweitern**

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

- [ ] **Step 3.3: JSON-Syntax verifizieren**

```bash
jq . plugin/hooks/hooks.json >/dev/null && echo "JSON ok"
```

Expected: `JSON ok`

- [ ] **Step 3.4: Commit**

```bash
git add plugin/hooks/hooks.json
git commit -m "feat: Hook A + D in hooks.json registriert

PreToolUse Edit|Write -> guard-wiki-writes.sh
UserPromptSubmit -> inject-lock-warning.sh
SessionStart unveraendert."
```

---

### Task 4: Cleanup — alten Hook entfernen

**Files:**
- Delete: `plugin/hooks/check-wiki-write.sh`
- Delete: `tests/test-wiki-write-hook.sh` (wenn vorhanden und fuer alten Hook)

- [ ] **Step 4.1: Pruefen was an alten Tests existiert**

```bash
ls tests/ | grep -E "write|pending"
```

- [ ] **Step 4.2: `check-wiki-write.sh` loeschen**

```bash
git rm plugin/hooks/check-wiki-write.sh
```

- [ ] **Step 4.3: Alte Tests pruefen und ggf. entfernen**

Wenn `tests/test-wiki-write-hook.sh` nur den alten Hook testet: loeschen.
Wenn er Teile testet die noch relevant sind: auf neuen Hook umschreiben.

```bash
# Inspektion
head -30 tests/test-wiki-write-hook.sh
```

Entscheidung hier im Step dokumentieren. Default: loeschen wenn `check-wiki-write.sh` der Test-Target war.

```bash
git rm tests/test-wiki-write-hook.sh
```

- [ ] **Step 4.4: Commit**

```bash
git commit -m "chore: Alten check-wiki-write.sh + Tests entfernt

Ersetzt durch guard-wiki-writes.sh (SPEC-001). Das alte Script war
PostToolUse-registriert und nutzte veraltetes JSON-Schema
({\"decision\":\"block\"}), was in jedem Call 'JSON validation failed'
produzierte. Deaktiviert in 12e8a3c, jetzt komplett geloescht."
```

---

### Task 5: CLAUDE.md aktualisieren

**Files:**
- Modify: `CLAUDE.md` (Projekt-Root)

- [ ] **Step 5.1: Aktuelle Enforcement-Sektion lesen**

```bash
grep -n "Enforcement" CLAUDE.md
```

- [ ] **Step 5.2: Text im Abschnitt "Enforcement — 3 Schichten" pruefen**

Der Abschnitt behauptet aktuell 3 Schichten (Prompt-Law + Subagent-Review + Machine-Law). Nach SPEC-001 ist Machine-Law nur **teilweise** wieder da (Schreibschutz + Lock-Warning), aber noch **nicht** Pipeline-Lock-Enforcement — das kommt in SPEC-002.

- [ ] **Step 5.3: Text ehrlich formulieren**

Alter Text-Block (beispielhaft):
```
## Enforcement — 3 Schichten
1. Prompt-Law — Skill-Anweisungen, Hard Gates, Dispatch-Templates
2. Subagent-Review — 4 Pruefer + 2 Reviewer + 1 Validator
3. Machine-Law — PostToolUse-Hook + PreToolUse-Hook (Pipeline-Lock)
```

Neu:
```
## Enforcement — 3 Schichten

1. **Prompt-Law** — Skill-Anweisungen, Hard Gates, Dispatch-Templates
2. **Subagent-Review** — 4 Pruefer (Ingest) + 2 Reviewer (Synthese) + 1 Validator
3. **Machine-Law (teilweise):**
   - `guard-wiki-writes.sh` (PreToolUse Edit|Write): blockiert Wiki-Writes ausserhalb von /ingest, /synthese, /normenupdate, /vokabular
   - `inject-lock-warning.sh` (UserPromptSubmit): passive Warnung wenn _pending.json offen
   - `check-wiki-output.sh`: wird von Gate-Agents selbst aufgerufen (siehe Commit f7b08d7)
   - **Noch ausstehend:** mechanische Pipeline-Lock-Enforcement (siehe SPEC-002)

Heuristische Checks (04 Zahlenwerte, 05 Normbezuege, 06 Seitenangaben, 09 Umlaute)
sind WARN im Shell-Script. Die echte Pruefung macht der quellen-pruefer Agent (Gate 2).
```

- [ ] **Step 5.4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md Enforcement-Sektion nach SPEC-001 aktualisiert"
```

---

### Task 6: End-to-End-Test in frischer Session

**Files:** Keine

- [ ] **Step 6.1: Claude-Code-Session komplett neu starten**

Grund: Hooks werden im RAM gecached. Ohne Neustart greifen die neuen Hooks nicht.

```bash
# Im Terminal:
exit  # aus aktueller Session
claude-code  # neue Session im llm-wiki Repo
```

- [ ] **Step 6.2: Test 1 — Manueller Write ohne Skill MUSS blockiert werden**

In der neuen Session:
```
Schreibe "test" in wiki/quellen/_hook-test.md
```

Expected: Claude versucht Write, Hook blockt mit der Meldung "WIKI-GATE: Direkte Wiki-Writes sind nicht erlaubt."

- [ ] **Step 6.3: Test 2 — Schreiben ausserhalb wiki/ MUSS gehen**

```
Schreibe "test" in /tmp/foo.md
```

Expected: Geht durch, keine Hook-Meldung.

- [ ] **Step 6.4: Test 3 — /ingest laden, dann Wiki-Write MUSS gehen**

```
/ingest
[dann Abbruch nach Phase 0]
Schreibe "test" in wiki/konzepte/_hook-test.md
```

Expected: Nach Skill-Load klappt der Write ohne Hook-Meldung.

- [ ] **Step 6.5: Test 4 — _pending.json anlegen, dann User-Prompt → Kontext-Injection**

```bash
# In anderem Terminal:
echo '{"typ":"ingest","stufe":"gates","quelle":"test-quelle","timestamp":"2026-04-10T12:00:00Z"}' > wiki/_pending.json
```

Dann im Chat einen neuen Prompt eingeben. In der Claude-Antwort oder im Debug-Log muss der Lock-Hinweis auftauchen.

```bash
rm wiki/_pending.json  # Cleanup
```

- [ ] **Step 6.6: Ergebnisse im Spec-Status dokumentieren**

Oben im SPEC: `**Status:** Done`.

- [ ] **Step 6.7: Commit**

```bash
git add docs/specs/SPEC-001-passive-hooks.md docs/specs/INDEX.md
git commit -m "docs: SPEC-001 als Done markiert — Hook A + D live getestet"
```

---

## Abschluss-Checkliste

Nach Task 6 kompletter Status:

- [ ] 2 neue Hooks aktiv (Hook A + Hook D)
- [ ] 2 neue Test-Dateien, alle Cases gruen
- [ ] Alter `check-wiki-write.sh` geloescht
- [ ] `hooks.json` registriert beide Hooks korrekt
- [ ] `CLAUDE.md` reflektiert den neuen Stand ehrlich
- [ ] Manueller End-to-End-Test in frischer Session erfolgreich
- [ ] SPEC-001 Status: Done
- [ ] INDEX.md aktualisiert

**Dauer:** 1-2 Stunden bei sauberem Durchlauf. Session-Restart-Zyklen koennen das auf 3 Stunden dehnen wenn Hooks nach Registrierung erst debuggt werden muessen.
