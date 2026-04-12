# Auto-Pipeline-Lock (SPEC-002 v2.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Schließe die Enforcement-Lücke, bei der Gate-Agents nach einem Ingest-Worker übersprungen werden können, indem ein SubagentStop-Hook automatisch `_pending.json` anlegt.

**Architecture:** Neuer Hook `create-pipeline-lock.sh` auf SubagentStop für `bibliothek:(ingest|synthese)-worker`. Er erzeugt `_pending.json` mechanisch nach Worker-Ende, sodass `guard-pipeline-lock.sh` den nächsten Dispatch blockiert — auch wenn der Orchestrator Phase 3 überspringt. Worker-Templates erhalten einen `[INGEST-ID:xxx]`-Marker für zuverlässige `quelle`-Extraktion.

**Tech Stack:** Bash (`set -euo pipefail`), `jq`, Claude Code Hooks API 2026 (SubagentStop-Event).

---

## Hintergrund: Die Lücke

SPEC-002 v1.0 hat mechanische Blockade für den *nächsten* Ingest-Dispatch gebaut (`guard-pipeline-lock.sh`). Aber `_pending.json` wird vom Orchestrator in Phase 3 angelegt — **nach** dem Worker-Return. Wenn der Orchestrator Phase 3 überspringt, existiert `_pending.json` nie, und die gesamte Machine-Law-Kette ist wirkungslos:

```
Worker done → [LÜCKE — kein Hook] → Orchestrator soll _pending.json anlegen → Gates dispatchen
                                          ↑
                                    Hier übersprungen (Session 2026-04-13)
```

**Fix:** SubagentStop auf Worker-Agents → Hook erstellt `_pending.json` automatisch.

## Dateistruktur

| Aktion | Datei | Verantwortung |
|--------|-------|---------------|
| **Neu** | `plugin/hooks/create-pipeline-lock.sh` | SubagentStop-Hook: erzeugt `_pending.json` nach Worker-Ende |
| **Neu** | `tests/test-create-pipeline-lock.sh` | Unit-Tests für den neuen Hook |
| Modify | `plugin/hooks/hooks.json` | SubagentStop-Matcher für Worker registrieren |
| Modify | `plugin/governance/ingest-dispatch-template.md` | `[INGEST-ID:...]`-Marker im Prompt |
| Modify | `plugin/governance/synthese-dispatch-template.md` | Explizite Echo-Anweisung für `[SYNTHESE-ID:...]` |
| Modify | `plugin/skills/ingest/SKILL.md` | Phase 3 Step 1: "verify" statt "create" |
| Modify | `CLAUDE.md` | Neuen Hook dokumentieren |
| Modify | `docs/specs/SPEC-002-pipeline-lock-enforcement.md` | v2.0 mit neuem Akzeptanzkriterium |
| Modify | `docs/specs/INDEX.md` | Version aktualisieren |
| Modify | `tests/test-integration-pipeline.sh` | Lifecycle-Tests für Worker-Stop → Auto-Lock |

---

### Task 1: SPEC-002 auf v2.0 aktualisieren

**Files:**
- Modify: `docs/specs/SPEC-002-pipeline-lock-enforcement.md:1-10` (Header)
- Modify: `docs/specs/SPEC-002-pipeline-lock-enforcement.md:256-278` (Akzeptanzkriterien + Edge Cases)
- Modify: `docs/specs/INDEX.md:12`

- [ ] **Step 1: SPEC-002 Header aktualisieren**

```markdown
**Status:** In Progress
**Version:** 2.0
**Aktualisiert:** 2026-04-13
```

Zusammenfassung ergänzen — neuen Absatz nach dem bestehenden Text:

```markdown
### v2.0: Auto-Pipeline-Lock (2026-04-13)

In Session 2026-04-13 hat der Orchestrator nach einem Ingest-Worker-Return Phase 3
(Gate-Dispatch) übersprungen und direkt zum nächsten Ingest gewollt. Die Machine-Law
hat nicht gegriffen weil `_pending.json` nie angelegt wurde — die gesamte Enforcement-Kette
hängt an einer Datei die der LLM-Orchestrator erstellen soll.

**Fix:** Neuer Hook `create-pipeline-lock.sh` auf SubagentStop für Worker-Agents.
Erzeugt `_pending.json` mechanisch nach Worker-Ende. Damit blockiert `guard-pipeline-lock.sh`
den nächsten Dispatch auch wenn der Orchestrator Phase 3 überspringt.
```

- [ ] **Step 2: Neue Akzeptanzkriterien hinzufügen**

Nach den bestehenden Kriterien:

```markdown
- [ ] `plugin/hooks/create-pipeline-lock.sh` existiert, `jq`-basiert, `set -euo pipefail`
- [ ] hooks.json: SubagentStop-Matcher für `bibliothek:(ingest|synthese)-worker` registriert
- [ ] `ingest-dispatch-template.md` enthält `[INGEST-ID:{{QUELLENSEITE_DATEI}}]` im Prompt
- [ ] `tests/test-create-pipeline-lock.sh`: alle Cases grün
- [ ] Integration-Test: Worker-Stop → `_pending.json` entsteht automatisch → zweiter Dispatch blockiert
- [ ] SKILL.md Phase 3 Step 1: "verify" statt "create"
```

- [ ] **Step 3: INDEX.md aktualisieren**

```markdown
| [SPEC-002](SPEC-002-pipeline-lock-enforcement.md) | Aktive Pipeline-Lock-Enforcement + Auto-Lock nach Worker-Stop | In Progress | 2.0 | 2026-04-13 |
```

- [ ] **Step 4: Commit**

```bash
git add docs/specs/SPEC-002-pipeline-lock-enforcement.md docs/specs/INDEX.md
git commit -m "$(cat <<'EOF'
docs: SPEC-002 v2.0 — Auto-Pipeline-Lock nach Worker-Stop

Dokumentiert die Enforcement-Lücke (Session 2026-04-13) und das Fix-Design:
SubagentStop-Hook auf Worker-Agents erzeugt _pending.json automatisch.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Unit-Tests für create-pipeline-lock.sh (TDD Red Phase)

**Files:**
- Create: `tests/test-create-pipeline-lock.sh`

- [ ] **Step 1: Test-Datei schreiben**

```bash
#!/usr/bin/env bash
# Tests fuer create-pipeline-lock.sh (Hook E)
set -uo pipefail

HOOK="$(dirname "$0")/../plugin/hooks/create-pipeline-lock.sh"
PASS=0; FAIL=0

assert() {
  if [ "$2" = "$3" ]; then
    echo "  PASS: $1"; PASS=$((PASS+1))
  else
    echo "  FAIL: $1 — expected=$2 actual=$3"; FAIL=$((FAIL+1))
  fi
}

assert_json() {
  local name="$1" field="$2" expected="$3" file="$4"
  local actual
  actual=$(jq -r "$field" "$file" 2>/dev/null || echo "PARSE_ERROR")
  assert "$name" "$expected" "$actual"
}

SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/wiki"
PENDING="$SANDBOX/wiki/_pending.json"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

run_hook() {
  echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK" 2>/dev/null
  return $?
}

echo "╔══════════════════════���═══════════════════╗"
echo "║  Tests: create-pipeline-lock.sh (Hook E)  ║"
echo "╚══════════════════════════════════════════╝"

# --- Case 1: Nicht-Worker SubagentStop → exit 0, kein _pending.json ---
echo ""
echo "━━━ Case 1: Nicht-Worker Agent ━━━"
JSON_GATE='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"Gate 1 done"}'
run_hook "$JSON_GATE"
assert "non-worker → exit 0" "0" "$?"
assert "non-worker → kein _pending.json" "false" "$([ -f "$PENDING" ] && echo true || echo false)"

# --- Case 2: Ingest-Worker Stop → _pending.json mit typ=ingest, gates_total=4 ---
echo ""
echo "━━━ Case 2: Ingest-Worker Stop ━━━"
JSON_INGEST='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":"Ingest abgeschlossen. [INGEST-ID:schaenzlin-langzeitverhalten-2003]"}'
run_hook "$JSON_INGEST"
assert "ingest-worker → exit 0" "0" "$?"
assert "ingest-worker → _pending.json existiert" "true" "$([ -f "$PENDING" ] && echo true || echo false)"
assert_json "typ = ingest" ".typ" "ingest" "$PENDING"
assert_json "stufe = gates" ".stufe" "gates" "$PENDING"
assert_json "quelle extrahiert" ".quelle" "schaenzlin-langzeitverhalten-2003" "$PENDING"
assert_json "gates_passed = 0" ".gates_passed" "0" "$PENDING"
assert_json "gates_total = 4" ".gates_total" "4" "$PENDING"
# Timestamp vorhanden
TS=$(jq -r '.timestamp // empty' "$PENDING" 2>/dev/null)
assert "timestamp vorhanden" "true" "$([ -n "$TS" ] && echo true || echo false)"
rm -f "$PENDING"

# --- Case 3: Synthese-Worker Stop → _pending.json mit typ=synthese, gates_total=3 ---
echo ""
echo "━━━ Case 3: Synthese-Worker Stop ━━━"
JSON_SYNTHESE='{"agent_type":"bibliothek:synthese-worker","hook_event_name":"SubagentStop","last_assistant_message":"Synthese fertig. [SYNTHESE-ID:querkraft]"}'
run_hook "$JSON_SYNTHESE"
assert "synthese-worker → exit 0" "0" "$?"
assert_json "typ = synthese" ".typ" "synthese" "$PENDING"
assert_json "gates_total = 3" ".gates_total" "3" "$PENDING"
assert_json "quelle = querkraft" ".quelle" "querkraft" "$PENDING"
rm -f "$PENDING"

# --- Case 4: _pending.json existiert bereits → kein Überschreiben ---
echo ""
echo "━━━ Case 4: Bestehende _pending.json ━━━"
echo '{"typ":"ingest","stufe":"sideeffects","quelle":"altes-buch","gates_passed":4,"gates_total":4}' > "$PENDING"
run_hook "$JSON_INGEST"
assert "bestehende lock → exit 0" "0" "$?"
assert_json "quelle unverändert" ".quelle" "altes-buch" "$PENDING"
assert_json "stufe unverändert" ".stufe" "sideeffects" "$PENDING"
rm -f "$PENDING"

# --- Case 5: Worker-Output ohne ID-Marker → quelle = "unbekannt" ---
echo ""
echo "━━━ Case 5: Kein ID-Marker im Output ━━━"
JSON_NO_ID='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":"Ingest fertig. Keine ID."}'
run_hook "$JSON_NO_ID"
assert "kein marker → exit 0" "0" "$?"
assert_json "quelle = unbekannt (fallback)" ".quelle" "unbekannt" "$PENDING"
assert_json "typ = ingest (trotzdem korrekt)" ".typ" "ingest" "$PENDING"
rm -f "$PENDING"

# --- Case 6: Leerer last_assistant_message → quelle = "unbekannt" ---
echo ""
echo "━━━ Case 6: Leere Message ━━━"
JSON_EMPTY_MSG='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":""}'
run_hook "$JSON_EMPTY_MSG"
assert "leere message → exit 0" "0" "$?"
assert_json "quelle = unbekannt" ".quelle" "unbekannt" "$PENDING"
rm -f "$PENDING"

# --- Case 7: Fehlender last_assistant_message key → quelle = "unbekannt" ---
echo ""
echo "━━━ Case 7: Fehlender Message-Key ━━━"
JSON_NO_MSG='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop"}'
run_hook "$JSON_NO_MSG"
assert "fehlender key → exit 0" "0" "$?"
assert_json "quelle = unbekannt" ".quelle" "unbekannt" "$PENDING"
rm -f "$PENDING"

# --- Case 8: INGEST-ID mit .md Suffix → .md wird gestripped ---
echo ""
echo "━━━ Case 8: ID mit .md Suffix ━━━"
JSON_MD='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":"[INGEST-ID:fingerloos-ec2-2016.md] Done"}'
run_hook "$JSON_MD"
assert "md suffix → exit 0" "0" "$?"
assert_json "quelle ohne .md" ".quelle" "fingerloos-ec2-2016" "$PENDING"
rm -f "$PENDING"

# --- Case 9: Nicht-existentes wiki-Verzeichnis → exit 0, kein Crash ---
echo ""
echo "━━━ Case 9: Kein wiki/ Verzeichnis ━━━"
SANDBOX_EMPTY=$(mktemp -d)
JSON_NO_WIKI='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":"[INGEST-ID:test]"}'
echo "$JSON_NO_WIKI" | CLAUDE_PROJECT_DIR="$SANDBOX_EMPTY" bash "$HOOK" 2>/dev/null
assert "kein wiki/ → exit 0" "0" "$?"
assert "kein _pending.json angelegt" "false" "$([ -f "$SANDBOX_EMPTY/wiki/_pending.json" ] && echo true || echo false)"
rm -rf "$SANDBOX_EMPTY"

# --- Case 10: Allgemeiner (nicht-bibliothek) Agent → ignoriert ---
echo ""
echo "━━━ Case 10: General-Purpose Agent ━━━"
JSON_GP='{"agent_type":"general-purpose","hook_event_name":"SubagentStop","last_assistant_message":"Done"}'
run_hook "$JSON_GP"
assert "general-purpose → exit 0" "0" "$?"
assert "general-purpose → kein _pending.json" "false" "$([ -f "$PENDING" ] && echo true || echo false)"

echo ""
echo "════════════════════════════════"
echo "Ergebnis: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Tests ausführen — verifiziere dass sie failen**

Run: `bash tests/test-create-pipeline-lock.sh`
Expected: Fehler weil `create-pipeline-lock.sh` noch nicht existiert.

- [ ] **Step 3: Commit Test-Datei**

```bash
git add tests/test-create-pipeline-lock.sh
git commit -m "$(cat <<'EOF'
test: unit tests fuer create-pipeline-lock.sh (TDD red phase)

10 Cases: Worker-Stop → auto-lock, Nicht-Worker ignoriert,
bestehender Lock nicht ueberschrieben, ID-Extraktion, Fallbacks.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: create-pipeline-lock.sh implementieren (TDD Green Phase)

**Files:**
- Create: `plugin/hooks/create-pipeline-lock.sh`

- [ ] **Step 1: Hook implementieren**

```bash
#!/usr/bin/env bash
# create-pipeline-lock.sh — SubagentStop Hook fuer Pipeline-Worker
# Erzeugt wiki/_pending.json automatisch nach Worker-Ende.
# Schliesst die Enforcement-Luecke: auch wenn der Orchestrator Phase 3
# ueberspringt, blockiert guard-pipeline-lock.sh den naechsten Dispatch.
#
# Blockiert nie. Exit 0 immer.

set -euo pipefail

INPUT=$(cat)

AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null || echo "")

# Nur Pipeline-Worker betrachten
case "$AGENT_TYPE" in
  bibliothek:ingest-worker)  TYP="ingest";  GATES_TOTAL=4 ;;
  bibliothek:synthese-worker) TYP="synthese"; GATES_TOTAL=3 ;;
  *) exit 0 ;;
esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
WIKI_DIR="${PROJECT_DIR}/wiki"
PENDING="${WIKI_DIR}/_pending.json"

# Kein wiki/ Verzeichnis → nichts tun (Bootstrap noch nicht gelaufen)
if [ ! -d "$WIKI_DIR" ]; then
  exit 0
fi

# Lock existiert bereits → nicht ueberschreiben (defensiv)
if [ -f "$PENDING" ]; then
  exit 0
fi

# Quelle aus Worker-Output extrahieren: [INGEST-ID:xxx] oder [SYNTHESE-ID:xxx]
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")
QUELLE=""

if [ -n "$LAST_MSG" ]; then
  QUELLE=$(echo "$LAST_MSG" | grep -oE '\[(INGEST|SYNTHESE)-ID:[^]]+\]' | head -1 | sed 's/\[.*-ID://;s/\]//' || echo "")
  # .md Suffix entfernen falls vorhanden
  QUELLE="${QUELLE%.md}"
fi

# Fallback wenn kein Marker gefunden
if [ -z "$QUELLE" ]; then
  QUELLE="unbekannt"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -n \
  --arg typ "$TYP" \
  --arg quelle "$QUELLE" \
  --arg ts "$TIMESTAMP" \
  --argjson total "$GATES_TOTAL" \
  '{typ: $typ, stufe: "gates", quelle: $quelle, timestamp: $ts, gates_passed: 0, gates_total: $total}' \
  > "$PENDING"

exit 0
```

- [ ] **Step 2: Ausführbar machen**

Run: `chmod +x plugin/hooks/create-pipeline-lock.sh`

- [ ] **Step 3: Tests ausführen — verifiziere dass alle PASS**

Run: `bash tests/test-create-pipeline-lock.sh`
Expected: Alle 10 Cases PASS (ca. 25 Assertions).

- [ ] **Step 4: Commit**

```bash
git add plugin/hooks/create-pipeline-lock.sh
git commit -m "$(cat <<'EOF'
feat: create-pipeline-lock.sh — auto-lock nach Worker-Stop

SubagentStop-Hook fuer bibliothek:ingest-worker und synthese-worker.
Erzeugt _pending.json automatisch, schliesst die Phase-3-Luecke.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: hooks.json registrieren

**Files:**
- Modify: `plugin/hooks/hooks.json:37-48` (SubagentStop-Array erweitern)

- [ ] **Step 1: Neuen SubagentStop-Eintrag hinzufügen**

Zwischen dem bestehenden SubagentStop-Eintrag (Gate-Agents) und der schließenden `]` einen zweiten Eintrag einfügen:

```json
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
      },
      {
        "matcher": "bibliothek:(ingest|synthese)-worker",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/create-pipeline-lock.sh\"",
            "timeout": 10
          }
        ]
      }
    ],
```

**Wichtig:** Der Worker-Matcher MUSS NACH dem Gate-Matcher stehen, damit die Reihenfolge der SubagentStop-Verarbeitung klar ist (erst Gates → dann Worker). In der Praxis matcht pro Event nur einer (Worker-Type ≠ Gate-Type), aber die Lesereihenfolge dokumentiert die Absicht.

- [ ] **Step 2: JSON-Validierung**

Run: `jq . plugin/hooks/hooks.json > /dev/null && echo "Valid JSON"`
Expected: "Valid JSON"

- [ ] **Step 3: Consistency-Check**

Run: `bash plugin/hooks/check-consistency.sh plugin/`
Expected: 19/19 PASS (oder angepasste Zahl falls check-consistency.sh den neuen Hook prüft)

- [ ] **Step 4: Commit**

```bash
git add plugin/hooks/hooks.json
git commit -m "$(cat <<'EOF'
feat: hooks.json — SubagentStop fuer Worker-Agents registriert

create-pipeline-lock.sh feuert auf bibliothek:(ingest|synthese)-worker.
Ergaenzt den bestehenden advance-pipeline-lock.sh (Gate-Agents).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Worker-Templates aktualisieren

**Files:**
- Modify: `plugin/governance/ingest-dispatch-template.md:37-50` (KONTEXT-Sektion)
- Modify: `plugin/governance/synthese-dispatch-template.md:260-275` (SELBST-CHECK-Sektion)

- [ ] **Step 1: INGEST-ID-Marker in ingest-dispatch-template einfügen**

Im Prompt-Template, KONTEXT-Sektion, nach der Zeile `Quellenseite: {{QUELLENSEITE_DATEI}}`:

```
PDF-Datei:          {{PDF_PFAD}}
Wiki-Verzeichnis:   {{WIKI_ROOT}}
Quellenseite:       {{QUELLENSEITE_DATEI}}

[INGEST-ID:{{QUELLENSEITE_DATEI}}]
```

Und am Ende des Templates, nach dem SELBST-CHECK-Block, vor dem schließenden ` ``` `:

```
═══════════════════════════════════════════════════════
PIPELINE-ID (PFLICHT — fuer Hook-Matching)
═══════════════════════════════════════════════════════

Gib am Ende deines Ergebnis-Berichts diese Zeile zurueck:
[INGEST-ID:{{QUELLENSEITE_DATEI}}]
```

- [ ] **Step 2: SYNTHESE-ID-Echo-Anweisung in synthese-dispatch-template ergänzen**

Der Marker `[SYNTHESE-ID:{{KONZEPT_NAME}}]` existiert bereits in Zeile 42. Ergänze am Ende des Templates (nach SELBST-CHECK, vor schließendem ` ``` `):

```
═══════════════════════════════════════════════════════
PIPELINE-ID (PFLICHT — fuer Hook-Matching)
═══════════════════════════════════════════════════════

Gib am Ende deines Ergebnis-Berichts diese Zeile zurueck:
[SYNTHESE-ID:{{KONZEPT_NAME}}]
```

- [ ] **Step 3: Commit**

```bash
git add plugin/governance/ingest-dispatch-template.md plugin/governance/synthese-dispatch-template.md
git commit -m "$(cat <<'EOF'
feat: Pipeline-ID-Marker in Worker-Templates

Ingest: [INGEST-ID:{{QUELLENSEITE_DATEI}}] im Prompt + Echo-Anweisung.
Synthese: Echo-Anweisung fuer bestehenden [SYNTHESE-ID:...]-Marker.
create-pipeline-lock.sh extrahiert die ID aus last_assistant_message.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Ingest-SKILL.md Phase 3 aktualisieren

**Files:**
- Modify: `plugin/skills/ingest/SKILL.md:255-278` (Phase 3 Checkliste)

- [ ] **Step 1: Phase 3 Step 1 ändern**

Ersetze in der Phase 3 Checkliste den bestehenden Step 1:

Vorher:
```markdown
1. **Pipeline-Lock anlegen** — Schreibe `wiki/_pending.json`:
   ```json
   {"typ":"ingest","stufe":"gates","quelle":"<kurzname>","timestamp":"<ISO-8601>","gates_passed":0,"gates_total":4}
   ```
   ERST hier, NICHT in Phase 0.4 — sonst blockiert guard-pipeline-lock.sh den eigenen
   ersten Ingest-Dispatch.
```

Nachher:
```markdown
1. **Pipeline-Lock verifizieren** — `wiki/_pending.json` wurde automatisch durch
   `create-pipeline-lock.sh` (SubagentStop-Hook) angelegt. Verifiziere:
   - Datei existiert
   - `quelle` stimmt mit der Quellenseite überein
   - Falls die Datei NICHT existiert (Hook-Fehler): manuell anlegen wie bisher:
     ```json
     {"typ":"ingest","stufe":"gates","quelle":"<kurzname>","timestamp":"<ISO-8601>","gates_passed":0,"gates_total":4}
     ```
```

- [ ] **Step 2: Phase 3 Step 4 aktualisieren**

Ersetze den bestehenden Step 4:

Vorher:
```markdown
4. Fuelle `{{PIPELINE_ID_MARKER}}` mit `[INGEST-ID:<kurzname>]`
   (gleicher Kurzname wie in _pending.json.quelle — advance-pipeline-lock.sh
   verifiziert den Marker und ignoriert Gate-Stops die nicht zur Pipeline gehoeren)
```

Nachher:
```markdown
4. Lese `_pending.json` → verwende `.quelle` als `{{PIPELINE_ID_MARKER}}`:
   `[INGEST-ID:<_pending.json.quelle>]`
   (advance-pipeline-lock.sh verifiziert den Marker gegen _pending.json.quelle)
```

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/ingest/SKILL.md
git commit -m "$(cat <<'EOF'
refactor: SKILL.md Phase 3 — _pending.json wird jetzt vom Hook angelegt

Step 1: "verify" statt "create" — create-pipeline-lock.sh uebernimmt.
Step 4: quelle aus _pending.json lesen statt frei waehlen.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: CLAUDE.md aktualisieren

**Files:**
- Modify: `CLAUDE.md` (Machine-Law-Sektion und Troubleshooting)

- [ ] **Step 1: Neuen Hook in Machine-Law-Liste dokumentieren**

Im Abschnitt `## Enforcement — 3 Schichten`, nach dem `advance-pipeline-lock.sh`-Eintrag:

```markdown
   - `create-pipeline-lock.sh` (SubagentStop auf Worker-Agents) — erzeugt `wiki/_pending.json`
     automatisch nach Ingest-/Synthese-Worker-Ende. Extrahiert quelle aus `[INGEST-ID:xxx]` /
     `[SYNTHESE-ID:xxx]` im Worker-Output. Überschreibt bestehende Locks nicht.
```

- [ ] **Step 2: Pflicht-Checkliste erweitern**

Im Abschnitt `## Entwicklung`, nach der bestehenden Test-Checkliste:

```bash
bash tests/test-create-pipeline-lock.sh         # NN/NN PASS?
```

(Exakte Anzahl wird nach Task 2 bekannt.)

- [ ] **Step 3: Troubleshooting ergänzen**

Neuer Abschnitt nach dem bestehenden Troubleshooting:

```markdown
### Worker-Stop erzeugt _pending.json nicht (Hook-Fehler)

Pruefe:
1. hooks.json hat SubagentStop-Matcher fuer `bibliothek:(ingest|synthese)-worker`
2. `create-pipeline-lock.sh` ist ausfuehrbar: `ls -la plugin/hooks/create-pipeline-lock.sh`
3. `wiki/` Verzeichnis existiert (Bootstrap gelaufen?)
4. Manuell anlegen: `echo '{"typ":"ingest","stufe":"gates","quelle":"...","timestamp":"...","gates_passed":0,"gates_total":4}' > wiki/_pending.json`
```

- [ ] **Step 4: CLAUDE.md NICHT-in-Phase-0.6-Kommentar aktualisieren**

Im Abschnitt `## Pipeline-Lock`, den Satz aktualisieren:

Vorher:
```
`_pending.json` wird in Phase 3 (nach Worker-Rueckkehr, vor Gate-Dispatch) angelegt
```

Nachher:
```
`_pending.json` wird automatisch durch `create-pipeline-lock.sh` (SubagentStop-Hook)
nach Worker-Rueckkehr angelegt. Phase 3 verifiziert die Datei und dispatcht die Gates.
```

- [ ] **Step 5: Hard-Gates-Inline-Kopie prüfen**

Run: `diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' plugin/skills/using-bibliothek/SKILL.md | sed '1d;$d') plugin/governance/hard-gates.md`
Expected: Keine Diff (keine Änderung an Hard Gates nötig — die Gates selbst ändern sich nicht, nur der Lock-Mechanismus).

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: CLAUDE.md — create-pipeline-lock.sh dokumentiert

Machine-Law-Liste, Pflicht-Checkliste, Troubleshooting,
Pipeline-Lock-Beschreibung aktualisiert.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Integration-Tests erweitern

**Files:**
- Modify: `tests/test-integration-pipeline.sh` (neue Phase nach bestehenden Phasen)

- [ ] **Step 1: Hook-E Runner und JSON-Bausteine hinzufügen**

Am Anfang der Datei, bei den Hilfsfunktionen (nach `run_lock_warning`):

```bash
HOOK_E="$PLUGIN_DIR/hooks/create-pipeline-lock.sh"

run_create_lock() {
  echo "$1" | CLAUDE_PROJECT_DIR="$SANDBOX" bash "$HOOK_E" 2>/dev/null
  return $?
}
```

Bei den JSON-Bausteinen:

```bash
WORKER_INGEST_STOP='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":"Ingest fertig. [INGEST-ID:test-buch-ec2]"}'
WORKER_SYNTHESE_STOP='{"agent_type":"bibliothek:synthese-worker","hook_event_name":"SubagentStop","last_assistant_message":"Synthese fertig. [SYNTHESE-ID:querkraft-synthese]"}'
WORKER_INGEST_NO_ID='{"agent_type":"bibliothek:ingest-worker","hook_event_name":"SubagentStop","last_assistant_message":"Ingest fertig ohne Marker."}'
```

- [ ] **Step 2: Neue Phase hinzufügen — "Auto-Lock nach Worker-Stop"**

Am Ende der Datei, vor dem Ergebnis-Block:

```bash
# ============================================================
# PHASE 12: Auto-Lock nach Worker-Stop (Hook E)
# ============================================================

section "Phase 12: Auto-Lock — create-pipeline-lock.sh"
rm -f "$PENDING"

# 12a: Ingest-Worker-Stop → _pending.json entsteht automatisch
run_create_lock "$WORKER_INGEST_STOP"
assert "E: Ingest-Worker-Stop → exit 0" "0" "$?"
assert "E: _pending.json existiert" "true" "$([ -f "$PENDING" ] && echo true || echo false)"
TYP_12=$(jq -r '.typ' "$PENDING" 2>/dev/null || echo "")
assert "E: typ = ingest" "ingest" "$TYP_12"
QUELLE_12=$(jq -r '.quelle' "$PENDING" 2>/dev/null || echo "")
assert "E: quelle = test-buch-ec2" "test-buch-ec2" "$QUELLE_12"

# 12b: Nach Auto-Lock → guard-pipeline-lock blockiert naechsten Ingest
run_pipeline_guard "$AGENT_INGEST"
assert "B+E: Auto-Lock → naechster Ingest blockiert" "2" "$?"

# 12c: inject-lock-warning zeigt Auto-Lock
OUT_12C=$(run_lock_warning "$PROMPT_SUBMIT")
assert_contains "D+E: Lock-Warning zeigt Auto-Lock-Quelle" "test-buch-ec2" "$OUT_12C"

# 12d: Gate-Advancement funktioniert auf Auto-Lock
for i in 1 2 3 4; do
  GATE_12='{"agent_type":"bibliothek:vollstaendigkeits-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"[INGEST-ID:test-buch-ec2] PASS"}'
  run_advance "$GATE_12"
done
STUFE_12=$(jq -r '.stufe' "$PENDING" 2>/dev/null)
assert "C+E: Auto-Lock → Gates → sideeffects" "sideeffects" "$STUFE_12"
rm -f "$PENDING"

# 12e: Synthese-Worker-Stop → Auto-Lock mit gates_total=3
run_create_lock "$WORKER_SYNTHESE_STOP"
TOTAL_12E=$(jq -r '.gates_total' "$PENDING" 2>/dev/null)
assert "E: Synthese → gates_total=3" "3" "$TOTAL_12E"
TYP_12E=$(jq -r '.typ' "$PENDING" 2>/dev/null)
assert "E: Synthese → typ=synthese" "synthese" "$TYP_12E"
rm -f "$PENDING"

# 12f: Worker-Stop ohne ID-Marker → Lock mit quelle=unbekannt
run_create_lock "$WORKER_INGEST_NO_ID"
QUELLE_12F=$(jq -r '.quelle' "$PENDING" 2>/dev/null)
assert "E: Kein Marker → quelle=unbekannt" "unbekannt" "$QUELLE_12F"
rm -f "$PENDING"

# 12g: Zweiter Worker-Stop → bestehender Lock nicht ueberschrieben
echo '{"typ":"ingest","stufe":"gates","quelle":"erstes-buch","gates_passed":2,"gates_total":4}' > "$PENDING"
run_create_lock "$WORKER_INGEST_STOP"
QUELLE_12G=$(jq -r '.quelle' "$PENDING" 2>/dev/null)
assert "E: Bestehender Lock → nicht ueberschrieben" "erstes-buch" "$QUELLE_12G"
PASSED_12G=$(jq -r '.gates_passed' "$PENDING" 2>/dev/null)
assert "E: Bestehender Counter → unveraendert" "2" "$PASSED_12G"
rm -f "$PENDING"

# 12h: Vollstaendiger Lifecycle mit Auto-Lock
# Worker → Auto-Lock → Gates → sideeffects → Cleanup → neuer Worker
run_create_lock "$WORKER_INGEST_STOP"
assert "E: Lifecycle Start" "true" "$([ -f "$PENDING" ] && echo true || echo false)"
for i in 1 2 3 4; do
  G='{"agent_type":"bibliothek:quellen-pruefer","hook_event_name":"SubagentStop","last_assistant_message":"[INGEST-ID:test-buch-ec2] PASS"}'
  run_advance "$G"
done
STUFE_12H=$(jq -r '.stufe' "$PENDING" 2>/dev/null)
assert "E: Lifecycle → sideeffects" "sideeffects" "$STUFE_12H"
rm -f "$PENDING"
run_pipeline_guard "$AGENT_INGEST"
assert "B: Nach Cleanup → Ingest erlaubt" "0" "$?"
```

- [ ] **Step 3: Test-Header-Kommentar aktualisieren**

Zeile 6-8 (Hook-Liste im Header):

```bash
#   E) create-pipeline-lock.sh  (SubagentStop Worker)
```

Und in der Phasen-Liste:
```bash
#  12. Auto-Lock nach Worker-Stop — Hook E erzeugt _pending.json
```

- [ ] **Step 4: Tests ausführen**

Run: `bash tests/test-integration-pipeline.sh`
Expected: Alle Tests PASS (bisherige + neue Phase 12).

- [ ] **Step 5: Commit**

```bash
git add tests/test-integration-pipeline.sh
git commit -m "$(cat <<'EOF'
test: Integration-Tests fuer Auto-Lock (Phase 12)

8 neue Cases: Worker-Stop → Auto-Lock, Cross-Hook-Interaktion,
vollstaendiger Lifecycle mit automatischer _pending.json-Erstellung.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Vollständige Verifikation + SPEC-002 abschließen

**Files:**
- Modify: `docs/specs/SPEC-002-pipeline-lock-enforcement.md:3-4` (Status + Version)

- [ ] **Step 1: Alle Unit-Tests ausführen**

```bash
bash tests/test-guard-wiki-writes.sh
bash tests/test-inject-lock-warning.sh
bash tests/test-guard-pipeline-lock.sh
bash tests/test-advance-pipeline-lock.sh
bash tests/test-create-pipeline-lock.sh
```

Expected: Alle PASS, kein Regression.

- [ ] **Step 2: Integration-Test ausführen**

Run: `bash tests/test-integration-pipeline.sh`
Expected: Alle PASS (bisherige 137 + neue aus Phase 12).

- [ ] **Step 3: Consistency-Check**

Run: `bash plugin/hooks/check-consistency.sh plugin/`
Expected: Alle PASS.

- [ ] **Step 4: Hard-Gates-Sync prüfen**

Run: `diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' plugin/skills/using-bibliothek/SKILL.md | sed '1d;$d') plugin/governance/hard-gates.md`
Expected: Keine Diff.

- [ ] **Step 5: SPEC-002 auf Done setzen**

```markdown
**Status:** Done
**Version:** 2.0
```

- [ ] **Step 6: INDEX.md Status aktualisieren**

```markdown
| [SPEC-002](SPEC-002-pipeline-lock-enforcement.md) | Aktive Pipeline-Lock-Enforcement + Auto-Lock nach Worker-Stop | Done | 2.0 | 2026-04-13 |
```

- [ ] **Step 7: Abschluss-Commit**

```bash
git add docs/specs/SPEC-002-pipeline-lock-enforcement.md docs/specs/INDEX.md
git commit -m "$(cat <<'EOF'
feat: SPEC-002 v2.0 Done — Auto-Pipeline-Lock schliesst Enforcement-Luecke

Neuer SubagentStop-Hook (create-pipeline-lock.sh) erzeugt _pending.json
automatisch nach Worker-Ende. Gate-Enforcement haengt nicht mehr an
Prompt-Law allein.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```
