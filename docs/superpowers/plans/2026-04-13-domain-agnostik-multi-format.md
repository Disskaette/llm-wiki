# Domain-Agnostik + Multi-Format-Ingest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Plugin von Bauingenieur-spezifisch zu universellem Wissens-Wiki generalisieren (SPEC-005) und dann PDF+Markdown+URL als Quellformate unterstuetzen (SPEC-006).

**Architecture:** Core-Typen (quelle, konzept) bleiben fest, Domain-Typen entstehen dynamisch aus Inhalt. Bedingte Gates ersetzen immer-aktive domain-spezifische Regeln. Worker legen Kategorien und Verzeichnisse on-demand an. Format-Erkennung in Phase 0 waehlt Lese-Strategie.

**Tech Stack:** Bash (Hooks), Markdown (Governance/Skills/Agents), jq (JSON-Parsing in Hooks)

**Specs:** `docs/specs/SPEC-005-domain-agnostik.md`, `docs/specs/SPEC-006-multi-format-ingest.md`

**Bekannte Code-Realitaeten (aus Validierung 2026-04-13):**
- `_pdfs/` im Code vs `pdfs/` im Wiki — Wiki verwendet `pdfs/` (ohne Unterstrich).
  Governance-Dateien referenzieren noch `_pdfs/`. Migration auf `pdfs/` in Task 8.
- check-wiki-output.sh hat KEINEN bestehenden `pdf:`-Check — Task 15 schreibt neuen Check.
- norm-reviewer Dispatch-Bedingung ist Prompt-Level (dispatchender Skill prueft seitentypen.md),
  nicht Hook-Level (hooks.json Matcher bleiben unveraendert).
- plugin.json Version-Bump in Task 10.

**Pflicht-Checks nach JEDEM Task:**
```bash
bash plugin/hooks/check-consistency.sh plugin/    # 19/19 PASS? (ab Task 3: 21/21)
diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' plugin/skills/using-bibliothek/SKILL.md | sed '1d;$d') plugin/governance/hard-gates.md
bash tests/test-guard-wiki-writes.sh
bash tests/test-inject-lock-warning.sh
bash tests/test-guard-pipeline-lock.sh
bash tests/test-advance-pipeline-lock.sh
bash tests/test-create-pipeline-lock.sh
bash tests/test-integration-pipeline.sh
```

---

## SPEC-005: Domain-Agnostik

### Task 1: seitentypen.md — Core/Domain-Split

**Files:**
- Modify: `plugin/governance/seitentypen.md`

Dies ist die Grundlage fuer alles Weitere. Die einzelne 6-Typen-Tabelle wird in zwei Tabellen aufgesplittet.

- [ ] **Step 1: Lese seitentypen.md vollstaendig**

Verstehe die aktuelle Struktur: eine Uebersichtstabelle (Zeile 10-17) mit 6 Typen, dann Pflicht-Frontmatter pro Typ, dann Dateinamen-Konvention.

- [ ] **Step 2: Uebersichtstabelle in Core/Domain splitten**

Ersetze die einzelne Tabelle in `## Uebersicht` durch zwei Tabellen:

```markdown
## Core-Typen (immer vorhanden, nicht konfigurierbar)

| Typ | Beantwortet | Beispiel | Verzeichnis |
|-----|------------|---------|-------------|
| **quelle** | "Was steht in dieser Quelle?" | Fingerloos 2016 | `wiki/quellen/` |
| **konzept** | "Was ist das? Wie funktioniert es?" | Rollschub, Querdruck | `wiki/konzepte/` |

## Domain-Typen (aktiv in diesem Wiki, erweiterbar)

| Typ | Beantwortet | Beispiel | Verzeichnis | Bedingter Gate |
|-----|------------|---------|-------------|----------------|
| **norm** | "Was fordert die Norm?" | EC2 §9.2.5 | `wiki/normen/` | KEIN-NORMBEZUG-OHNE-ABSCHNITT |
| **baustoff** | "Welche Eigenschaften hat das Material?" | BSH GL24h | `wiki/baustoffe/` | — |
| **verfahren** | "Wie rechne ich das nach?" | Gamma-Verfahren | `wiki/verfahren/` | — |
| **moc** | "Was gehoert thematisch zusammen?" | Querkraft | `wiki/moc/` | — |

> Domain-Typen werden vom Worker automatisch angelegt wenn er entsprechende
> Strukturen im Quellmaterial erkennt. Neuer Typ = neue Zeile in dieser Tabelle
> + Eintrag in `hooks/config/valid-types.txt`.
```

- [ ] **Step 3: kategorie-Enum in Frontmatter-Beispielen entfernen**

Im Abschnitt `### Quelle` (Zeile ~47): Ersetze den Kommentar
`kategorie: Holzbau  # Holzbau | Stahlbeton | Bauphysik | Brandschutz | ...`
durch:
`kategorie: Holzbau  # Level-1-Term aus _vokabular.md (keine feste Enum-Liste)`

Im Abschnitt `### Baustoff` (Zeile ~107): Ersetze
`kategorie: Holz  # Holz | Beton | Stahl | Verbund`
durch:
`kategorie: Holz  # Materialgruppe, Level-1-Term aus _vokabular.md`

- [ ] **Step 4: Konsistenz-Check laufen lassen**

```bash
bash plugin/hooks/check-consistency.sh plugin/
```

Erwartung: 19/19 PASS. Falls FAIL: Ursache analysieren und fixen.

- [ ] **Step 5: Commit**

```bash
git add plugin/governance/seitentypen.md
git commit -m "refactor: seitentypen.md Core/Domain-Split (SPEC-005 Schritt 1)"
```

---

### Task 2: hard-gates.md — Bedingte Gates

**Files:**
- Modify: `plugin/governance/hard-gates.md`
- Modify: `plugin/skills/using-bibliothek/SKILL.md` (Inline-Kopie synchron halten)

- [ ] **Step 1: Lese hard-gates.md und identifiziere domain-spezifische Gates**

Genau 1 Gate ist domain-spezifisch: `KEIN-NORMBEZUG-OHNE-ABSCHNITT`.
Die anderen 9 sind universell (VOLLSTAENDIGE-LESUNG, SEITENANGABE, ZAHLENWERT, QUERVERWEIS, VOKABULAR, UPDATE-DIFF, WIDERSPRUCH, QUELLENLESUNG, UMLAUTE).

- [ ] **Step 2: Bedingungs-Feld bei KEIN-NORMBEZUG-OHNE-ABSCHNITT hinzufuegen**

Finde den `<HARD-GATE: KEIN-NORMBEZUG-OHNE-ABSCHNITT>` Block und fuege eine `Bedingung:`-Zeile ein:

```markdown
<HARD-GATE: KEIN-NORMBEZUG-OHNE-ABSCHNITT>
Bedingung: Domain-Typ "norm" ist in seitentypen.md aktiv.
Jeder Normverweis ...
```

- [ ] **Step 3: Universelle Gates mit `Bedingung: keine (universell)` annotieren**

Fuer alle 9 anderen Gates: Fuege `Bedingung: keine (universell)` als erste Zeile nach dem `<HARD-GATE:` Tag ein. Damit ist die Struktur konsistent und Agents koennen programmatisch pruefen.

- [ ] **Step 4: Inline-Kopie in using-bibliothek/SKILL.md synchronisieren**

Die Inline-Kopie zwischen `<!-- BEGIN HARD-GATES -->` und `<!-- END HARD-GATES -->` muss exakt mit hard-gates.md uebereinstimmen. Ersetze den gesamten Block.

- [ ] **Step 5: Sync verifizieren**

```bash
diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' plugin/skills/using-bibliothek/SKILL.md | sed '1d;$d') plugin/governance/hard-gates.md
```

Erwartung: keine Differenz.

- [ ] **Step 6: Konsistenz-Check + Commit**

```bash
bash plugin/hooks/check-consistency.sh plugin/
git add plugin/governance/hard-gates.md plugin/skills/using-bibliothek/SKILL.md
git commit -m "feat: bedingte Gates in hard-gates.md (SPEC-005 Schritt 2)"
```

---

### Task 3: valid-types.txt Sync-Mechanik + domain-gates.txt

**Files:**
- Modify: `plugin/hooks/config/valid-types.txt`
- Create: `plugin/hooks/config/domain-gates.txt`
- Modify: `plugin/hooks/check-consistency.sh`

- [ ] **Step 1: valid-types.txt um Kommentare erweitern**

Aktuelle Datei hat 6 Typen ohne Kontext. Ergaenze Kommentare:

```
# Core-Typen (immer vorhanden)
quelle
konzept
# Domain-Typen (aus seitentypen.md, erweiterbar)
norm
baustoff
verfahren
moc
```

- [ ] **Step 2: domain-gates.txt erstellen**

```
# Aktive bedingte Gates (aus hard-gates.md, Bedingung erfuellt)
# Format: GATE-NAME:BEDINGUNG-TYP
KEIN-NORMBEZUG-OHNE-ABSCHNITT:norm
```

- [ ] **Step 3: check-consistency.sh um Sync-Check erweitern**

Neuen Check hinzufuegen der prueft ob alle Typen aus valid-types.txt auch in seitentypen.md vorkommen und umgekehrt. Lese seitentypen.md, extrahiere Typ-Spalte aus beiden Tabellen (Core + Domain), vergleiche mit valid-types.txt (Kommentare ignorieren).

Finde das Ende des letzten Checks (Check 19) und fuege Check 20 hinzu:

```bash
# Check 20: valid-types.txt ↔ seitentypen.md Sync
TYPES_FROM_CONFIG=$(grep -v '^#' "$ROOT/hooks/config/valid-types.txt" | grep -v '^$' | sort)
TYPES_FROM_SPEC=$(grep '^\| \*\*' "$ROOT/governance/seitentypen.md" | sed 's/.*\*\*\([a-z]*\)\*\*.*/\1/' | sort)
if [ "$TYPES_FROM_CONFIG" = "$TYPES_FROM_SPEC" ]; then
  pass "20-valid-types-sync"
else
  fail "20-valid-types-sync" "valid-types.txt und seitentypen.md nicht synchron"
fi
```

Passe die erwartete Check-Anzahl im Script an (falls hardcoded).

- [ ] **Step 4: check-consistency.sh um domain-gates Validierung erweitern**

Check 21: Jeder Gate-Name in domain-gates.txt muss in hard-gates.md existieren.

```bash
# Check 21: domain-gates.txt → hard-gates.md Validierung
ALL_OK=true
while IFS=: read -r GATE TYP; do
  [[ "$GATE" =~ ^# ]] && continue
  [[ -z "$GATE" ]] && continue
  if ! grep -q "HARD-GATE: $GATE" "$ROOT/governance/hard-gates.md"; then
    ALL_OK=false
  fi
done < "$ROOT/hooks/config/domain-gates.txt"
if $ALL_OK; then
  pass "21-domain-gates-valid"
else
  fail "21-domain-gates-valid" "domain-gates.txt referenziert unbekannten Gate"
fi
```

- [ ] **Step 5: Alle Tests laufen lassen**

```bash
bash plugin/hooks/check-consistency.sh plugin/    # jetzt 21/21 PASS erwartet
bash tests/test-integration-pipeline.sh           # bestehende Tests unveraendert
```

- [ ] **Step 6: CLAUDE.md Testzahl aktualisieren**

In CLAUDE.md die Zeile `bash plugin/hooks/check-consistency.sh plugin/    # 19/19 PASS?` auf `# 21/21 PASS?` aendern.

- [ ] **Step 7: Commit**

```bash
git add plugin/hooks/config/valid-types.txt plugin/hooks/config/domain-gates.txt plugin/hooks/check-consistency.sh CLAUDE.md
git commit -m "feat: valid-types Sync-Check + domain-gates.txt (SPEC-005 Schritt 3)"
```

---

### Task 4: Ingest-Bootstrap auf Core reduzieren

**Files:**
- Modify: `plugin/skills/ingest/SKILL.md`

- [ ] **Step 1: Bootstrap-Liste in Phase 0 kuerzen**

Finde die Bootstrap-Verzeichnisstruktur in Phase 0 (Zeile ~32-61). Ersetze die volle Liste durch Core + Infrastruktur:

```
wiki/
├── quellen/
├── konzepte/
├── _index/
│   ├── quellen.md    (leer, mit Header)
│   └── konzepte.md   (leer, mit Header)
├── pdfs/
│   └── neu/          (Eingangsordner fuer neue Quellen)
├── _vokabular.md     (leer, mit Header + Kategorie-Geruest)
├── _log.md           (leer, mit Header)
├── .obsidian/
│   └── app.json      (Obsidian Vault-Konfiguration)
└── CLAUDE.md          (Regeln fuer LLMs)
```

Fuege danach einen Hinweis ein:
```markdown
> Domain-Verzeichnisse (normen/, baustoffe/, verfahren/, moc/, pdfs/<kategorie>/)
> werden NICHT beim Bootstrap angelegt. Sie entstehen on-demand wenn der Worker
> erstmals Inhalte dieses Typs erkennt (siehe Phase 2).
```

- [ ] **Step 2: Phase 2 um on-demand-Verzeichnis-Logik erweitern**

Fuege in Phase 2 (Wiki-Seiten generieren) einen neuen Abschnitt 2g ein:

```markdown
**2g: Domain-Verzeichnisse on-demand anlegen**

Wenn der Worker eine Seite eines Domain-Typs erstellen will (z.B. Normseite):
1. Pruefe ob das Verzeichnis existiert (`wiki/normen/`)
2. Falls nicht: `mkdir -p wiki/normen/` + Index-Datei `_index/normen.md` anlegen
3. Pruefe ob der Typ in `hooks/config/valid-types.txt` steht
4. Falls nicht: Typ als neue Zeile unter `# Domain-Typen` appenden
5. Pruefe ob der Typ in `seitentypen.md` Domain-Tabelle steht
6. Falls nicht: Zeile in Domain-Tabelle ergaenzen
7. Seite im neuen Verzeichnis erstellen
```

- [ ] **Step 3: Konsistenz-Check + Commit**

```bash
bash plugin/hooks/check-consistency.sh plugin/
git add plugin/skills/ingest/SKILL.md
git commit -m "refactor: Bootstrap nur Core-Verzeichnisse, Domain on-demand (SPEC-005 Schritt 4)"
```

---

### Task 5: Dynamische Kategorien via Vokabular

**Files:**
- Modify: `plugin/governance/vokabular-regeln.md`
- Modify: `plugin/governance/ingest-dispatch-template.md`
- Modify: `plugin/governance/synthese-dispatch-template.md`

- [ ] **Step 1: vokabular-regeln.md — Level-1 = Kategorien dokumentieren**

Finde den Abschnitt ueber Hierarchie-Ebenen (Zeile ~40-48). Ersetze die hardcoded Oberbegriffe durch eine generische Beschreibung:

```markdown
## Hierarchie (max 3 Ebenen)

### Ebene 1: Kategorien (== `kategorie:`-Feld in Quellenseiten)

Level-1-Terme SIND die erlaubten Kategorien. Sie werden nicht hardcoded,
sondern entstehen aus dem Inhalt:
- Erster Ingest: Worker erkennt Themenfeld → legt Level-1-Term an
- Folgende Ingests: Worker waehlt bestehenden Term oder legt neuen an
- Gate 4 validiert: Kein Duplikat? Kein Synonym eines bestehenden Terms?

Beispiele (Bauingenieurwesen): Holzbau, Stahlbeton, Bauphysik, Verbundbau
Beispiele (Philosophie): Erkenntnistheorie, Ethik, Logik, Metaphysik
Beispiele (Medizin): Kardiologie, Neurologie, Chirurgie, Pharmakologie

### Ebene 2: Fachbegriffe

Schlagworte die in Quellen- und Konzeptseiten verwendet werden.

### Ebene 3: Spezialbegriffe

Unterbegriffe von Fachbegriffen (selten noetig).
```

- [ ] **Step 2: ingest-dispatch-template.md — kategorie-Kommentar aendern**

Finde die Zeile mit `kategorie: Holzbau  # Holzbau | Stahlbeton | ...` und ersetze den Kommentar:

```yaml
kategorie: Holzbau  # Level-1-Term aus wiki/_vokabular.md — kein festes Enum
```

- [ ] **Step 3: synthese-dispatch-template.md — materialgruppe analog**

Finde `materialgruppe:` und aendere den Kommentar analog zu kategorie.

- [ ] **Step 4: Konsistenz-Check + Commit**

```bash
bash plugin/hooks/check-consistency.sh plugin/
git add plugin/governance/vokabular-regeln.md plugin/governance/ingest-dispatch-template.md plugin/governance/synthese-dispatch-template.md
git commit -m "feat: dynamische Kategorien via Vokabular-Oberbegriffe (SPEC-005 Schritt 5)"
```

---

### Task 6: Dispatch-Templates domain-agnostisch

**Files:**
- Modify: `plugin/governance/ingest-dispatch-template.md`
- Modify: `plugin/governance/synthese-dispatch-template.md`
- Modify: `plugin/governance/gate-dispatch-template.md`

- [ ] **Step 1: ingest-dispatch-template.md — {{DOMAIN_GATES}} Platzhalter**

Fuege in die Platzhalter-Tabelle ein:

```markdown
| `{{DOMAIN_GATES}}` | Aktive bedingte Gates (aus hard-gates.md + seitentypen.md) |
```

Im Prompt-Template nach dem `REGELN`-Block fuege einen neuen Block ein:

```
═══════════════════════════════════════════════════════
DOMAIN-SPEZIFISCHE GATES (bedingt aktiv)
═══════════════════════════════════════════════════════

{{DOMAIN_GATES}}

Falls leer: keine domain-spezifischen Gates aktiv.
Falls vorhanden: pruefe und erzwinge diese zusaetzlichen Regeln.
```

- [ ] **Step 2: Domain-spezifische Beispiele generalisieren**

Ersetze Bauingenieur-spezifische Beispiele durch generische Formulierungen:
- `Holzbau` → `<Kategorie>` oder komplett entfernen
- Spezifische Normen (EC2, EC5) → "Normverweise (falls Domain-Typ 'norm' aktiv)"
- Konkrete Baustoffe → entfernen (kommt aus dem Quellmaterial)

Behalte die Struktur bei, nur die Beispiel-Inhalte aendern.

- [ ] **Step 3: synthese-dispatch-template.md analog anpassen**

Gleicher {{DOMAIN_GATES}} Platzhalter + Beispiele generalisieren.

- [ ] **Step 4: gate-dispatch-template.md — bedingte Prueflogik**

Im Gate 2 (quellen-pruefer) Prompt-Template: Part A (Normbezuege) wird bedingt:

```
### A: Kontextuelle Quellenpruefung

{{DOMAIN_GATES}}

Falls "KEIN-NORMBEZUG-OHNE-ABSCHNITT" aktiv:
  Pruefe jeden Normverweis auf Abschnittsnummer.
Falls nicht aktiv:
  Ueberspringe Normpruefung.
```

- [ ] **Step 5: Ingest SKILL.md Phase 0.6 — {{DOMAIN_GATES}} befuellen**

In Phase 0.6 (Dispatch vorbereiten) Schritt 2 ergaenzen:

```markdown
   - `{{DOMAIN_GATES}}`: Lese hard-gates.md → finde alle Gates mit Bedingung
     → pruefe ob der referenzierte Domain-Typ in seitentypen.md existiert
     → nur erfuellte Gates als Text einfuegen
```

- [ ] **Step 6: Konsistenz-Check + Commit**

```bash
bash plugin/hooks/check-consistency.sh plugin/
git add plugin/governance/ingest-dispatch-template.md plugin/governance/synthese-dispatch-template.md plugin/governance/gate-dispatch-template.md plugin/skills/ingest/SKILL.md
git commit -m "feat: domain-agnostische Dispatch-Templates mit {{DOMAIN_GATES}} (SPEC-005 Schritt 6)"
```

---

### Task 7: Agent-Beispiele parametrisieren

**Files:**
- Modify: `plugin/agents/quellen-pruefer.md`
- Modify: `plugin/agents/konsistenz-pruefer.md`
- Modify: `plugin/agents/norm-reviewer.md`
- Modify: `plugin/agents/vokabular-pruefer.md`
- Modify: `plugin/agents/vollstaendigkeits-pruefer.md`
- Modify: `plugin/agents/struktur-reviewer.md`

- [ ] **Step 1: quellen-pruefer.md — Normpruefung bedingt machen**

Part A prueft Normbezuege. Mache dies bedingt:
- Finde den Abschnitt zu Normbezuege-Checks
- Wrappe in: "Falls Domain-Typ 'norm' aktiv (pruefe seitentypen.md):"
- Fuege hinzu: "Falls nicht aktiv: ueberspringe diesen Part, melde 'N/A (kein norm-Typ)'"

Ersetze Bauingenieur-Beispiele (EC2, EC5, DIN EN 1995) durch generische Formulierung:
"Normverweise (EC, DIN, EN, ISO, oder andere domain-spezifische Standards)"

- [ ] **Step 2: konsistenz-pruefer.md — Beispiele generalisieren**

Ersetze spezifische Beispiele:
- `Rollschub-BSP.md` → `<konzeptseite>.md`
- `Querkraftuebertragung|Querkraft` → `<konzeptname|Anzeigename>`
- `HBV-System` → `<Fachbegriff>`

Behalte die Prueflogik identisch, nur Beispiele aendern.

- [ ] **Step 3: norm-reviewer.md — Bedingung ergaenzen**

Fuege im Header ein:
```markdown
> **Bedingung:** Dieser Agent ist nur relevant wenn Domain-Typ "norm"
> in seitentypen.md aktiv ist. Andernfalls wird er nicht dispatcht.
```

Ersetze `Bemessung-HBV.md`, `Bemessung-BSH.md` durch `<verfahrensseite>.md`.

- [ ] **Step 4: vokabular-pruefer.md — Kategorie-Validierung ergaenzen**

Fuege eine neue Pruefung hinzu:

```markdown
4. **Kategorie-Validierung:** Ist der `kategorie:`-Wert ein Level-1-Term
   in _vokabular.md? Falls der Worker einen neuen Term angelegt hat:
   ist er kein Synonym eines bestehenden Terms? Keine Duplikate?
```

- [ ] **Step 5: vollstaendigkeits-pruefer.md + struktur-reviewer.md pruefen**

Diese sind schon weitgehend generisch. Lese beide und entferne verbleibende
domain-spezifische Hardcodierungen falls vorhanden.

- [ ] **Step 6: Konsistenz-Check + Commit**

```bash
bash plugin/hooks/check-consistency.sh plugin/
git add plugin/agents/*.md
git commit -m "refactor: Agent-Beispiele domain-agnostisch parametrisiert (SPEC-005 Schritt 7)"
```

---

### Task 8: Restliche Governance-Dateien

**Files:**
- Modify: `plugin/governance/obsidian-setup.md`
- Modify: `plugin/governance/wiki-claude-md.md`
- Modify: `plugin/governance/naming-konvention.md`
- Modify: `plugin/governance/CHANGELOG.md`

- [ ] **Step 1: obsidian-setup.md — Graph-View-Queries dynamisch**

Ersetze die hardcoded Pfad-Queries (Zeile ~139-143) durch:
```markdown
Graph-View-Queries werden aus den aktiven Seitentypen in seitentypen.md
abgeleitet. Jeder Typ mit eigenem Verzeichnis bekommt eine Farbgruppe:
- Core-Typen (quellen/, konzepte/) → immer
- Domain-Typen → nur wenn Verzeichnis existiert
```

Ersetze hardcoded Index-Dateien (normen.md, baustoffe.md, verfahren.md) durch:
"Index-Dateien werden pro existierendem Verzeichnis angelegt (on-demand)."

- [ ] **Step 2: wiki-claude-md.md — Verzeichnis-Doku anpassen**

Ersetze die feste Verzeichnisliste durch Core + Hinweis auf Domain:
```markdown
- `quellen/` — Quellenseiten (Core)
- `konzepte/` — Konzeptseiten (Core)
- `_index/` — Navigationsindizes (Core)
- `pdfs/` — Quell-Dateien (Core)
- Weitere Verzeichnisse (normen/, baustoffe/, verfahren/, moc/) entstehen
  on-demand wenn der Ingest-Worker entsprechende Inhalte erkennt.
```

- [ ] **Step 3: `_pdfs/` → `pdfs/` Vereinheitlichung**

Das tatsaechliche Wiki verwendet `pdfs/` (ohne Unterstrich). Governance-Dateien
referenzieren noch `_pdfs/`. Ersetze in allen Governance-Dateien `_pdfs/` durch `pdfs/`:

```bash
grep -rl '_pdfs/' plugin/governance/ plugin/skills/ | head -20
```

Fuer jede Fundstelle: `_pdfs/` → `pdfs/` ersetzen. Betrifft mindestens:
- seitentypen.md (Frontmatter-Beispiel)
- ingest-dispatch-template.md (pdf:-Feld)
- ingest SKILL.md (Bootstrap, PDF-Sortierung)
- wiki-claude-md.md (Verzeichnis-Doku)
- obsidian-setup.md (Index-Referenzen)

- [ ] **Step 4: naming-konvention.md — Beispiele generalisieren**

Ersetze `normen/ec2-9-2-5.md` durch `normen/<norm-abschnitt>.md (falls norm-Typ aktiv)`.
Behalte die generische Namensregel (lowercase, Bindestriche, keine Umlaute).

- [ ] **Step 5: CHANGELOG.md ergaenzen**

Fuege SPEC-005 Eintrag hinzu mit Datum und Zusammenfassung.

- [ ] **Step 6: Konsistenz-Check + Commit**

```bash
bash plugin/hooks/check-consistency.sh plugin/
git add plugin/governance/obsidian-setup.md plugin/governance/wiki-claude-md.md plugin/governance/naming-konvention.md plugin/governance/CHANGELOG.md
git commit -m "refactor: Governance-Dateien domain-agnostisch (SPEC-005 Schritt 8)"
```

---

### Task 9: Skill-Governance-Tabellen + wiki-review

**Files:**
- Modify: `plugin/skills/ingest/SKILL.md` (Governance-Tabelle)
- Modify: `plugin/skills/synthese/SKILL.md` (Governance-Tabelle)
- Modify: `plugin/skills/normenupdate/SKILL.md` (Governance-Tabelle)
- Modify: `plugin/skills/wiki-review/SKILL.md` (Phase 0.8 verifizieren)
- Modify: `plugin/skills/katalog/SKILL.md` (Kategorien-Liste)
- Modify: `plugin/skills/export/SKILL.md` (Beispiele)

- [ ] **Step 1: Governance-Tabellen in Skills — Bedingungs-Spalte**

In den Skill-Governance-Tabellen (ingest, synthese, normenupdate) hat jedes Gate eine Zeile. Ergaenze eine Spalte `Bedingung` die auf den Domain-Typ verweist:

Beispiel fuer ingest/SKILL.md:
```markdown
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | ✅ Aktiv | Phase 2 setzt Abschnitte | norm-Typ aktiv |
```

Alle universellen Gates bekommen `—` in der Bedingungs-Spalte.

- [ ] **Step 2: normenupdate SKILL.md — Bedingung im Header**

Fuege Hinweis ein:
```markdown
> **Bedingung:** Dieser Skill ist nur relevant wenn Domain-Typ "norm"
> in seitentypen.md aktiv ist. Pruefe beim Skill-Start ob der Typ existiert.
> Falls nicht: "Kein norm-Typ in diesem Wiki aktiv. /normenupdate nicht verfuegbar."
```

norm-reviewer Agent wird ebenfalls nur dispatcht wenn norm-Typ aktiv ist.
Dies ist eine Prompt-Level-Bedingung (der dispatchende Skill prueft seitentypen.md),
KEINE Hook-Level-Aenderung (hooks.json Matcher bleiben unveraendert).

- [ ] **Step 3: wiki-review Phase 0.8 verifizieren**

Phase 0.8 liest bereits seitentypen.md dynamisch und Phase 3.5 ist content-driven.
Verifiziere dass die Implementierung mit dem neuen Core/Domain-Split kompatibel ist.
Falls noetig: Tabellen-Parsing anpassen (jetzt 2 Tabellen statt 1).

Ergaenze in Phase 3: Pruefen ob valid-types.txt mit seitentypen.md synchron ist.

- [ ] **Step 4: katalog + export — Beispiele generalisieren**

katalog SKILL.md: Ersetze hardcoded Kategorieliste durch Verweis auf _vokabular.md.
export SKILL.md: Ersetze HBV/BSH/BSP-Beispiele durch generische Platzhalter.

- [ ] **Step 5: Konsistenz-Check + Commit**

```bash
bash plugin/hooks/check-consistency.sh plugin/
git add plugin/skills/*/SKILL.md
git commit -m "refactor: Skill-Governance bedingte Gates + Beispiele generalisiert (SPEC-005 Schritt 9)"
```

---

### Task 10: SPEC-005 Abschluss + ARCHITECTURE.md + Tests

**Files:**
- Modify: `ARCHITECTURE.md`
- Modify: `CLAUDE.md`
- Modify: `docs/specs/SPEC-005-domain-agnostik.md`

- [ ] **Step 1: plugin.json Version-Bump**

In `plugin/.claude-plugin/plugin.json`: Version auf `2.0.0` setzen
(Major-Bump wegen Breaking Change: Core/Domain-Split, dynamische Typen).
Description aktualisieren: "Universelle LLM-gepflegte Wissensdatenbank" statt
"Technische Wissensdatenbank".

- [ ] **Step 2: ARCHITECTURE.md aktualisieren**

Ergaenze die 3-Schichten-Architektur (Core/Domain/Instanz) im Architektur-Dokument.
Aktualisiere Diagramme falls vorhanden.

- [ ] **Step 3: CLAUDE.md Enforcement-Abschnitt aktualisieren**

Ergaenze den Hinweis auf bedingte Gates und die neuen Konsistenz-Checks (21/21).

- [ ] **Step 4: Alle Tests laufen lassen — Vollstaendige Pflicht-Checkliste**

```bash
bash plugin/hooks/check-consistency.sh plugin/    # 21/21 PASS?
diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' plugin/skills/using-bibliothek/SKILL.md | sed '1d;$d') plugin/governance/hard-gates.md
bash tests/test-guard-wiki-writes.sh               # 6/6 PASS?
bash tests/test-inject-lock-warning.sh             # 7/7 PASS?
bash tests/test-guard-pipeline-lock.sh             # 10/10 PASS?
bash tests/test-advance-pipeline-lock.sh           # 20/20 PASS?
bash tests/test-create-pipeline-lock.sh            # 30/30 PASS?
bash tests/test-integration-pipeline.sh            # 152/152 PASS?
```

Alle muessen PASS sein. Bei FAIL: analysieren und fixen.

- [ ] **Step 5: SPEC-005 Status auf Done setzen**

In `docs/specs/SPEC-005-domain-agnostik.md`: Status → Done.
In `docs/specs/INDEX.md`: Status → Done.

- [ ] **Step 6: Commit + Push**

```bash
git add ARCHITECTURE.md CLAUDE.md docs/specs/SPEC-005-domain-agnostik.md docs/specs/INDEX.md
git commit -m "feat: SPEC-005 Done — Domain-Agnostik komplett"
git push
```

---

## SPEC-006: Multi-Format-Ingest

> Voraussetzung: SPEC-005 abgeschlossen.

### Task 11: Format-Erkennung in Phase 0

**Files:**
- Modify: `plugin/skills/ingest/SKILL.md`

- [ ] **Step 1: Phase 0 Schritt 1 um Format-Erkennung erweitern**

Ersetze den aktuellen "PDF lokalisieren" Abschnitt durch:

```markdown
1. **Quelle lokalisieren und Format erkennen:**
   - Wenn expliziter Pfad/URL angegeben → Format ableiten:
     - `.pdf` Extension → Format: PDF
     - `.md` Extension → Format: Markdown
     - `http://` oder `https://` Prefix → Format: URL
     - Andere Extension → "Format nicht unterstuetzt", Abbruch
   - Wenn KEIN Pfad angegeben:
     → Scanne `wiki/pdfs/neu/` nach PDF-Dateien
     → Scanne `wiki/quellen-dateien/neu/` nach Markdown-Dateien (falls Verzeichnis existiert)
     → Liste alle gefundenen Quellen mit Format auf
   - Existiert die Quelle?
     - PDF: Datei vorhanden?
     - Markdown: Datei vorhanden?
     - URL: WebFetch-Test (erreichbar? Text extrahierbar?)
   - Text extrahierbar?
     - PDF: Read-Tool auf erste 5 Seiten testen. Kein Text → pdfs/unlesbar/
     - Markdown: Read-Tool direkt. Leere Datei → Abbruch
     - URL: WebFetch → pruefe ob Ergebnis Text enthaelt (nicht nur JS/HTML-Shell)
   - Groesse und Split-Entscheidung:
     - PDF: Seitenzahl + Dateigroesse (>10 MB → Split)
     - Markdown: Dateigroesse (>500 KB → Split)
     - URL: Kein Split (Webseiten selten gross genug)
```

- [ ] **Step 2: Phase 0.6 Modellwahl pro Format ergaenzen**

Ergaenze die Modellwahl-Tabelle:

```markdown
3. Modellwahl:
   - **PDF >200 Seiten** → `model: "opus"`
   - **PDF ≤200 Seiten** → `model: "sonnet"`
   - **PDF >10 MB** → Split-Ingest-Protokoll
   - **Markdown >500 KB** → Split-Ingest-Protokoll
   - **Markdown ≤500 KB** → `model: "sonnet"`
   - **URL** → `model: "sonnet"` (Webseiten sind kompakt)
```

- [ ] **Step 3: Konsistenz-Check + Commit**

```bash
bash plugin/hooks/check-consistency.sh plugin/
git add plugin/skills/ingest/SKILL.md
git commit -m "feat: Format-Erkennung PDF/Markdown/URL in Phase 0 (SPEC-006 Schritt 1)"
```

---

### Task 12: Dispatch-Template Format-Platzhalter

**Files:**
- Modify: `plugin/governance/ingest-dispatch-template.md`

- [ ] **Step 1: Platzhalter-Tabelle erweitern**

Fuege zwei neue Platzhalter hinzu:

```markdown
| `{{QUELLEN_FORMAT}}` | pdf, markdown oder url |
| `{{QUELLEN_PFAD}}` | Absoluter Pfad zur Datei oder URL |
```

`{{PDF_PFAD}}` bleibt als Alias wenn Format=pdf (Rueckwaertskompatibilitaet).

- [ ] **Step 2: Lese-Strategie-Block im Prompt-Template einfuegen**

Nach dem KONTEXT-Block:

```
═══════════════════════════════════════════════════════
QUELLEN-FORMAT UND LESE-STRATEGIE
═══════════════════════════════════════════════════════

Format: {{QUELLEN_FORMAT}}
Pfad:   {{QUELLEN_PFAD}}

Lese-Strategie:
- pdf: Read-Tool mit pages-Parameter. Jede Seite lesen.
  Seitenangaben im Text: (S. 42), (S. 42-48)
- markdown: Read-Tool direkt auf gesamte Datei.
  Abschnitts-Referenzen statt Seiten: (Abschnitt "Titel")
- url: WebFetch-Tool. HTML als Text extrahieren.
  Abschnitts-Referenzen wenn Headings vorhanden, sonst keine.
```

- [ ] **Step 3: Frontmatter-Template anpassen**

Im `EXAKTE OUTPUT-STRUKTUR` Block: Ersetze das feste `pdf:` Feld durch:

```yaml
# Genau EINES der folgenden Felder (je nach Quellen-Format):
pdf: "[[pdfs/kategorie/dateiname.pdf]]"           # nur bei PDF-Quellen
quelle-datei: "[[quellen-dateien/kategorie/dateiname.md]]"  # nur bei Markdown-Quellen
url: "https://example.com/artikel"                 # nur bei URL-Quellen
abgerufen: 2026-04-13                              # nur bei URL-Quellen (Pflicht)
```

- [ ] **Step 4: Konsistenz-Check + Commit**

```bash
bash plugin/hooks/check-consistency.sh plugin/
git add plugin/governance/ingest-dispatch-template.md
git commit -m "feat: Format-Platzhalter und Lese-Strategien im Dispatch-Template (SPEC-006 Schritt 2)"
```

---

### Task 13: Naming-Konvention + Link-Typen

**Files:**
- Modify: `plugin/governance/naming-konvention.md`

- [ ] **Step 1: Link-Typen von 3 auf 5 erweitern**

Finde den Abschnitt mit den 3 Link-Typen und erweitere:

```markdown
## Link-Konventionen (5 Typen)

| Nr | Typ | Format | Syntax |
|----|-----|--------|--------|
| 1 | PDF-Beleg | PDF | `[[datei.pdf#page=N\|Autor Jahr, S. N]]` |
| 2 | Fachbegriff | Alle | `[[konzeptname\|Anzeigename]]` |
| 3 | Normverweis | Alle | `[[normseite\|Norm, §X.Y]]` (nur bei aktivem norm-Typ) |
| 4 | Markdown-Beleg | Markdown | `[[datei.md#heading\|Autor Jahr, Abschnitt "Titel"]]` |
| 5 | URL-Beleg | URL | `[Titel](url)` (Standard-Markdown-Link, externer Verweis) |
```

- [ ] **Step 2: Konsistenz-Check + Commit**

```bash
bash plugin/hooks/check-consistency.sh plugin/
git add plugin/governance/naming-konvention.md
git commit -m "feat: 5 Link-Typen fuer PDF/Markdown/URL (SPEC-006 Schritt 3)"
```

---

### Task 14: Gate-Anpassungen pro Format

**Files:**
- Modify: `plugin/governance/gate-dispatch-template.md`

- [ ] **Step 1: Gate 1 (Vollstaendigkeit) Format-Differenzierung**

Im Gate-1-Template ergaenze:

```markdown
Pruefstrategie je nach Quellen-Format:
- PDF: Inhaltsverzeichnis (erste 5-10 Seiten) gegen kapitel-index
- Markdown: Headings (## und ###) gegen kapitel-index
- URL: Reduziert — Hauptinhalt erfasst? (keine strenge Kapitelstruktur erwartet)
```

- [ ] **Step 2: Gate 2 (Quellenpruefung) Spot-Check anpassen**

Im Gate-2-Template ergaenze:

```markdown
Spot-Check je nach Quellen-Format:
- PDF: 5 zufaellige Seitenangaben gegen PDF-Seiten verifizieren
- Markdown: 5 zufaellige Abschnitts-Referenzen gegen Datei verifizieren
- URL: WebFetch erneut + 3 Stichproben pruefen (Inhalt kann sich geaendert haben)
```

- [ ] **Step 3: Konsistenz-Check + Commit**

```bash
bash plugin/hooks/check-consistency.sh plugin/
git add plugin/governance/gate-dispatch-template.md
git commit -m "feat: Gate-Pruefstrategien pro Quellen-Format (SPEC-006 Schritt 4)"
```

---

### Task 15: check-wiki-output.sh Format-Kompatibilitaet

**Files:**
- Modify: `plugin/hooks/check-wiki-output.sh`
- Modify: `tests/test-integration-pipeline.sh`

- [ ] **Step 1: check-wiki-output.sh — NEUEN Quellpfad-Check schreiben**

ACHTUNG: Es gibt KEINEN bestehenden pdf:-Check in check-wiki-output.sh.
Dies ist ein komplett neuer Check (z.B. Check 17 oder naechste freie Nummer).

Fuege nach dem letzten bestehenden Check einen neuen Block ein:
Das Frontmatter muss MINDESTENS eines von `pdf:`, `quelle-datei:` oder `url:` enthalten
(nur fuer `type: quelle`). Bei `url:` muss auch `abgerufen:` vorhanden sein.
```bash
# Check: Quellenseite hat Quellpfad
if [ "$TYPE" = "quelle" ]; then
  HAS_PDF=$(grep -c '^pdf:' "$FILE" || echo 0)
  HAS_DATEI=$(grep -c '^quelle-datei:' "$FILE" || echo 0)
  HAS_URL=$(grep -c '^url:' "$FILE" || echo 0)
  if [ "$HAS_PDF" -eq 0 ] && [ "$HAS_DATEI" -eq 0 ] && [ "$HAS_URL" -eq 0 ]; then
    fail "Quellenseite ohne Quellpfad (pdf/quelle-datei/url)"
  fi
  if [ "$HAS_URL" -gt 0 ]; then
    HAS_ABGERUFEN=$(grep -c '^abgerufen:' "$FILE" || echo 0)
    if [ "$HAS_ABGERUFEN" -eq 0 ]; then
      warn "URL-Quelle ohne abgerufen-Datum"
    fi
  fi
fi
```

- [ ] **Step 2: Test schreiben fuer neue Quellformate**

Ergaenze in test-integration-pipeline.sh (oder neue Testdatei) Tests fuer:
- Quellenseite mit `pdf:` → PASS (wie bisher)
- Quellenseite mit `quelle-datei:` → PASS
- Quellenseite mit `url:` + `abgerufen:` → PASS
- Quellenseite mit `url:` ohne `abgerufen:` → WARN
- Quellenseite ohne jeglichen Quellpfad → FAIL

- [ ] **Step 3: Tests laufen lassen**

```bash
bash tests/test-integration-pipeline.sh
```

Alle bestehenden + neuen Tests muessen PASS sein.

- [ ] **Step 4: Commit**

```bash
git add plugin/hooks/check-wiki-output.sh tests/test-integration-pipeline.sh
git commit -m "feat: check-wiki-output Multi-Format-Support (SPEC-006 Schritt 5)"
```

---

### Task 16: SPEC-006 Abschluss

**Files:**
- Modify: `ARCHITECTURE.md`
- Modify: `CLAUDE.md`
- Modify: `plugin/governance/CHANGELOG.md`
- Modify: `docs/specs/SPEC-006-multi-format-ingest.md`
- Modify: `docs/specs/INDEX.md`

- [ ] **Step 1: ARCHITECTURE.md — Multi-Format dokumentieren**

Ergaenze im Datenfluss-Diagramm: Statt nur "PDF-Literatur" als Input zeige
"PDF, Markdown, URL" als drei Eingangswege die alle in den Ingest muenden.

- [ ] **Step 2: CHANGELOG.md ergaenzen**

SPEC-006 Eintrag mit Datum und Zusammenfassung.

- [ ] **Step 3: Vollstaendige Test-Suite**

```bash
bash plugin/hooks/check-consistency.sh plugin/
diff <(sed -n '/<!-- BEGIN HARD-GATES -->/,/<!-- END HARD-GATES -->/p' plugin/skills/using-bibliothek/SKILL.md | sed '1d;$d') plugin/governance/hard-gates.md
bash tests/test-guard-wiki-writes.sh
bash tests/test-inject-lock-warning.sh
bash tests/test-guard-pipeline-lock.sh
bash tests/test-advance-pipeline-lock.sh
bash tests/test-create-pipeline-lock.sh
bash tests/test-integration-pipeline.sh
```

Alle muessen PASS sein.

- [ ] **Step 4: SPEC-006 Status auf Done setzen**

In `docs/specs/SPEC-006-multi-format-ingest.md`: Status → Done.
In `docs/specs/INDEX.md`: Status → Done.

- [ ] **Step 5: Commit + Push**

```bash
git add -A
git commit -m "feat: SPEC-005 + SPEC-006 Done — Domain-Agnostik + Multi-Format-Ingest"
git push
```
