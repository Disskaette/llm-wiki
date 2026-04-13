# SPEC-003 v2.0 Discovery-Logik — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Synthese um persistente Konzept-Discovery und Schlagwort-Rueckkanal erweitern, mit dreischichtiger Enforcement-Kette.

**Architecture:** Zwei neue Wiki-Dateien (`_konzept-reife.md`, `_schlagwort-vorschlaege.md`) als persistente Tracker. Synthese-Worker meldet Discoveries als Pflicht-Output, konsistenz-pruefer verifiziert, check-wiki-output.sh prueft Datei-Existenz. Ingest fuettert die Reife-Datei zusaetzlich. Wiki-Review erkennt Drift.

**Tech Stack:** Shell (check-wiki-output.sh), Markdown (Templates, Skills, Gate-Prompts)

**Betroffene Dateien (Uebersicht):**

| Datei | Aktion | Task |
|-------|--------|------|
| `plugin/hooks/check-wiki-output.sh` | Modify: Check 18 hinzufuegen | 1 |
| `tests/test-check-wiki-output-discovery.sh` | Create: Tests fuer Check 18 | 1 |
| `plugin/governance/synthese-dispatch-template.md` | Modify: Phase 2e + [DISCOVERY] + Platzhalter | 2 |
| `plugin/governance/gate-dispatch-template.md` | Modify: konsistenz-pruefer Part D | 3 |
| `plugin/skills/synthese/SKILL.md` | Modify: Phase 0.0, 0.6, 2e, 5, Governance-Tabelle | 4 |
| `plugin/skills/ingest/SKILL.md` | Modify: Phase 4 neuer Schritt | 5 |
| `plugin/skills/wiki-review/SKILL.md` | Modify: Phase 3b Discovery-Gesundheit | 6 |
| `plugin/hooks/check-consistency.sh` | Modify: Check 22 (Discovery-Platzhalter) | 7 |

---

### Task 1: check-wiki-output.sh — Check 18 (Discovery-Dateien)

**Files:**
- Modify: `plugin/hooks/check-wiki-output.sh:229` (vor Ergebnis-Block einfuegen)
- Create: `tests/test-check-wiki-output-discovery.sh`

- [ ] **Step 1: Test-Datei anlegen**

```bash
#!/usr/bin/env bash
# test-check-wiki-output-discovery.sh — Tests fuer Check 10 (Discovery-Dateien)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${SCRIPT_DIR}/../plugin/hooks/check-wiki-output.sh"
PASS=0; FAIL=0; TOTAL=0

setup() {
    TEST_DIR=$(mktemp -d)
    WIKI_DIR="${TEST_DIR}/wiki"
    mkdir -p "$WIKI_DIR/konzepte" "$WIKI_DIR/quellen"
    # Minimales Vokabular
    cat > "$WIKI_DIR/_vokabular.md" << 'EOFV'
# Kontrolliertes Vokabular
### Holzbau
### Querkraft
EOFV
}

teardown() {
    rm -rf "$TEST_DIR"
}

run_test() {
    local name="$1" expected="$2" file="$3"
    TOTAL=$((TOTAL + 1))
    output=$(bash "$HOOK" "$file" "$WIKI_DIR/_vokabular.md" "$WIKI_DIR/" 2>&1) || true
    if echo "$output" | grep -q "$expected"; then
        echo "  ✅ $name"
        PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $name"
        echo "    Expected: $expected"
        echo "    Got: $output"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Tests: check-wiki-output.sh Check 10 (Discovery-Dateien) ==="

# --- Test 1: Konzeptseite + Discovery-Dateien vorhanden → PASS ---
setup
cat > "$WIKI_DIR/konzepte/rollschub.md" << 'EOF'
---
type: konzept
title: "Rollschub"
synonyme: [Rollschubversagen]
schlagworte: [Holzbau, Querkraft]
materialgruppe: Holzbau
versagensart: [Rollschub]
mocs: [moc-holzbau]
quellen-anzahl: 2
created: 2026-04-14
updated: 2026-04-14
synth-datum: 2026-04-14
reviewed: false
---
# Rollschub
## Zusammenfassung
Rollschub ist ein Versagensmechanismus.
## Quellen
- [[quelle-a|Autor A 2020]]
EOF
cat > "$WIKI_DIR/_konzept-reife.md" << 'EOF'
---
kandidaten: []
---
# Konzept-Reife-Tracker
EOF
cat > "$WIKI_DIR/_schlagwort-vorschlaege.md" << 'EOF'
---
neue-terme: []
fehlende-zuordnungen: []
---
# Schlagwort-Vorschlaege
EOF
run_test "Konzeptseite + beide Discovery-Dateien → Check 10 PASS" "✅ Check 18-discovery-dateien" "$WIKI_DIR/konzepte/rollschub.md"
teardown

# --- Test 2: Konzeptseite + Discovery-Dateien fehlen → FAIL ---
setup
cat > "$WIKI_DIR/konzepte/rollschub.md" << 'EOF'
---
type: konzept
title: "Rollschub"
synonyme: [Rollschubversagen]
schlagworte: [Holzbau, Querkraft]
materialgruppe: Holzbau
versagensart: [Rollschub]
mocs: [moc-holzbau]
quellen-anzahl: 2
created: 2026-04-14
updated: 2026-04-14
synth-datum: 2026-04-14
reviewed: false
---
# Rollschub
## Zusammenfassung
Rollschub ist ein Versagensmechanismus.
## Quellen
- [[quelle-a|Autor A 2020]]
EOF
# Keine Discovery-Dateien angelegt
run_test "Konzeptseite + keine Discovery-Dateien → Check 10 FAIL" "FAIL: 18-discovery-dateien" "$WIKI_DIR/konzepte/rollschub.md"
teardown

# --- Test 3: Konzeptseite + nur _konzept-reife.md → FAIL ---
setup
cat > "$WIKI_DIR/konzepte/rollschub.md" << 'EOF'
---
type: konzept
title: "Rollschub"
synonyme: [Rollschubversagen]
schlagworte: [Holzbau, Querkraft]
materialgruppe: Holzbau
versagensart: [Rollschub]
mocs: [moc-holzbau]
quellen-anzahl: 2
created: 2026-04-14
updated: 2026-04-14
synth-datum: 2026-04-14
reviewed: false
---
# Rollschub
## Zusammenfassung
Rollschub ist ein Versagensmechanismus.
## Quellen
- [[quelle-a|Autor A 2020]]
EOF
cat > "$WIKI_DIR/_konzept-reife.md" << 'EOF'
---
kandidaten: []
---
# Konzept-Reife-Tracker
EOF
run_test "Konzeptseite + nur _konzept-reife.md → Check 10 FAIL" "FAIL: 18-discovery-dateien" "$WIKI_DIR/konzepte/rollschub.md"
teardown

# --- Test 4: Quellenseite → Check 10 uebersprungen (nicht erforderlich) ---
setup
cat > "$WIKI_DIR/quellen/test-quelle.md" << 'EOF'
---
type: quelle
title: "Testbuch"
autor: [Test, Autor]
jahr: 2020
verlag: "Testverlag"
seiten: 100
kategorie: Holzbau
verarbeitung: vollstaendig
pdf: "[[pdfs/holzbau/test.pdf]]"
reviewed: false
ingest-datum: 2026-04-14
schlagworte: [Holzbau, Querkraft]
kapitel-index:
  - nr: 1
    titel: "Kapitel 1"
    seiten: "1-50"
    relevanz: hoch
    schlagworte: [Holzbau]
---
# Testbuch
## Ueberblick
Ein Testbuch.
EOF
run_test "Quellenseite → Check 10 uebersprungen" "✅ Check 18-discovery-dateien" "$WIKI_DIR/quellen/test-quelle.md"
teardown

# --- Test 5: Konzeptseite + beide Dateien, eine leer → PASS (Existenz reicht) ---
setup
cat > "$WIKI_DIR/konzepte/rollschub.md" << 'EOF'
---
type: konzept
title: "Rollschub"
synonyme: [Rollschubversagen]
schlagworte: [Holzbau, Querkraft]
materialgruppe: Holzbau
versagensart: [Rollschub]
mocs: [moc-holzbau]
quellen-anzahl: 2
created: 2026-04-14
updated: 2026-04-14
synth-datum: 2026-04-14
reviewed: false
---
# Rollschub
## Zusammenfassung
Rollschub ist ein Versagensmechanismus.
## Quellen
- [[quelle-a|Autor A 2020]]
EOF
touch "$WIKI_DIR/_konzept-reife.md"
touch "$WIKI_DIR/_schlagwort-vorschlaege.md"
run_test "Konzeptseite + leere Discovery-Dateien → Check 10 PASS" "✅ Check 18-discovery-dateien" "$WIKI_DIR/konzepte/rollschub.md"
teardown

# --- Ergebnis ---
echo ""
echo "=== Ergebnis: $PASS/$TOTAL PASS, $FAIL FAIL ==="
[ "$FAIL" -gt 0 ] && exit 1
exit 0
```

- [ ] **Step 2: Tests ausfuehren — muessen FAILen (Check 10 existiert noch nicht)**

Run: `bash tests/test-check-wiki-output-discovery.sh`
Expected: FAIL — "Check 18-discovery-dateien" taucht nicht im Output auf

- [ ] **Step 3: Check 10 in check-wiki-output.sh implementieren**

In `plugin/hooks/check-wiki-output.sh`, vor dem Ergebnis-Block (vor Zeile 231 `# --- Ergebnis ---`) einfuegen.
Check 17 ist die hoechste bestehende Nummer → neuer Check wird **Check 18**:

```bash
# --- Check 18: Discovery-Dateien existieren (nur bei Konzeptseiten) ---
if [ "$FM_TYPE" = "konzept" ]; then
    DISCOVERY_MISSING=""
    [ ! -f "${WIKI_DIR}/_konzept-reife.md" ] && DISCOVERY_MISSING="${DISCOVERY_MISSING}_konzept-reife.md, "
    [ ! -f "${WIKI_DIR}/_schlagwort-vorschlaege.md" ] && DISCOVERY_MISSING="${DISCOVERY_MISSING}_schlagwort-vorschlaege.md, "
    if [ -n "$DISCOVERY_MISSING" ]; then
        check FAIL "18-discovery-dateien" "Discovery-Dateien fehlen: ${DISCOVERY_MISSING%, }"
    else
        check PASS "18-discovery-dateien" ""
    fi
else
    check PASS "18-discovery-dateien" "(Typ $FM_TYPE — nicht erforderlich)"
fi
```

Dann auch den Kommentar in Zeile 2 aktualisieren: `# check-wiki-output.sh — 14 deterministische Checks`
(war 13, jetzt 14 mit dem neuen Check).

- [ ] **Step 4: Tests ausfuehren — muessen PASSen**

Run: `bash tests/test-check-wiki-output-discovery.sh`
Expected: 5/5 PASS

- [ ] **Step 5: Bestehende Tests ausfuehren — duerfen nicht brechen**

Run: `bash tests/test-integration-pipeline.sh`
Expected: 164/164 PASS (oder aktuelle Anzahl)

- [ ] **Step 6: Commit**

```bash
git add plugin/hooks/check-wiki-output.sh tests/test-check-wiki-output-discovery.sh
git commit -m "feat: Check 18 — Discovery-Dateien-Existenz (SPEC-003 v2.0 Schicht 3)"
```

---

### Task 2: synthese-dispatch-template.md — Phase 2e + [DISCOVERY]-Block

**Files:**
- Modify: `plugin/governance/synthese-dispatch-template.md`

- [ ] **Step 1: Neue Platzhalter-Zeilen in die Platzhalter-Tabelle einfuegen**

In die Tabelle ab Zeile 15 (`## Platzhalter`) zwei neue Zeilen anfuegen:

```markdown
| `{{KONZEPT_REIFE_INHALT}}` | Aktueller YAML-Inhalt von `_konzept-reife.md` (inline eingefuegt) |
| `{{SCHLAGWORT_VORSCHLAEGE_INHALT}}` | Aktueller YAML-Inhalt von `_schlagwort-vorschlaege.md` (inline eingefuegt) |
```

- [ ] **Step 2: Discovery-Kontext im Prompt-Template einfuegen**

Nach dem Block `QUELLENSEITEN (INLINE)` (nach Zeile 56 `{{QUELLENSEITEN_INHALT}}`),
neuen Kontext-Block einfuegen:

```
═══════════════════════════════════════════════════════
DISCOVERY-KONTEXT (INLINE)
═══════════════════════════════════════════════════════

Aktueller Stand der Konzept-Reife:
{{KONZEPT_REIFE_INHALT}}

Aktuelle Schlagwort-Vorschlaege:
{{SCHLAGWORT_VORSCHLAEGE_INHALT}}
```

- [ ] **Step 3: Phase 2e einfuegen**

Nach dem Block `SELBST-CHECK` (Zeile 271-286) und VOR dem Block `PIPELINE-ID`,
neuen Pflicht-Abschnitt einfuegen:

```
═══════════════════════════════════════════════════════
PHASE 2e: DISCOVERY — NICHT VERHANDELBAR
═══════════════════════════════════════════════════════

Waehrend der vergleichenden Analyse (Phase 1-2) identifizierst du:

1. KONZEPT-KANDIDATEN: Fachbegriffe die in mehreren Quellen substanziell
   behandelt werden aber KEINE eigene Konzeptseite haben.
   - Pruefe gegen {{BESTEHENDE_KONZEPTE}}
   - Pruefe gegen bestehende Eintraege in _konzept-reife.md (oben inline)
   - Nur melden wenn der Begriff substanziell behandelt wird (nicht nur erwaehnt)

2. SCHLAGWORT-VORSCHLAEGE:
   a) Neue Terme: Fachbegriffe die in den Quellen wiederholt verwendet werden
      aber NICHT im kontrollierten Vokabular stehen.
   b) Fehlende Zuordnungen: Quellenseiten die ein Thema ausfuehrlich behandeln
      aber das entsprechende Schlagwort im Frontmatter nicht haben.

3. VOKABULAR-ERGAENZUNGEN: Wenn ein neuer Term in >=2 Quellen substanziell
   vorkommt und im Vokabular fehlt:
   → Trage ihn DIREKT in _vokabular.md ein (nur additiv, nie loeschen).
   → Verwende die Struktur der bestehenden Eintraege als Vorlage.

4. SCHLAGWORT-PATCHES: Wenn eine Quellenseite ein Thema ausfuehrlich behandelt
   aber das Schlagwort im Frontmatter fehlt:
   → Ergaenze das schlagworte:-Feld DIREKT (nur additiv, nie entfernen).
   → Nur Terme die im Vokabular existieren (ggf. erst Schritt 3).

Melde ALLES im [DISCOVERY]-Block am Ende deines Outputs.
Wenn nichts entdeckt: BEGRUENDUNG PFLICHT.

═══════════════════════════════════════════════════════
EXAKTE OUTPUT-STRUKTUR: [DISCOVERY]-BLOCK (PFLICHT)
═══════════════════════════════════════════════════════

Am Ende deines Ergebnis-Berichts, VOR der [SYNTHESE-ID]-Zeile:

[DISCOVERY]

KONZEPT-KANDIDATEN:
- term: "Begriffsname"
  quellen: quellenseite-a (Kap. X, S. Y-Z), quellenseite-b (Kap. X, S. Y-Z)

SCHLAGWORT-VORSCHLAEGE:
- neu: "Termname" — N Quellen verwenden den Begriff, fehlt im Vokabular
- fehlend: quellenseite-a → [Term1, Term2]

VOKABULAR-ERGAENZUNGEN:
- "Termname" → in _vokabular.md eingetragen

SCHLAGWORT-PATCHES:
- quellenseite-a → schlagworte: +Term1, +Term2

KEINE-DISCOVERY-BEGRUENDUNG: null

Wenn nichts entdeckt — Begruendung PFLICHT (nicht nur "nichts gefunden"):

KONZEPT-KANDIDATEN: keine
SCHLAGWORT-VORSCHLAEGE: keine
VOKABULAR-ERGAENZUNGEN: keine
SCHLAGWORT-PATCHES: keine
KEINE-DISCOVERY-BEGRUENDUNG: "Alle im Quellenvergleich aufgetretenen
Fachbegriffe existieren bereits als Konzeptseiten. Keine Terme identifiziert
die im Vokabular fehlen."
```

- [ ] **Step 4: Bestehende Platzhalter `{{BESTEHENDE_KONZEPTE}}` hinzufuegen**

Im Platzhalter-Tabelle muss `{{BESTEHENDE_KONZEPTE}}` ergaenzt werden
(wird in Phase 2e referenziert, fehlt bisher im Synthese-Template — war nur im Ingest-Template):

```markdown
| `{{BESTEHENDE_KONZEPTE}}` | Komma-separierte Liste existierender Konzeptseiten |
```

- [ ] **Step 5: Konsistenz-Check ausfuehren**

Run: `bash plugin/hooks/check-consistency.sh plugin/`
Expected: 21/21 PASS (Check 15 prueft >=5 Platzhalter — mit den neuen sind es mehr, also weiterhin PASS)

- [ ] **Step 6: Commit**

```bash
git add plugin/governance/synthese-dispatch-template.md
git commit -m "feat: Synthese-Template Phase 2e + [DISCOVERY]-Block (SPEC-003 v2.0 Schicht 1)"
```

---

### Task 3: gate-dispatch-template.md — konsistenz-pruefer Part D

**Files:**
- Modify: `plugin/governance/gate-dispatch-template.md:268-328` (Gate 3 Abschnitt)

- [ ] **Step 1: Part D in den konsistenz-pruefer Prompt einfuegen**

Im Gate 3 Prompt-Template (innerhalb der ``` Code-Fences), nach dem bestehenden
Pruefpunkt 3 (Duplikate) und VOR dem Output-Block, neuen Part einfuegen:

```
4. **Discovery-Check (NUR bei Synthese-Gates, nicht bei Ingest):**

   Pruefe nur wenn der Pipeline-ID-Marker mit [SYNTHESE-ID:...] beginnt.
   Bei [INGEST-ID:...]: Part D ueberspringen, "N/A (Ingest)" melden.

   a) Hat der Worker einen [DISCOVERY]-Block im Output geliefert?
      → FEHLT komplett: FAIL — "[DISCOVERY]-Block fehlt im Worker-Output"

   b) Wenn "keine" bei Kandidaten/Vorschlaegen:
      Gibt es eine KEINE-DISCOVERY-BEGRUENDUNG?
      → FEHLT: FAIL — "Leerer Discovery-Block ohne Begruendung"
      → Ist die Begruendung plausibel? Nicht nur "nichts gefunden" —
        muss erklaeren WARUM nichts entdeckt wurde.

   c) Wenn Konzept-Kandidaten gemeldet:
      → Ist fuer jeden Kandidat mindestens eine Quelle mit Kontext angegeben?
      → Existiert der Term bereits als Konzeptseite im Wiki? → kein Kandidat.

   d) Wenn Schlagwort-Vorschlaege gemeldet:
      → Sind die als "neu" vorgeschlagenen Terme tatsaechlich NICHT in _vokabular.md?
      → Sind die fehlenden Zuordnungen plausibel? (Quelle behandelt Thema wirklich?)

   e) Wenn Vokabular-Ergaenzungen gemeldet:
      → Lies _vokabular.md und pruefe: Steht der neue Term jetzt drin?
      → Falls nicht: FAIL — "Vokabular-Ergaenzung gemeldet aber nicht geschrieben"

   f) Wenn Schlagwort-Patches gemeldet:
      → Lies das schlagworte:-Feld der gepatchten Quellenseite.
      → Wurde das Schlagwort tatsaechlich ergaenzt?
      → Wurden bestehende Schlagworte entfernt? → FAIL — "Nicht-additiver Patch"
```

- [ ] **Step 2: Output-Block des konsistenz-pruefers erweitern**

Im Output-Template des Gate 3, den Abschnitt ergaenzen:

```markdown
### Discovery: [PASS/FAIL/N/A] — [Befunde]
```

- [ ] **Step 3: Konsistenz-Check ausfuehren**

Run: `bash plugin/hooks/check-consistency.sh plugin/`
Expected: 21/21 PASS

- [ ] **Step 4: Commit**

```bash
git add plugin/governance/gate-dispatch-template.md
git commit -m "feat: konsistenz-pruefer Part D — Discovery-Check (SPEC-003 v2.0 Schicht 2)"
```

---

### Task 4: synthese/SKILL.md — Phase 0.0 Rewrite + Phase 5 erweitern

**Files:**
- Modify: `plugin/skills/synthese/SKILL.md`

Dies ist die umfangreichste Aenderung. Mehrere Abschnitte muessen aktualisiert werden.

- [ ] **Step 1: Governance-Tabelle erweitern**

In der Governance-Tabelle (Zeile 12-24) einen neuen Eintrag hinzufuegen:

```markdown
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | ✅ Aktiv | Phase 2e: Worker schreibt Vokabular + patcht Quellenseiten, Gate 3 Part D verifiziert | — |
```

Den bestehenden Eintrag `KEIN-SCHLAGWORT-OHNE-VOKABULAR` (Zeile 19, aktuell "Delegiert")
ersetzen durch die aktive Version oben.

- [ ] **Step 2: Phase 0.0 komplett ersetzen**

Den bestehenden Phase 0.0 Block (Zeilen 31-38) ersetzen durch:

```markdown
### Phase 0.0: Konzept-Discovery auswerten

1. **Primaere Quelle:** Lies `_konzept-reife.md` (YAML-Frontmatter parsen)
   → Liste aller Kandidaten mit Status (unreif/reif/erstellt)

2. **Rueckwaertskompatibilitaet:** Scanne Quellenseiten-Frontmatter:
   `grep "konzept-kandidaten:" wiki/quellen/*.md`
   → Kandidaten die NICHT in `_konzept-reife.md` stehen → dort nachtragen
   → Status berechnen: >=2 Quellen → reif, <2 → unreif

3. **Reife-Bericht an Nutzer:**
   ```
   Reife Kandidaten (>=2 Quellen):
   - Rollschub — 3 Quellen (fingerloos-ec2-2016, colling-holzbau-2023, blass-holzbau-2022)
   - [...]
   
   Unreife Kandidaten (1 Quelle):
   - Gamma-Verfahren — 1 Quelle (blass-holzbau-2022)
   
   Seit letzter Synthese neu: [Liste]
   ```

4. **Nutzer waehlt** welche reifen Kandidaten synthetisiert werden

5. **Schlagwort-Vorschlaege pruefen:**
   - Lies `_schlagwort-vorschlaege.md`
   - Offene Vorschlaege melden:
     "N offene Schlagwort-Vorschlaege. /vokabular empfohlen?"

Falls `_konzept-reife.md` nicht existiert (erster Synthese-Lauf):
→ Datei mit Bootstrap-Inhalt anlegen (leeres `kandidaten: []`).
Falls `_schlagwort-vorschlaege.md` nicht existiert:
→ Datei mit Bootstrap-Inhalt anlegen (leere `neue-terme: []`, `fehlende-zuordnungen: []`).
```

- [ ] **Step 3: Phase 0.6 erweitern — neue Platzhalter**

Im Phase 0.6 Block (Zeile 102-122) die Platzhalter-Liste ergaenzen.
Nach dem bestehenden Punkt 2 (`{{VOKABULAR_TERME}}`) einfuegen:

```markdown
   - `{{KONZEPT_REIFE_INHALT}}`: Read `_konzept-reife.md` → inline einfuegen
   - `{{SCHLAGWORT_VORSCHLAEGE_INHALT}}`: Read `_schlagwort-vorschlaege.md` → inline einfuegen
   - `{{BESTEHENDE_KONZEPTE}}`: `ls wiki/konzepte/*.md` → Komma-separierte Liste
```

- [ ] **Step 4: Neue Phase 2e einfuegen**

Nach Phase 2 (vor Phase 3) einen neuen Abschnitt einfuegen:

```markdown
### Phase 2e: Discovery-Erkennung (im Worker)

Der Synthese-Worker fuehrt Phase 2e automatisch aus (Anweisung im Dispatch-Template).
Der Hauptagent muss NICHTS tun — Phase 2e ist Worker-intern.

**Was der Worker tut:**
- Identifiziert Konzept-Kandidaten beim Quellenvergleich
- Erkennt fehlende Vokabular-Terme
- Schreibt neue Terme in `_vokabular.md` (additiv)
- Patcht Quellenseiten-Schlagworte (additiv)
- Meldet alles im `[DISCOVERY]`-Block

**Was der Hauptagent verifiziert (nach Worker-Rueckkehr):**
- `[DISCOVERY]`-Block im Worker-Output vorhanden?
- Gate 3 (konsistenz-pruefer) Part D prueft die Details
```

- [ ] **Step 5: Phase 5 erweitern — Discovery persistieren**

Im Phase 5 Block (Zeile 305-321), den neuen Schritt VOR `check-wiki-output.sh` einfuegen:

```markdown
- [ ] **Discovery persistieren** (Worker hat `_vokabular.md` + Quellenseiten-Patches
  bereits geschrieben, Gates haben verifiziert — jetzt nur Tracking-Metadaten):
  1. `[DISCOVERY]`-Block aus Worker-Output parsen
  2. Konzept-Kandidaten → `_konzept-reife.md`:
     - Fuer jeden Kandidaten: Term schon vorhanden? → Quellen ergaenzen, Status neu berechnen
     - Neuer Term? → Eintrag anlegen mit `entdeckt-bei: "synthese:<konzeptname>"`
     - Konzeptseite existiert bereits? → Nicht eintragen
     - Status: >=2 Quellen → `reif`, <2 → `unreif`
  3. Schlagwort-Vorschlaege → `_schlagwort-vorschlaege.md`:
     - Neue Terme eintragen (Duplikat-Check)
     - Fehlende Zuordnungen eintragen
     - Bereits umgesetzte Patches als `status: umgesetzt` markieren
  4. Markdown-Body beider Dateien aus YAML regenerieren
```

Und den _log.md Eintrag erweitern:

```markdown
- [ ] **_log.md Eintrag** (inkl. Discovery-Zusammenfassung):
  ```markdown
  ## [DATUM] synthese | Konzeptname
  - Target: konzepte/konzeptname.md (NEU/UPDATED)
  - Quellen re-gelesen: [Liste]
  - Formeln: N neu + M korrigiert
  - Widersprueche: N markiert
  - Gates: quellen-pruefer PASS, konsistenz-pruefer PASS, vokabular-pruefer PASS
  - Discovery: N Konzept-Kandidaten, M Schlagwort-Vorschlaege, K Vokabular-Ergaenzungen, L Patches
  ```
```

- [ ] **Step 6: Konsistenz-Check**

Run: `bash plugin/hooks/check-consistency.sh plugin/`
Expected: 21/21 PASS

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/synthese/SKILL.md
git commit -m "feat: Synthese Phase 0.0 Rewrite + Phase 2e/5 Discovery (SPEC-003 v2.0)"
```

---

### Task 5: ingest/SKILL.md — Phase 4 neuer Schritt

**Files:**
- Modify: `plugin/skills/ingest/SKILL.md:365-389` (Phase 4: Nebeneffekte)

- [ ] **Step 1: Neuen Nebeneffekt einfuegen**

In der Phase 4 Pflicht-Nebeneffekte-Liste (nach `_vokabular.md aktualisieren`, vor
`check-wiki-output.sh ausfuehren`), neuen Schritt einfuegen:

```markdown
- [ ] **Konzept-Kandidaten in _konzept-reife.md eintragen** —
      Fuer jeden `konzept-kandidat` aus dem Frontmatter der neuen Quellenseite:
      1. Term schon in `_konzept-reife.md`? → Neue Quelle ergaenzen, Status neu berechnen
      2. Term nicht vorhanden? → Neuen Eintrag mit `entdeckt-bei: "ingest:<quellenseite>"` anlegen
      3. Status: >=2 Quellen → `reif`, <2 → `unreif`
      4. Markdown-Body aus YAML regenerieren
      Falls `_konzept-reife.md` noch nicht existiert: Datei mit leerem `kandidaten: []` Bootstrap anlegen.
```

- [ ] **Step 2: Log-Format ergaenzen**

Im Log-Format-Beispiel (Zeile 393-401) eine Zeile ergaenzen:

```markdown
- Konzept-Kandidaten: N in _konzept-reife.md eingetragen (M neu, K aktualisiert)
```

- [ ] **Step 3: Konsistenz-Check**

Run: `bash plugin/hooks/check-consistency.sh plugin/`
Expected: 21/21 PASS

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/ingest/SKILL.md
git commit -m "feat: Ingest Phase 4 — Kandidaten in _konzept-reife.md (SPEC-003 v2.0)"
```

---

### Task 6: wiki-review/SKILL.md — Phase 3b Discovery-Gesundheit

**Files:**
- Modify: `plugin/skills/wiki-review/SKILL.md`

- [ ] **Step 1: Phase 0 erweitern — Discovery-Dateien als Self-Referential-Quellen**

In Phase 0 (Zeile 29-94), nach Schritt 0.9, neuen Schritt einfuegen:

```markdown
**Schritt 0.10 — Discovery-Dateien laden (v1.1):**
- Read `wiki/_konzept-reife.md` (falls vorhanden) → YAML parsen → **KONZEPT_REIFE**
- Read `wiki/_schlagwort-vorschlaege.md` (falls vorhanden) → YAML parsen → **SCHLAGWORT_VORSCHLAEGE**
- Falls eine oder beide Dateien fehlen: in Phase 3b als DATEIEN-CHECK melden
```

- [ ] **Step 2: Phase 3b einfuegen — nach Phase 3 Meta-Konsistenz**

Nach dem bestehenden Phase 3 Block (nach `3.6 config/valid-types.txt`, vor Phase 4),
neuen Abschnitt einfuegen:

```markdown
### Phase 3b: Discovery-Gesundheit (SPEC-003 v2.0)

Prueft ob die persistente Discovery-Logik funktioniert oder stillschweigend
uebersprungen wird.

**3b.1 DATEIEN-CHECK:**
- Existiert `_konzept-reife.md`?
- Existiert `_schlagwort-vorschlaege.md`?
- Falls eine fehlt UND `_log.md` enthaelt mindestens einen `synthese`-Eintrag:
  → ERROR: "Discovery-Dateien nicht angelegt obwohl Synthese gelaufen ist."
- Falls eine fehlt UND keine Synthese im Log:
  → INFO: "Discovery-Dateien noch nicht angelegt. Wird beim ersten /synthese erstellt."
- **Output:** `| Datei | Status |`

**3b.2 STALE-CHECK:**
- Letztes `aktualisiert:`-Datum in `_konzept-reife.md` YAML extrahieren
- Synthese-Laeufe seit diesem Datum aus `_log.md` zaehlen (Eintraege mit `synthese |`)
- Falls >=2 Synthese-Laeufe seit letztem Update:
  → WARN: "N Synthese-Laeufe seit letztem Discovery-Update. Discovery wird moeglicherweise uebersprungen."
- **Output:** `| Letztes Update | Synthese-Laeufe seitdem | Status |`

**3b.3 REIFE-CHECK:**
- Alle Eintraege mit `status: reif` aus `_konzept-reife.md` lesen
- Fuer jeden: Existiert `wiki/konzepte/<term>.md`?
  - JA → `status` sollte `erstellt` sein, nicht `reif` → WARN: "Status-Drift"
  - NEIN → Wie lange schon reif? (Synthese-Laeufe seit `aktualisiert`-Datum zaehlen)
    - >2 Synthese-Laeufe → WARN: "[Term] ist seit [Datum] reif (N Quellen), aber noch keine Konzeptseite. /synthese empfohlen."
- **Output:** `| Kandidat | Quellen | Reif seit | Synthese-Laeufe | Status |`

**3b.4 RUECKSTAU-CHECK:**
- Alle Eintraege mit `status: offen` aus `_schlagwort-vorschlaege.md` zaehlen
- Aeltesten offenen Eintrag identifizieren
- Synthese-Laeufe seit aeltestem offenen Eintrag zaehlen
- Falls >=3 Synthese-Laeufe:
  → WARN: "N offene Schlagwort-Vorschlaege, aeltester seit [Datum]. /vokabular empfohlen."
- **Output:** `| Typ | Offen | Aeltester | Status |`

**3b.5 KONSISTENZ-CHECK:**
- Alle `konzept-kandidaten:`-Eintraege aus `wiki/quellen/*.md` sammeln
- Gegen `_konzept-reife.md` abgleichen
- Terme die in Quellenseiten stehen aber NICHT in der Reife-Datei:
  → WARN: "N Kandidaten aus Quellenseiten fehlen in _konzept-reife.md. Phase 0.0 Sync nicht gelaufen."
- **Output:** `| Term | In Quellenseiten | In _konzept-reife.md | Status |`

**3b.6 GHOST-CHECK:**
- Alle Eintraege mit `status: erstellt` aus `_konzept-reife.md` lesen
- Fuer jeden: Existiert die Konzeptseite tatsaechlich?
  - NEIN → ERROR: "[Term] als 'erstellt' markiert, aber Konzeptseite existiert nicht."
- **Output:** `| Term | Status | Konzeptseite existiert | Ergebnis |`
```

- [ ] **Step 3: Phase 5 Quick-Scan Report erweitern**

Im Quick-Scan Report Template (Phase 5, Zeile 340-377) nach dem Block `### Meta-Konsistenz`
neuen Abschnitt einfuegen:

```markdown
### Discovery-Gesundheit
- Discovery-Dateien: [vorhanden | fehlen (Synthese gelaufen: ja/nein)]
- Stale: [aktuell | N Synthese-Laeufe seit letztem Update]
- Reife Kandidaten ohne Seite: X (aeltester seit [Datum])
- Schlagwort-Rueckstau: X offene Vorschlaege (aeltester seit [Datum])
- Konsistenz: X Kandidaten nicht in Reife-Datei
- Ghosts: X "erstellt"-Eintraege ohne Konzeptseite
```

- [ ] **Step 4: Phase 4 Abdeckungs-Check anpassen**

Den bestehenden Phase 4.1 Block (Zeile 323-327) anpassen — primaer aus `_konzept-reife.md` lesen:

```markdown
**4.1 Konzept-Kandidaten ohne eigene Seite:**
- Primaer: Lies `_konzept-reife.md` → alle Eintraege mit `status: reif` ohne Konzeptseite
- Fallback (falls `_konzept-reife.md` nicht existiert):
  Alle `konzept-kandidaten:`-Eintraege aus allen Quellenseiten sammeln,
  gruppieren nach `term:`, Terme mit >=2 Quellen und ohne Konzeptseite → melden
- **Output:** `| Kandidat | Quellen (Anzahl) | Quellenseiten | Quelle (Reife-Datei/Frontmatter) |`
```

- [ ] **Step 5: Konsistenz-Check**

Run: `bash plugin/hooks/check-consistency.sh plugin/`
Expected: 21/21 PASS

- [ ] **Step 6: Commit**

```bash
git add plugin/skills/wiki-review/SKILL.md
git commit -m "feat: Wiki-Review Phase 3b — Discovery-Gesundheit (SPEC-004 v1.1)"
```

---

### Task 7: check-consistency.sh — Check 22 + finale Validierung

**Files:**
- Modify: `plugin/hooks/check-consistency.sh`

- [ ] **Step 1: Check 22 hinzufuegen — Discovery-Platzhalter im Synthese-Template**

Vor dem Ergebnis-Block (vor Zeile 306 `# --- Ergebnis ---`) einfuegen:

```bash
# --- Check 22: Synthese-Template hat Discovery-Platzhalter ---
if [ -f "$ROOT/governance/synthese-dispatch-template.md" ]; then
    DISC_PH=0
    grep -q '{{KONZEPT_REIFE_INHALT}}' "$ROOT/governance/synthese-dispatch-template.md" && DISC_PH=$((DISC_PH+1))
    grep -q '{{SCHLAGWORT_VORSCHLAEGE_INHALT}}' "$ROOT/governance/synthese-dispatch-template.md" && DISC_PH=$((DISC_PH+1))
    grep -q '\[DISCOVERY\]' "$ROOT/governance/synthese-dispatch-template.md" && DISC_PH=$((DISC_PH+1))
    if [ "$DISC_PH" -ge 3 ]; then
        check PASS "22-discovery-template" ""
    else
        check FAIL "22-discovery-template" "Synthese-Template: nur $DISC_PH/3 Discovery-Elemente (Platzhalter + Block)"
    fi
else
    check FAIL "22-discovery-template" "Synthese-Template fehlt"
fi
```

Zeile 2 Kommentar aktualisieren: `# check-consistency.sh — 22 Plugin-interne Konsistenzpruefungen`

- [ ] **Step 2: Alle Tests ausfuehren**

```bash
bash plugin/hooks/check-consistency.sh plugin/
# Erwartung: 22/22 PASS

bash tests/test-guard-wiki-writes.sh
# Erwartung: 6/6 PASS

bash tests/test-inject-lock-warning.sh
# Erwartung: 7/7 PASS

bash tests/test-guard-pipeline-lock.sh
# Erwartung: 10/10 PASS

bash tests/test-advance-pipeline-lock.sh
# Erwartung: 20/20 PASS

bash tests/test-create-pipeline-lock.sh
# Erwartung: 30/30 PASS

bash tests/test-integration-pipeline.sh
# Erwartung: 164/164 PASS (oder aktuelle Anzahl)

bash tests/test-check-wiki-output-discovery.sh
# Erwartung: 5/5 PASS

diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' plugin/skills/using-bibliothek/SKILL.md | sed '1d;$d') plugin/governance/hard-gates.md
# Erwartung: kein Output (Dateien synchron — hard-gates.md wurde nicht geaendert)
```

- [ ] **Step 3: Commit**

```bash
git add plugin/hooks/check-consistency.sh
git commit -m "feat: Konsistenz-Check 22 — Discovery-Template-Validierung (SPEC-003 v2.0)"
```

---

### Task 8: CLAUDE.md aktualisieren

**Files:**
- Modify: `/Users/maximilianstark/Projects/llm-wiki/CLAUDE.md`

- [ ] **Step 1: Test-Checkliste erweitern**

In der Entwicklung-Sektion die Test-Checkliste ergaenzen:

```bash
bash tests/test-check-wiki-output-discovery.sh      # 5/5 PASS?
```

Und die Konsistenz-Erwartung anpassen:

```bash
bash plugin/hooks/check-consistency.sh plugin/    # 22/22 PASS?
```

- [ ] **Step 2: Plugin-Status aktualisieren**

Keine Version-Bump noetig (v2.0.0 bleibt) — die Discovery-Logik ist ein
Prompt-/Template-Feature, kein neuer Hook oder Agent.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: Test-Checkliste fuer SPEC-003 v2.0 Discovery-Logik"
```

---

### Task 9: Spec-Status aktualisieren

**Files:**
- Modify: `docs/specs/SPEC-003-synthese-enforcement.md`
- Modify: `docs/specs/SPEC-004-wiki-review-skill.md`
- Modify: `docs/specs/INDEX.md`

- [ ] **Step 1: SPEC-003 v2.0 auf Done setzen**

Status-Zeile aendern: `**Status:** Done`

- [ ] **Step 2: SPEC-004 v1.1 auf Done setzen**

Status-Zeile aendern: `**Status:** Done`

- [ ] **Step 3: INDEX.md aktualisieren**

Beide Eintraege auf Done + aktuelles Datum.

- [ ] **Step 4: Finaler Commit**

```bash
git add docs/specs/SPEC-003-synthese-enforcement.md docs/specs/SPEC-004-wiki-review-skill.md docs/specs/INDEX.md
git commit -m "feat: SPEC-003 v2.0 + SPEC-004 v1.1 Done — Discovery-Logik komplett"
```
