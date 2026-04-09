# Dispatch-Templating & Pipeline-Härtung — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Plugin mechanisch absichern: 1 Agent = 1 PDF, Gate-Review erzwungen, konsistenter Output, Obsidian-optimierte Link-Konventionen.

**Architecture:** Shell-basierte Hooks (PreToolUse + PostToolUse) erzwingen Pipeline-Disziplin über `_pending.json` Zustandsdatei. Markdown-Templates standardisieren Subagent-Prompts. Skill-Updates verankern die neuen Regeln.

**Tech Stack:** Bash (Hooks), Markdown (Templates, Skills, Governance), JSON (hooks.json, _pending.json)

**Spec:** `docs/superpowers/specs/2026-04-10-dispatch-templating-design.md`

---

## Überblick: 9 Tasks in 4 Phasen

| Phase | Tasks | Beschreibung |
|---|---|---|
| A: Shell-Scripts | 1-4 | Bugfix + Pipeline-Lock + Konsistenz-Checks |
| B: Templates | 5-6 | Ingest- und Synthese-Dispatch-Templates |
| C: Skill-Updates | 7-8 | /ingest und /synthese SKILL.md |
| D: Governance & Docs | 9 | seitentypen, naming, obsidian-setup, ARCHITECTURE, .gitignore |

Abhängigkeiten: Task 1 → 3 (Bugfix vor Erweiterung). Task 5+6 → 7+8 (Templates vor Skills). Rest unabhängig.

---

### Task 1: Hook-Bugfix — check-wiki-write.sh

**Files:**
- Modify: `hooks/check-wiki-write.sh:28-38`
- Test: `tests/test-wiki-write-hook.sh`

- [ ] **Step 1: Test-Datei erstellen mit allen Fällen**

```bash
#!/usr/bin/env bash
# tests/test-wiki-write-hook.sh — Testfälle für check-wiki-write.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$SCRIPT_DIR/hooks/check-wiki-write.sh"
PASS=0; FAIL=0

assert_allow() {
    local desc="$1" input="$2"
    RESULT=$(echo "$input" | bash "$HOOK" 2>/dev/null)
    if echo "$RESULT" | grep -q '"allow"'; then
        echo "  ✅ $desc"; PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $desc — got: $RESULT"; FAIL=$((FAIL + 1))
    fi
}

assert_block() {
    local desc="$1" input="$2"
    RESULT=$(echo "$input" | bash "$HOOK" 2>/dev/null)
    if echo "$RESULT" | grep -q '"block"'; then
        echo "  ✅ $desc (blocked)"; PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $desc — expected block, got: $RESULT"; FAIL=$((FAIL + 1))
    fi
}

echo "=== check-wiki-write.sh Tests ==="

# Lesende Bash-Befehle mit wiki/ — müssen ALLOW sein
assert_allow "wc -l ohne Umleitung" \
    '{"tool": "Bash", "tool_input": {"command": "wc -l wiki/quellen/*.md"}}'

assert_allow "wc -l mit 2>/dev/null" \
    '{"tool": "Bash", "tool_input": {"command": "wc -l wiki/quellen/*.md 2>/dev/null"}}'

assert_allow "grep mit 2>/dev/null" \
    '{"tool": "Bash", "tool_input": {"command": "grep \"pattern\" wiki/quellen/*.md 2>/dev/null"}}'

assert_allow "cat (lesen)" \
    '{"tool": "Bash", "tool_input": {"command": "cat wiki/quellen/test.md"}}'

assert_allow "head Befehl" \
    '{"tool": "Bash", "tool_input": {"command": "head -20 wiki/quellen/test.md 2>/dev/null"}}'

# Schreibende Bash-Befehle mit wiki/ — müssen BLOCK sein
assert_block "echo redirect" \
    '{"tool": "Bash", "tool_input": {"command": "echo \"test\" > wiki/quellen/test.md"}}'

assert_block "sed -i" \
    '{"tool": "Bash", "tool_input": {"command": "sed -i s/foo/bar/ wiki/quellen/test.md"}}'

assert_block "tee" \
    '{"tool": "Bash", "tool_input": {"command": "echo test | tee wiki/quellen/test.md"}}'

assert_block "rm" \
    '{"tool": "Bash", "tool_input": {"command": "rm wiki/quellen/test.md"}}'

assert_block "mv" \
    '{"tool": "Bash", "tool_input": {"command": "mv wiki/quellen/a.md wiki/quellen/b.md"}}'

# Nicht-Wiki-Pfade — müssen ALLOW sein
assert_allow "Bash ohne wiki-Pfad" \
    '{"tool": "Bash", "tool_input": {"command": "ls -la /tmp/"}}'

echo ""
echo "=== Ergebnis: $PASS PASS, $FAIL FAIL ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
```

- [ ] **Step 2: Test ausführen — muss fehlschlagen bei 2>/dev/null-Fällen**

Run: `bash tests/test-wiki-write-hook.sh`
Expected: FAIL bei "wc -l mit 2>/dev/null" und "grep mit 2>/dev/null"

- [ ] **Step 3: Bugfix in check-wiki-write.sh — Umleitungen vor Schreiberkennung entfernen**

In `hooks/check-wiki-write.sh` den Bash-Schreiberkennungsblock (Zeile 28-38) ersetzen:

```bash
# Falls Bash-Tool: pruefe ob command wiki/ referenziert
if [ -z "$FILE_PATH" ]; then
    COMMAND=$(echo "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    if echo "$COMMAND" | grep -q 'wiki/.*\.md' 2>/dev/null; then
        # Entferne harmlose Umleitungen bevor Schreib-Check
        CLEAN_CMD=$(echo "$COMMAND" | sed 's/2>\/dev\/null//g; s/>\/dev\/null//g; s/2>&1//g; s/1>\/dev\/null//g')
        if echo "$CLEAN_CMD" | grep -qE '(>[^&]|>>| tee | mv | cp | rm |sed -i)' 2>/dev/null; then
            echo '{"decision": "block", "reason": "Bash-Schreibzugriff auf wiki/ erkannt. Wiki-Seiten nur ueber /ingest, /synthese, /normenupdate, /vokabular aendern."}'
            exit 0
        fi
    fi
    echo '{"decision": "allow", "reason": "Kein Wiki-Dateipfad erkannt"}'
    exit 0
fi
```

- [ ] **Step 4: Test erneut ausführen — alle müssen PASS sein**

Run: `bash tests/test-wiki-write-hook.sh`
Expected: Alle PASS

- [ ] **Step 5: Konsistenz-Check ausführen**

Run: `bash hooks/check-consistency.sh .`
Expected: 12/12 PASS (bestehende Checks unverändert)

- [ ] **Step 6: Commit**

```bash
git add tests/test-wiki-write-hook.sh hooks/check-wiki-write.sh
git commit -m "fix: check-wiki-write.sh erkennt 2>/dev/null nicht mehr als Schreibzugriff

Harmlose Umleitungen (2>/dev/null, >/dev/null, 2>&1) werden vor der
Schreib-Pattern-Erkennung entfernt. Testfälle hinzugefügt."
```

---

### Task 2: Pipeline-Lock — check-gates-pending.sh (PreToolUse-Hook)

**Files:**
- Create: `hooks/check-gates-pending.sh`
- Test: `tests/test-gates-pending-hook.sh`

- [ ] **Step 1: Test-Datei erstellen**

```bash
#!/usr/bin/env bash
# tests/test-gates-pending-hook.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$SCRIPT_DIR/hooks/check-gates-pending.sh"
PASS=0; FAIL=0
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Erstelle minimale Wiki-Struktur
mkdir -p "$TMPDIR/wiki"

assert_allow() {
    local desc="$1" input="$2"
    RESULT=$(echo "$input" | WIKI_DIR="$TMPDIR/wiki" bash "$HOOK" 2>/dev/null)
    if echo "$RESULT" | grep -q '"allow"'; then
        echo "  ✅ $desc"; PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $desc — got: $RESULT"; FAIL=$((FAIL + 1))
    fi
}

assert_block() {
    local desc="$1" input="$2"
    RESULT=$(echo "$input" | WIKI_DIR="$TMPDIR/wiki" bash "$HOOK" 2>/dev/null)
    if echo "$RESULT" | grep -q '"block"'; then
        echo "  ✅ $desc (blocked)"; PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $desc — expected block, got: $RESULT"; FAIL=$((FAIL + 1))
    fi
}

echo "=== check-gates-pending.sh Tests ==="

# Kein _pending.json → alles erlaubt
rm -f "$TMPDIR/wiki/_pending.json"
assert_allow "Kein pending — normaler Agent erlaubt" \
    '{"subagent_type": "general-purpose", "prompt": "Ingest test"}'

assert_allow "Kein pending — Gate-Agent erlaubt" \
    '{"subagent_type": "bibliothek:quellen-pruefer", "prompt": "Check"}'

# _pending.json mit stufe: gates
echo '{"typ":"ingest","stufe":"gates","quelle":"fingerloos-ec2-2016"}' > "$TMPDIR/wiki/_pending.json"

assert_block "Gates pending — normaler Agent blockiert" \
    '{"subagent_type": "general-purpose", "prompt": "Ingest test"}'

assert_allow "Gates pending — pruefer erlaubt" \
    '{"subagent_type": "bibliothek:quellen-pruefer", "prompt": "Check"}'

assert_allow "Gates pending — vollstaendigkeits-pruefer erlaubt" \
    '{"subagent_type": "bibliothek:vollstaendigkeits-pruefer", "prompt": "Check"}'

assert_allow "Gates pending — konsistenz-pruefer erlaubt" \
    '{"subagent_type": "bibliothek:konsistenz-pruefer", "prompt": "Check"}'

assert_allow "Gates pending — vokabular-pruefer erlaubt" \
    '{"subagent_type": "bibliothek:vokabular-pruefer", "prompt": "Check"}'

assert_allow "Gates pending — reviewer erlaubt" \
    '{"subagent_type": "bibliothek:struktur-reviewer", "prompt": "Check"}'

assert_allow "Gates pending — validator erlaubt" \
    '{"subagent_type": "bibliothek:duplikat-validator", "prompt": "Check"}'

# _pending.json mit stufe: sideeffects
echo '{"typ":"ingest","stufe":"sideeffects","quelle":"fingerloos-ec2-2016"}' > "$TMPDIR/wiki/_pending.json"

assert_block "Sideeffects pending — normaler Agent blockiert" \
    '{"subagent_type": "general-purpose", "prompt": "Ingest test"}'

assert_allow "Sideeffects pending — pruefer erlaubt" \
    '{"subagent_type": "bibliothek:quellen-pruefer", "prompt": "Check"}'

# Kein subagent_type angegeben
echo '{"typ":"ingest","stufe":"gates","quelle":"fingerloos-ec2-2016"}' > "$TMPDIR/wiki/_pending.json"

assert_block "Gates pending — Agent ohne subagent_type blockiert" \
    '{"prompt": "Ingest test"}'

echo ""
echo "=== Ergebnis: $PASS PASS, $FAIL FAIL ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
```

- [ ] **Step 2: Test ausführen — muss fehlschlagen (Hook existiert noch nicht)**

Run: `bash tests/test-gates-pending-hook.sh`
Expected: FAIL (Datei nicht gefunden)

- [ ] **Step 3: Hook-Script erstellen**

```bash
#!/usr/bin/env bash
# check-gates-pending.sh — PreToolUse Hook auf Agent-Tool
# Blockiert neue Ingest/Synthese-Agents wenn Gates oder Nebeneffekte ausstehen.
# Gate-Agents (pruefer/reviewer/validator) werden IMMER durchgelassen.
#
# Input: JSON auf stdin mit subagent_type und prompt
# Output: JSON mit "decision": "block"/"allow" + "reason"
# Env: WIKI_DIR (optional, fuer Tests; sonst aus Projekt-Root abgeleitet)

set -uo pipefail

INPUT=$(cat)

# Wiki-Verzeichnis bestimmen
if [ -z "${WIKI_DIR:-}" ]; then
    # Versuche wiki/ relativ zum Projekt-Root zu finden
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    # Suche wiki/ in bekannten Orten
    for CANDIDATE in "$PROJECT_ROOT/wiki" "$PWD/wiki"; do
        if [ -d "$CANDIDATE" ]; then
            WIKI_DIR="$CANDIDATE"
            break
        fi
    done
fi

# Kein Wiki-Verzeichnis gefunden → durchlassen (Plugin nicht aktiv)
if [ -z "${WIKI_DIR:-}" ] || [ ! -d "${WIKI_DIR:-}" ]; then
    echo '{"decision": "allow", "reason": "Kein Wiki-Verzeichnis gefunden"}'
    exit 0
fi

PENDING="$WIKI_DIR/_pending.json"

# Kein Pending-File → alles frei
if [ ! -f "$PENDING" ]; then
    echo '{"decision": "allow", "reason": "Kein offener Durchlauf"}'
    exit 0
fi

# Subagent-Typ extrahieren
SUBAGENT=$(echo "$INPUT" | sed -n 's/.*"subagent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

# Gate-Agents immer durchlassen (pruefer, reviewer, validator)
case "${SUBAGENT:-}" in
    *pruefer*|*reviewer*|*validator*)
        echo '{"decision": "allow", "reason": "Gate-Agent durchgelassen"}'
        exit 0
        ;;
esac

# Alle anderen Agents blockieren
PENDING_CONTENT=$(cat "$PENDING")
STUFE=$(echo "$PENDING_CONTENT" | sed -n 's/.*"stufe"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
QUELLE=$(echo "$PENDING_CONTENT" | sed -n 's/.*"quelle"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

case "$STUFE" in
    gates)
        echo "{\"decision\": \"block\", \"reason\": \"Gate-Review fuer '${QUELLE}' steht aus. Dispatche zuerst die Gate-Agents (vollstaendigkeits-pruefer, quellen-pruefer, konsistenz-pruefer, vokabular-pruefer).\"}"
        ;;
    sideeffects)
        echo "{\"decision\": \"block\", \"reason\": \"Nebeneffekte fuer '${QUELLE}' stehen aus (_log.md, _index, MOC, PDF sortieren). Erst abschliessen, dann naechster Ingest.\"}"
        ;;
    *)
        echo "{\"decision\": \"block\", \"reason\": \"Unbekannter Pending-Status: ${STUFE}. _pending.json manuell pruefen.\"}"
        ;;
esac
exit 0
```

- [ ] **Step 4: Ausführbar machen**

Run: `chmod +x hooks/check-gates-pending.sh`

- [ ] **Step 5: Test erneut ausführen — alle müssen PASS sein**

Run: `bash tests/test-gates-pending-hook.sh`
Expected: Alle PASS

- [ ] **Step 6: Commit**

```bash
git add hooks/check-gates-pending.sh tests/test-gates-pending-hook.sh
git commit -m "feat: PreToolUse-Hook blockiert Agent-Dispatch wenn Gates ausstehen

Neuer Hook check-gates-pending.sh prüft _pending.json vor Agent-Dispatch.
Gate-Agents (pruefer/reviewer/validator) werden immer durchgelassen.
Zweistufig: gates → sideeffects → frei."
```

---

### Task 3: Pipeline-Lock Integration — check-wiki-write.sh Erweiterung

**Files:**
- Modify: `hooks/check-wiki-write.sh`
- Modify: `tests/test-wiki-write-hook.sh` (neue Testfälle)

- [ ] **Step 1: Neue Testfälle für _pending.json Erstellung hinzufügen**

Am Ende von `tests/test-wiki-write-hook.sh` vor dem Ergebnis-Block einfügen:

```bash
echo ""
echo "--- _pending.json Tests ---"

# Setup: Temp-Wiki mit Quellenseite
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
mkdir -p "$TMPDIR/wiki/quellen"

# Test: Quellenseite schreiben erstellt _pending.json
cat > "$TMPDIR/wiki/quellen/test-buch-2024.md" << 'WIKIEOF'
---
type: quelle
title: "Test Buch"
autor: [Test, Autor]
jahr: 2024
kapitel-index:
  - nr: 1
    titel: "Einleitung"
    seiten: "1-10"
reviewed: false
schlagworte: []
---
# Test
WIKIEOF

# Simuliere PostToolUse auf Quellenseite
echo "{\"tool\": \"Write\", \"tool_input\": {\"file_path\": \"$TMPDIR/wiki/quellen/test-buch-2024.md\"}}" | \
    WIKI_DIR="$TMPDIR/wiki" bash "$HOOK" > /dev/null 2>&1

if [ -f "$TMPDIR/wiki/_pending.json" ]; then
    echo "  ✅ _pending.json erstellt nach Quellenseiten-Write"; PASS=$((PASS + 1))
else
    echo "  ❌ FAIL: _pending.json nicht erstellt"; FAIL=$((FAIL + 1))
fi

# Test: _pending.json enthält korrekte Stufe
if [ -f "$TMPDIR/wiki/_pending.json" ]; then
    if grep -q '"stufe".*"gates"' "$TMPDIR/wiki/_pending.json"; then
        echo "  ✅ _pending.json stufe ist 'gates'"; PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: stufe ist nicht 'gates'"; FAIL=$((FAIL + 1))
    fi
fi
```

- [ ] **Step 2: Test ausführen — neue Tests müssen fehlschlagen**

Run: `bash tests/test-wiki-write-hook.sh`
Expected: FAIL bei _pending.json Tests

- [ ] **Step 3: check-wiki-write.sh erweitern — _pending.json Erstellung + Transition**

In `hooks/check-wiki-write.sh` nach dem erfolgreichen Wiki-Check (nach `echo "{\"decision\": \"allow\", \"reason\": \"Wiki-Check bestanden\"}"`) und vor dem `_log.md` Sonderfall-Block die _pending.json Logik einfügen.

Am Anfang des Scripts (nach WIKI_DIR-Bestimmung) eine Variable setzen:

```bash
PENDING="${WIKI_DIR}/_pending.json"
```

Nach dem Wiki-Check-Bestanden-Block:

```bash
# --- _pending.json Erstellung bei Quellenseiten ---
case "$FILE_PATH" in
    */wiki/quellen/*.md)
        if [ ! -f "$PENDING" ]; then
            QUELLE_BASENAME=$(basename "$FILE_PATH" .md)
            printf '{"typ":"ingest","stufe":"gates","quelle":"%s","timestamp":"%s"}' \
                "$QUELLE_BASENAME" "$(date -u +%FT%T)" > "$PENDING"
        fi
        ;;
esac
```

Im _log.md Sonderfall-Block die Stufen-Transition einfügen:

```bash
_log.md)
    # --- _pending.json Stufen-Transition ---
    if [ -f "$PENDING" ]; then
        P_STUFE=$(sed -n 's/.*"stufe"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PENDING" | head -1)
        P_QUELLE=$(sed -n 's/.*"quelle"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PENDING" | head -1)

        if [ "$P_STUFE" = "gates" ]; then
            if grep -q "Gates:.*PASS" "$FILE_PATH" 2>/dev/null && grep -q "$P_QUELLE" "$FILE_PATH" 2>/dev/null; then
                sed -i '' 's/"stufe"[[:space:]]*:[[:space:]]*"gates"/"stufe": "sideeffects"/' "$PENDING"
            fi
        elif [ "$P_STUFE" = "sideeffects" ]; then
            LAST_ENTRY=$(awk "/## \\[.*\\] ingest \\| .*${P_QUELLE}/,/^## \\[/" "$FILE_PATH" | head -20)
            HAS_GATES=$(echo "$LAST_ENTRY" | grep -c "Gates:" 2>/dev/null || true)
            HAS_VERARBEITUNG=$(echo "$LAST_ENTRY" | grep -c "Verarbeitung:" 2>/dev/null || true)
            if [ "$HAS_GATES" -gt 0 ] && [ "$HAS_VERARBEITUNG" -gt 0 ]; then
                rm -f "$PENDING"
            fi
        fi
    fi
    echo '{"decision": "allow", "reason": "Log-Update erlaubt"}'
    exit 0
    ;;
```

- [ ] **Step 4: Test erneut ausführen — alle müssen PASS sein**

Run: `bash tests/test-wiki-write-hook.sh`
Expected: Alle PASS

- [ ] **Step 5: Commit**

```bash
git add hooks/check-wiki-write.sh tests/test-wiki-write-hook.sh
git commit -m "feat: check-wiki-write.sh erstellt und transitioniert _pending.json

Quellenseiten-Write erstellt _pending.json (stufe: gates).
Gate-Ergebnisse in _log.md transitionieren zu sideeffects.
Vollständiger Log-Eintrag löscht _pending.json."
```

---

### Task 4: hooks.json aktualisieren

**Files:**
- Modify: `hooks/hooks.json`

- [ ] **Step 1: hooks.json um PreToolUse-Eintrag erweitern**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/check-gates-pending.sh\"",
            "timeout": 5000
          }
        ]
      }
    ],
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
    "PostToolUse": [
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/check-wiki-write.sh\"",
            "timeout": 30000
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Konsistenz-Check**

Run: `bash hooks/check-consistency.sh .`
Expected: 12/12 PASS

- [ ] **Step 3: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat: PreToolUse-Hook auf Agent-Tool in hooks.json registriert"
```

---

### Task 5: Ingest-Dispatch-Template

**Files:**
- Create: `governance/ingest-dispatch-template.md`

- [ ] **Step 1: Template-Datei erstellen**

Vollständiger Inhalt — siehe Spec Komponente 1. Die Template-Datei enthält:
- Alle Platzhalter ({{PDF_PFAD}}, {{WIKI_ROOT}}, {{QUELLENSEITE_DATEI}}, {{BESTEHENDE_KONZEPTE}}, {{VOKABULAR_TERME}})
- Exakte Frontmatter-Vorlage aus `governance/seitentypen.md` (Typ quelle)
- Exakte Inhaltsstruktur (Überblick → Kapitel-Zusammenfassungen → Querverweise)
- Konzept-Kandidaten-Logik (nicht anlegen, nur melden)
- Link-Konventionen (3 Typen: PDF#page, Quellenseite, Konzeptseite)
- Kontext-Budget-Stopp-Anweisung
- check-wiki-output.sh Selbst-Check-Anweisung

Die exakten Frontmatter-Felder aus `governance/seitentypen.md` übernehmen (type, title, autor, jahr, verlag, seiten, kategorie, verarbeitung, pdf, reviewed, ingest-datum, schlagworte, kapitel-index). Dazu das neue Feld `konzept-kandidaten:`.

- [ ] **Step 2: Konsistenz-Check — Template muss Platzhalter enthalten**

Run: `grep -c '{{' governance/ingest-dispatch-template.md`
Expected: ≥5 (alle 5 Platzhalter)

- [ ] **Step 3: Commit**

```bash
git add governance/ingest-dispatch-template.md
git commit -m "feat: Ingest-Dispatch-Template für standardisierte Subagent-Prompts"
```

---

### Task 6: Synthese-Dispatch-Template

**Files:**
- Create: `governance/synthese-dispatch-template.md`

- [ ] **Step 1: Template-Datei erstellen**

Vollständiger Inhalt — siehe Spec Komponente 2. Die Template-Datei enthält:
- Platzhalter ({{KONZEPT_NAME}}, {{KONZEPT_DATEI}}, {{QUELLENSEITEN_INHALT}}, {{WIKI_ROOT}}, {{VOKABULAR_TERME}})
- Wiki-first-Lesestrategie (Quellenseiten primär, PDF nur bei Widersprüchen)
- Kein-Informationsverlust-Regel
- Exakte Konzeptseiten-Struktur aus `/synthese` SKILL.md Phase 2a
- Konzept-Kandidaten-Schwellenwert (≥2 Quellen → neue Seite)
- Link-Konventionen (3 Typen)
- check-wiki-output.sh Selbst-Check

Die Konzeptseiten-Struktur aus Spec übernehmen: Zusammenfassung, Formeln, Zahlenwerte+Parameter (Vergleichstabelle), Norm-Referenzen, Randbedingungen, Widersprüche, Verwandte Konzepte, Quellen.

- [ ] **Step 2: Konsistenz-Check**

Run: `grep -c '{{' governance/synthese-dispatch-template.md`
Expected: ≥5

- [ ] **Step 3: Commit**

```bash
git add governance/synthese-dispatch-template.md
git commit -m "feat: Synthese-Dispatch-Template mit Wiki-first-Lesestrategie"
```

---

### Task 7: /ingest SKILL.md aktualisieren

**Files:**
- Modify: `skills/ingest/SKILL.md`

- [ ] **Step 1: Phase 0.6 einfügen (Dispatch-Vorbereitung)**

Nach Phase 0.5 (Planmodus-Prüfung) neuen Abschnitt einfügen:

```markdown
### Phase 0.6: Dispatch vorbereiten

<NICHT-VERHANDELBAR>
Subagent-Prompts werden NICHT frei formuliert. IMMER Template verwenden.
</NICHT-VERHANDELBAR>

1. Lade `governance/ingest-dispatch-template.md`
2. Fuelle Platzhalter:
   - `{{PDF_PFAD}}`: aus Phase 0.1
   - `{{WIKI_ROOT}}`: Projektpfad + `/wiki/`
   - `{{QUELLENSEITE_DATEI}}`: nach Naming-Konvention ableiten
   - `{{BESTEHENDE_KONZEPTE}}`: Glob `wiki/konzepte/*.md` → Dateinamen-Liste
   - `{{VOKABULAR_TERME}}`: `grep "^### " wiki/_vokabular.md` → Term-Liste
3. Dispatche Agent mit ausgefuelltem Template als Prompt
4. **1 Agent = 1 PDF.** Mehrere PDFs → sequentiell verarbeiten, eine nach der anderen.
```

- [ ] **Step 2: Phase 2b anpassen (Konzept-Kandidaten statt Seitenanlage)**

Den bestehenden Absatz zu "Existiert keine? → Neue Konzeptseite anlegen" ersetzen durch:

```markdown
- Existiert keine? → Als `konzept-kandidat` in die Quellenseite eintragen:
  ```yaml
  konzept-kandidaten:
    - term: "Begriffsname"
      kontext: "Kurzbeschreibung, Kap. X, S. Y-Z"
  ```
  KEINE neue Konzeptseite anlegen. Konzeptseiten werden erst durch /synthese
  erstellt wenn ≥2 Quellen den Kandidaten nennen (Schwellenwert N=2).
```

- [ ] **Step 3: Phase 3 verstärken (Gate-Checkliste)**

Den bestehenden Phase-3-Abschnitt ergänzen mit dem NICHT-VERHANDELBAR Block:

```markdown
<NICHT-VERHANDELBAR>
NACH Rueckkehr des Ingest-Subagents MUESSEN die folgenden Gates dispatcht werden.
Ueberspringen ist VERBOTEN. _pending.json blockiert den naechsten Ingest mechanisch.

□ Gate 1-4 parallel dispatchen (vollstaendigkeits-pruefer, quellen-pruefer,
  konsistenz-pruefer, vokabular-pruefer)
□ Alle 4 PASS → Phase 4 (Nebeneffekte)
□ Bei FAIL: Korrektur → Re-Gate (max 3×) → Eskalation an Nutzer
</NICHT-VERHANDELBAR>
```

- [ ] **Step 4: Batch-Regel einfügen**

Am Ende der Phase 0.6 oder als eigener Abschnitt:

```markdown
### Batch-Modus

Bei mehreren PDFs: sequentiell verarbeiten. Pro PDF der vollstaendige Ablauf:
Template → Ingest-Agent → check-wiki-output.sh → 4 Gate-Agents → Nebeneffekte → naechste PDF.

**KEIN paralleles Dispatchen** mehrerer Ingest-Agents.
```

- [ ] **Step 5: Hard-Gates Inline-Kopie synchron halten**

Run: `diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' skills/using-bibliothek/SKILL.md | sed '1d;$d') governance/hard-gates.md`
Expected: Keine Unterschiede (oder Anpassung nötig falls Gates geändert)

- [ ] **Step 6: Konsistenz-Check**

Run: `bash hooks/check-consistency.sh .`
Expected: Alle Checks PASS

- [ ] **Step 7: Commit**

```bash
git add skills/ingest/SKILL.md
git commit -m "feat: /ingest SKILL.md — Template-Pflicht, Konzept-Kandidaten, Gate-Enforcement"
```

---

### Task 8: /synthese SKILL.md aktualisieren

**Files:**
- Modify: `skills/synthese/SKILL.md`

- [ ] **Step 1: Phase 0.0 einfügen (Konzept-Kandidaten sammeln)**

Vor Phase 0.1 neuen Abschnitt:

```markdown
### Phase 0.0: Konzept-Kandidaten sammeln

1. Scanne alle Quellenseiten: `grep "konzept-kandidaten:" wiki/quellen/*.md`
2. Zaehle pro Kandidat: wie viele Quellen nennen ihn?
3. Kandidaten mit ≥2 Quellen → zur Synthese-Liste hinzufuegen
4. Meldung: "N neue Konzeptseiten koennen erstellt werden: [Liste]"
5. Nutzer entscheidet welche Konzepte synthetisiert werden
```

- [ ] **Step 2: Phase 0.5b ändern (Wiki-first statt PDF-first)**

Den bestehenden NICHT-VERHANDELBAR-Block in Phase 0.5b ersetzen:

```markdown
<NICHT-VERHANDELBAR>
Synthese arbeitet primaer auf Wiki-Quellenseiten (4-Gate-gepruefte Extraktionen).
Original-PDFs werden NUR bei Widerspruechen, unklaren Formeln oder unplausiblen
Zahlenwerten geladen — GEZIELT, 2-5 Seiten, nicht ganze Kapitel.

1. Lies alle Wiki-Quellenseiten die das Konzept behandeln (PFLICHT)
2. Lade Original-PDFs NUR bei Bedarf (Widerspruch/Unklarheit)
3. Vermerke jeden PDF-Spot-Check im Output
</NICHT-VERHANDELBAR>
```

- [ ] **Step 3: Governance-Tabelle Gate 9 anpassen**

```markdown
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | ✅ Aktiv | Wiki-Quellenseiten als Primaerquelle (4-Gate-geprueft), PDF-Spot-Check bei Widerspruechen/Unklarheiten |
```

- [ ] **Step 4: Phase 0.6 einfügen (Dispatch-Vorbereitung)**

```markdown
### Phase 0.6: Dispatch vorbereiten

<NICHT-VERHANDELBAR>
Subagent-Prompts werden NICHT frei formuliert. IMMER Template verwenden.
</NICHT-VERHANDELBAR>

1. Lade `governance/synthese-dispatch-template.md`
2. Fuelle Platzhalter:
   - `{{KONZEPT_NAME}}`: aus Nutzer-Anfrage oder Kandidaten-Liste
   - `{{KONZEPT_DATEI}}`: Pfad zur bestehenden Seite oder "NEU"
   - `{{QUELLENSEITEN_INHALT}}`: Read aller Wiki-Quellenseiten → inline einfuegen
   - `{{WIKI_ROOT}}`: Projektpfad + `/wiki/`
   - `{{VOKABULAR_TERME}}`: `grep "^### " wiki/_vokabular.md` → Term-Liste
3. Dispatche Agent mit ausgefuelltem Template als Prompt
```

- [ ] **Step 5: Informationsverlust-Gate hinzufügen**

In Phase 2 oder als eigener Block:

```markdown
<NICHT-VERHANDELBAR>
KEIN INFORMATIONSVERLUST: Fuer JEDE Quellenseite gilt:
- Jede Formel → muss in der Konzeptseite landen
- Jeder Zahlenwert → muss in der Vergleichstabelle landen
- Jede Randbedingung → muss dokumentiert sein
- Jeder Normbezug → muss mit Abschnitt erfasst sein

Wenn unsicher ob relevant: AUFNEHMEN. Weglassen nur mit expliziter Begruendung.
</NICHT-VERHANDELBAR>
```

- [ ] **Step 6: Konsistenz-Check**

Run: `bash hooks/check-consistency.sh .`
Expected: Alle Checks PASS

- [ ] **Step 7: Commit**

```bash
git add skills/synthese/SKILL.md
git commit -m "feat: /synthese SKILL.md — Wiki-first, Konzept-Kandidaten, Template-Pflicht, Kein-Informationsverlust"
```

---

### Task 9: Governance-Docs, ARCHITECTURE, .gitignore

**Files:**
- Modify: `governance/seitentypen.md`
- Modify: `governance/naming-konvention.md`
- Modify: `governance/obsidian-setup.md`
- Modify: `hooks/check-consistency.sh`
- Modify: `ARCHITECTURE.md`
- Modify: `.gitignore`

- [ ] **Step 1: seitentypen.md — neue Felder dokumentieren**

Im Quellen-Frontmatter-Block `konzept-kandidaten:` als optionales Feld hinzufügen.
Im Konzept-Frontmatter-Block `mocs:` als optionales Feld hinzufügen.

Quellen-Block ergänzen:
```yaml
konzept-kandidaten:  # Optional — vom Ingest-Agent befüllt
  - term: "Begriffsname"
    kontext: "Kurzbeschreibung, Kap. X, S. Y-Z"
```

Konzept-Block ergänzen:
```yaml
mocs: [moc-holzbau, moc-verbundbau]  # Optional — in welchen MOCs verlinkt
```

- [ ] **Step 2: naming-konvention.md — Link-Alias-Konvention dokumentieren**

Neuen Abschnitt "Link-Konventionen" hinzufügen:

```markdown
## Link-Konventionen

Drei Link-Typen, kontextabhängig:

| Kontext | Ziel | Syntax |
|---------|------|--------|
| Beleg im Fließtext | PDF mit Seitenangabe | `[[datei.pdf#page=N\|Autor Jahr, S. N]]` |
| ## Quellen-Abschnitt | Wiki-Quellenseite | `[[quellenseite\|Autor Jahr]]` |
| Fachbegriff | Konzeptseite | `[[konzeptname\|Anzeigename]]` |

Obsidian Shortest-Path-Auflösung: Voller Pfad nicht nötig wenn Dateiname eindeutig.

### Alias-Konvention (title:-Feld)

Dateinamen bleiben ASCII-lowercase. Anzeigenamen über:
- Frontmatter `title:` → Obsidian zeigt in Sidebar
- Wikilink-Alias `[[dateiname|Anzeigename]]` → schöner Name im Text
```

- [ ] **Step 3: obsidian-setup.md — Graph-Filter und MOC-Hierarchie dokumentieren**

Neue Abschnitte hinzufügen:

```markdown
## Graph View Konfiguration

### Standard-Filter
```
-path:quellen/ -path:_index/ -file:_
```

### Gruppen-Coloring
| Gruppe | Query | Farbe |
|--------|-------|-------|
| MOC | `path:moc/` | Rot |
| Konzept | `path:konzepte/` | Blau |
| Verfahren | `path:verfahren/` | Grün |
| Norm | `path:normen/` | Orange |
| Baustoff | `path:baustoffe/` | Violett |

Attachments-Toggle: AUS (PDFs nicht im Graph).

### Local Graph
Für tägliche Arbeit: Rechte Sidebar → "Open local graph".
Zeigt Nachbarn der aktuellen Seite (Tiefe konfigurierbar).

## MOC-Hierarchie

Zweistufig nach LYT-Pattern:
- `wiki/home.md` als Vault-Einstieg
- Top-MOCs (Fachbereiche): interaktiv erarbeitet
- Sub-MOCs (Themen): verlinken auf Konzept-/Verfahrensseiten
- Konzepte dürfen in mehreren MOCs auftauchen

Obsidian-Config: `"defaultOpenFile": "home"` in `.obsidian/app.json`
```

- [ ] **Step 4: check-consistency.sh — 4 neue Checks (13-16)**

Am Ende des Scripts vor dem Ergebnis-Block:

```bash
# --- Check 13: Ingest-Dispatch-Template existiert ---
if [ -f "$ROOT/governance/ingest-dispatch-template.md" ]; then
    check PASS "13-ingest-template" ""
else
    check FAIL "13-ingest-template" "governance/ingest-dispatch-template.md fehlt"
fi

# --- Check 14: Synthese-Dispatch-Template existiert ---
if [ -f "$ROOT/governance/synthese-dispatch-template.md" ]; then
    check PASS "14-synthese-template" ""
else
    check FAIL "14-synthese-template" "governance/synthese-dispatch-template.md fehlt"
fi

# --- Check 15: Templates enthalten Platzhalter ---
INGEST_PH=$(grep -c '{{' "$ROOT/governance/ingest-dispatch-template.md" 2>/dev/null || echo 0)
SYNTHESE_PH=$(grep -c '{{' "$ROOT/governance/synthese-dispatch-template.md" 2>/dev/null || echo 0)
if [ "$INGEST_PH" -ge 5 ] && [ "$SYNTHESE_PH" -ge 5 ]; then
    check PASS "15-template-platzhalter" ""
else
    check FAIL "15-template-platzhalter" "Ingest: $INGEST_PH (min 5), Synthese: $SYNTHESE_PH (min 5)"
fi

# --- Check 16: Skills referenzieren Templates ---
INGEST_REF=$(grep -c 'ingest-dispatch-template' "$ROOT/skills/ingest/SKILL.md" 2>/dev/null || echo 0)
SYNTHESE_REF=$(grep -c 'synthese-dispatch-template' "$ROOT/skills/synthese/SKILL.md" 2>/dev/null || echo 0)
if [ "$INGEST_REF" -ge 1 ] && [ "$SYNTHESE_REF" -ge 1 ]; then
    check PASS "16-skill-template-referenz" ""
else
    check FAIL "16-skill-template-referenz" "Ingest-Ref: $INGEST_REF, Synthese-Ref: $SYNTHESE_REF"
fi
```

Die Ergebnis-Zeile aktualisieren: "16 Checks" statt "12 Checks".

- [ ] **Step 5: ARCHITECTURE.md aktualisieren**

Folgende Abschnitte ergänzen/aktualisieren:
- Dispatch-Templates in der Pipeline-Übersicht
- Pipeline-Lock (_pending.json) in Governance-Schichten
- Konzept-Kandidaten-System in Daten-Flow-Artefakte
- Link-Konventionen (3 Typen)
- MOC-Hierarchie
- Statistiken aktualisieren (16 Konsistenz-Checks statt 12)
- Neue Hook (check-gates-pending.sh) dokumentieren

- [ ] **Step 6: .gitignore — wiki/_pdfs/ hinzufügen**

```
.DS_Store
.obsidian/
wiki/_pdfs/
```

- [ ] **Step 7: Konsistenz-Check (muss jetzt 16/16 zeigen)**

Run: `bash hooks/check-consistency.sh .`
Expected: 16/16 PASS

- [ ] **Step 8: Hard-Gates Sync prüfen**

Run: `diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' skills/using-bibliothek/SKILL.md | sed '1d;$d') governance/hard-gates.md`
Expected: Keine Unterschiede

- [ ] **Step 9: Commit**

```bash
git add governance/seitentypen.md governance/naming-konvention.md governance/obsidian-setup.md hooks/check-consistency.sh ARCHITECTURE.md .gitignore
git commit -m "feat: Governance-Docs, Konsistenz-Checks, ARCHITECTURE — Dispatch-Templating komplett

- seitentypen.md: konzept-kandidaten + mocs Felder
- naming-konvention.md: Link-Alias-Konvention + 3 Link-Typen
- obsidian-setup.md: Graph-Filter, Coloring, MOC-Hierarchie
- check-consistency.sh: 4 neue Checks (13-16), jetzt 16/16
- ARCHITECTURE.md: Pipeline-Lock, Templates, Konzept-Kandidaten
- .gitignore: wiki/_pdfs/ ausgeschlossen"
```

---

## Abschluss-Verifizierung

- [ ] **Alle Konsistenz-Checks: 16/16 PASS**

Run: `bash hooks/check-consistency.sh .`

- [ ] **Hard-Gates Sync: identisch**

Run: `diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' skills/using-bibliothek/SKILL.md | sed '1d;$d') governance/hard-gates.md`

- [ ] **Hook-Tests: alle PASS**

Run: `bash tests/test-wiki-write-hook.sh && bash tests/test-gates-pending-hook.sh`

- [ ] **Git Status: sauber**

Run: `git status`
Expected: Keine uncommitted changes
