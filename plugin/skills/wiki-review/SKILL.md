---
name: wiki-review
description: "Wiki-Review — Obsidian-Integritaet, Content-Drift, Abdeckungsanalyse, Migrationsplan"
---

## Governance-Vertrag

> Wiki-Review ist ein diagnostischer Skill zur semantischen Analyse des Wikis.
> Er identifiziert Qualitaetsprobleme, Content-Drift und Abdeckungsluecken.
> Kein Gate ist aktiv — der Skill ist read-only (ausser Report-Write in `wiki/_reviews/`).

| Gate | Durchsetzung | Wie | Bedingung |
|------|-------------|-----|-----------|
| KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG | ⚪ N/A | Review liest keine neuen Buecher | — |
| KEIN-INHALT-OHNE-SEITENANGABE | ⚪ N/A | Review prueft, modifiziert aber nicht | — |
| KEIN-ZAHLENWERT-OHNE-QUELLE | ⚪ N/A | Review prueft, modifiziert aber nicht | — |
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | ⚪ N/A | Review prueft, modifiziert aber nicht | — |
| KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS | ⚪ N/A | Review prueft, meldet Luecken | — |
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | ⚪ N/A | Review prueft, meldet Probleme | — |
| KEIN-UPDATE-OHNE-DIFF | ⚪ N/A | Keine Aenderungen durch Review | — |
| KEIN-WIDERSPRUCH-OHNE-MARKIERUNG | ⚪ N/A | Review prueft Format, korrigiert nicht | — |
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | ⚪ N/A | Review aendert keine Wiki-Seiten | — |
| KORREKTE-UMLAUTE | ⚪ N/A | Review-Report ist Chat-Output (Stufe 1) bzw. Markdown (Stufe 2) | — |

---

## Phasen

### Phase 0: Governance laden (Self-Referential)

<NICHT-VERHANDELBAR>
Der Standard wird aus den AKTUELLEN Plugin-Dateien gelesen, NIE hardcoded.
Wenn sich Templates aendern, aendert sich automatisch was der Review als
"korrekt" betrachtet.
</NICHT-VERHANDELBAR>

**Schritt 0.1 — Konzeptseiten-Standard extrahieren:**
- Read `governance/synthese-dispatch-template.md`
- Suche den Block `Frontmatter (alle Felder PFLICHT):` bis zum naechsten `---`-Delimiter nach den Feldern
- Extrahiere alle Feldnamen (Keys vor dem `:`) → **PFLICHT_FELDER_KONZEPT**
- Erwartetes Ergebnis (dynamisch, nicht hardcoded): type, title, synonyme, schlagworte, materialgruppe, versagensart, mocs, quellen-anzahl, created, updated, synth-datum, reviewed

**Schritt 0.2 — Quellenseiten-Standard extrahieren:**
- Read `governance/ingest-dispatch-template.md`
- Suche analog den Block `Frontmatter (alle Felder PFLICHT):` → **PFLICHT_FELDER_QUELLE**
- Erwartetes Ergebnis (dynamisch): type, title, autor, jahr, verlag, seiten, kategorie, verarbeitung, pdf, reviewed, ingest-datum, schlagworte, kapitel-index
- Bedingt-Pflicht (WARN wenn fehlend, kein ERROR): konzept-kandidaten (nicht jede Quelle hat Kandidaten)

**Schritt 0.3 — Body-Struktur-Reihenfolge extrahieren:**
- Read `governance/synthese-dispatch-template.md`
- Suche den Block ab `Body-Struktur` bis zum naechsten `═══`-Delimiter
- Extrahiere alle `## [Headername]`-Zeilen in Reihenfolge → **SOLL_REIHENFOLGE**
- Erwartetes Ergebnis (dynamisch): Zusammenfassung, Einsatzgrenzen + Randbedingungen, Formeln, Zahlenwerte + Parameter, Norm-Referenzen, Widersprueche, Verwandte Konzepte, Quellen

**Schritt 0.4 — Erlaubte Seitentypen laden:**
- Read `hooks/config/valid-types.txt`
- Ignoriere Kommentarzeilen (`#`)
- Ergebnis → **VALID_TYPES** (eine Liste)

**Schritt 0.5 — Hard Gates laden:**
- Read `governance/hard-gates.md`
- Extrahiere alle `<HARD-GATE: ...>`-Marker → **ACTIVE_GATES** (Liste der Gate-Namen)
- Nutze in Phase 1/2 um zu verifizieren dass der Review alle relevanten Aspekte abdeckt

**Schritt 0.6 — Link- und Dateinamen-Konventionen laden:**
- Read `governance/naming-konvention.md`
- Extrahiere:
  - 3 Link-Typen (Beleg, Quellen-Abschnitt, Fachbegriff) mit Syntax-Muster
  - Dateinamen-Regeln (lowercase ASCII, Bindestriche, keine Umlaute)
  - Eindeutigkeitsregel ueber alle Verzeichnisse

**Schritt 0.7 — Obsidian-Setup-Standard laden:**
- Read `governance/obsidian-setup.md`
- Extrahiere:
  - `app.json`-Block → **SOLL_APP_JSON** (Key-Value-Paare)
  - Graph-View-Filter → **SOLL_GRAPH_FILTER**
  - Graph-View-Gruppen-Logik (Typ→Verzeichnis, siehe 0.9) → dynamisch in Phase 1.6 abgeleitet

**Schritt 0.8 — Wiki-Inventar erstellen:**
- Alle `.md`-Dateien unter `wiki/` zaehlen und kategorisieren
- Sonderdateien: `_log.md`, `_vokabular.md`, `_pending.json`
- Ergebnis → **INVENTAR** mit Counts pro Verzeichnis

**Schritt 0.9 — Typ→Verzeichnis-Mapping extrahieren (dynamisch):**
- Read `governance/seitentypen.md`
- seitentypen.md enthaelt ZWEI Tabellen:
  - **Core-Typen** (Spalten: Typ, Beantwortet, Beispiel, Verzeichnis) — immer vorhanden
  - **Domain-Typen** (Spalten: Typ, Beantwortet, Beispiel, Verzeichnis, Bedingter Gate) — erweiterbar
- Extrahiere aus BEIDEN Tabellen alle `Typ → Verzeichnis`-Paare → **TYP_VERZEICHNIS_MAP**
- Ergaenze Infrastruktur-Verzeichnisse (nicht typengebunden, aber immer erwartet):
  `_index/`, `pdfs/`
- NICHT hardcoden — wenn ein neuer Seitentyp in seitentypen.md aufgenommen wird,
  erkennt der Review ihn automatisch

**Schritt 0.10 — Discovery-Dateien laden (v1.1):**
- Read `wiki/_konzept-reife.md` (falls vorhanden) → YAML parsen → **KONZEPT_REIFE**
- Read `wiki/_schlagwort-vorschlaege.md` (falls vorhanden) → YAML parsen → **SCHLAGWORT_VORSCHLAEGE**
- Falls eine oder beide Dateien fehlen: in Phase 3b als DATEIEN-CHECK melden

---

### Phase 1: Obsidian-Layer (EXHAUSTIV — jede Seite)

JEDE `.md`-Datei in `wiki/` wird geprueft. Ausnahmen: `_log.md`, `_reviews/`-Dateien.
Ein einziger Fund reicht fuer Full-Audit-Empfehlung.

**1.1 Frontmatter-Schema:**
- Fuer jede Seite: YAML-Frontmatter parsen
- Pflicht-Felder pruefen:
  - `type: quelle` → gegen **PFLICHT_FELDER_QUELLE**
  - `type: konzept` → gegen **PFLICHT_FELDER_KONZEPT**
  - Andere Typen: mindestens `type`, `title`, `schlagworte`, `reviewed`
- `type:`-Wert gegen **VALID_TYPES** pruefen
- Feldtypen pruefen:
  - `schlagworte:`, `synonyme:`, `mocs:`, `versagensart:` → YAML-Array (nicht String)
  - `created:`, `updated:`, `ingest-datum:`, `synth-datum:` → ISO-Format (YYYY-MM-DD)
  - `reviewed:` → boolean (`true`/`false`) oder ISO-Datum
  - `quellen-anzahl:`, `seiten:`, `jahr:` → Zahl (nicht String)
- Unbekannte Felder (nicht im Template) → melden als INFO (nicht als Fehler)
- **Output:** Tabelle `| Seite | Fehlende Felder | Typfehler | Status |`

**1.2 Link-Integritaet:**
- Jeden `[[...]]`-Wikilink extrahieren (Regex: `\[\[([^\]]+)\]\]`)
- Wikilinks mit Pipe (`|`) splitten: Teil VOR `|` ist der Dateiname/Ziel, Teil NACH `|` ist der Anzeigename
- Fuer jeden Link:
  - Zieldatei existiert? (Obsidian Shortest-Path: Dateiname ohne Verzeichnis reicht)
  - Syntax korrekt? Gegen die 3 Link-Typen aus **naming-konvention.md** pruefen:
    - PDF-Beleg: `[[datei.pdf#page=N|Autor Jahr, S. N]]`
    - Konzept: `[[konzeptname|Anzeigename]]`
    - Quellenseite: `[[quellenseite|Autor Jahr]]`
  - Markdown-Links (`[text](url)`) statt Wikilinks? → melden
  - PDF-Links: Existiert die referenzierte PDF im Vault (`wiki/pdfs/`)?
- **Output:** Tabelle `| Quelle | Link | Problem |`

**1.3 Dateinamen-Konventionen:**
- Jeder Dateiname pruefen:
  - Nur lowercase ASCII + Bindestriche + `.md`? (Regex: `^[a-z0-9-]+\.md$`)
  - Keine Umlaute (ae/oe/ue als Ersetzung ist korrekt in Dateinamen)?
  - Keine Leerzeichen, keine Sonderzeichen ausser Bindestrich?
- Eindeutigkeit pruefen: Kein Dateiname doppelt ueber verschiedene Verzeichnisse
  (Obsidian Shortest-Path bricht bei Namenskollisionen)
- **Output:** Tabelle `| Datei | Verstoesse |`

**1.4 Graph-Konnektivitaet:**
- **Waisen:** Seiten mit 0 eingehenden Wikilinks (keine andere Seite verlinkt hierher)
  - Ausnahmen: MOC-Seiten, `_index/`-Dateien, `_log.md`, `_vokabular.md`
- **Sackgassen:** Konzeptseiten mit 0 ausgehenden Wikilinks (keine Links zu anderen Seiten)
  - Nur fuer `type: konzept`, `type: verfahren`, `type: baustoff`
- **MOC-Abdeckung:** Konzeptseiten ohne mindestens eine MOC-Zuordnung im `mocs:`-Feld
- **Output:** Listen: Waisen, Sackgassen, MOC-lose Konzepte

**1.5 Dataview-Kompatibilitaet:**
- Felder die Dataview-Queries verwenden muessen korrekte Typen haben:
  - `schlagworte:` → YAML-Array `[Term1, Term2]`, nicht String `"Term1, Term2"`
  - `mocs:` → YAML-Array
  - `reviewed:` → boolean oder ISO-Datum, nicht String `"ja"` oder `"nein"`
  - `quellen-anzahl:` → Zahl, nicht String `"5"`
- **Output:** Tabelle `| Seite | Feld | Ist-Typ | Soll-Typ |`

**1.6 Obsidian-Vault-Konfiguration:**

<NICHT-VERHANDELBAR>
Der Soll-Zustand wird aus `governance/obsidian-setup.md` gelesen, NIE hardcoded.
Wenn sich die Setup-Doku aendert, aendert sich was der Review als "korrekt" betrachtet.
</NICHT-VERHANDELBAR>

**Schritt 1.6.1 — .obsidian/ Existenz:**
- Existiert `wiki/.obsidian/`? Falls nein → ERROR: "Vault-Konfiguration fehlt.
  Obsidian erkennt wiki/ ohne `.obsidian/` nicht als Vault."
- Falls nein: restliche 1.6-Checks ueberspringen (kein Soll/Ist-Vergleich moeglich)

**Schritt 1.6.2 — app.json Pflicht-Keys:**
- Read `wiki/.obsidian/app.json`
- Read `governance/obsidian-setup.md`, extrahiere den `app.json`-Block
- Pflicht-Keys aus der Setup-Doku (dynamisch, nicht hardcoded):
  `useMarkdownLinks`, `newLinkFormat`, `strictLineBreaks`, `showFrontmatter`
- Fuer jeden Pflicht-Key:
  - Key fehlt → WARN: "Einstellung `[key]` nicht gesetzt"
  - Key vorhanden, Wert weicht ab → WARN: "Einstellung `[key]`: ist `[ist]`, soll `[soll]`"
- `defaultOpenFile: "home"` nur pruefen wenn `wiki/home.md` existiert
- **Output:** Tabelle `| Key | Soll | Ist | Status |`

**Schritt 1.6.3 — Graph-View-Gruppen:**
- Read `wiki/.obsidian/graph.json` (falls vorhanden)
- Nutze **TYP_VERZEICHNIS_MAP** aus Phase 0.9
- Fuer jedes existierende Wiki-Verzeichnis aus der Map (nicht fuer leere/fehlende):
  - Gibt es eine Graph-Gruppe mit `path:verzeichnisname/`-Query? → OK
  - Fehlt die Gruppe → WARN: "Graph-Gruppe fuer `[verzeichnis]/` nicht konfiguriert —
    Seiten dieses Typs haben keine eigene Farbe im Graph View"
- Graph-Filter pruefen: Enthaelt der Filter `-path:quellen/` und `-path:_index/`?
  Falls nein → INFO: "Empfohlener Graph-Filter fehlt (Quellen/Index ausblenden)"
- `graph.json` fehlt komplett → WARN: "Keine Graph-View-Konfiguration.
  Alle Seitentypen erscheinen in gleicher Farbe."
- **Output:** Tabelle `| Seitentyp | Verzeichnis | Graph-Gruppe | Status |`

---

### Phase 2: Content-Layer (STICHPROBE — 15 Seiten gemischt)

Zufaellige Auswahl von 15 Seiten, gemischt ueber alle Typen:
- Mindestens 3 Quellenseiten
- Mindestens 3 Konzeptseiten
- Rest gemischt (Normen, Verfahren, Baustoffe, sofern vorhanden)
- Keine `_index/`-Dateien, keine MOCs, keine `_log.md`

Falls das Wiki <15 inhaltliche Seiten hat: alle pruefen.

**2.1 H2-Reihenfolge (nur Konzeptseiten):**
- Alle `## `-Header extrahieren
- Gegen **SOLL_REIHENFOLGE** vergleichen:
  - Fehlende Pflicht-H2? → melden
  - Falsche Reihenfolge? → melden (z.B. Formeln vor Einsatzgrenzen)
  - Zusaetzliche H2? → INFO (nicht Fehler)
- **Output:** `| Seite | Ist-Reihenfolge | Abweichungen |`

**2.2 check-wiki-output.sh (alle Stichproben-Seiten):**
- Pro Seite ausfuehren: `bash hooks/check-wiki-output.sh <datei>`
- Ergebnis (PASS/FAIL + Befunde) dokumentieren
- **Output:** `| Seite | Ergebnis | Befunde |`

**2.3 Quellenqualitaet (nur Konzeptseiten):**
- `quellen-anzahl:` Wert lesen
- Tatsaechliche Wikilinks im `## Quellen`-Abschnitt zaehlen
- Stimmt der Wert ueberein?
- Wikilink-Dichte: Links pro Absatz im Body (ohne Frontmatter)
  - <1 Link pro 3 Absaetze → WARN: Niedrige Verlinkungsdichte
- **Output:** `| Seite | quellen-anzahl | Tatsaechlich | Wikilink-Dichte |`

**2.4 Widerspruchs-Format:**
- Suche nach `[WIDERSPRUCH` (Plaintext-Format) → akzeptabel (hard-gates.md verwendet dieses Format)
- Suche nach `> [!CAUTION]` (Obsidian Callout-Syntax) → bevorzugt (besser sichtbar in Obsidian)
- Mischen von beiden Formaten auf einer Seite → melden als INKONSISTENZ
- Kein Widerspruchs-Marker aber Quellen divergieren → INFO (kein Fehler, aber Hinweis)
- **Output:** `| Seite | Format | Status |`

**2.6 PDF-Link-Drift (nur Quellenseiten mit pdf:-Feld):**
- Suche nach Plaintext-Seitenangaben: Regex `\(S\.\s*\d+` (matcht `(S. 32)`, `(S. 42-48)`)
- Suche nach klickbaren PDF-Links: Regex `\[\[[^\]]+\.pdf#page=\d+`
- Bewertung pro Seite:
  - Plaintext-Referenzen vorhanden + PDF-Links vorhanden → TEILWEISE MIGRIERT
  - Nur Plaintext, keine PDF-Links → NICHT MIGRIERT
  - Nur PDF-Links, kein Plaintext → OK (aktuelles Format)
- Zaehle: Wieviele Plaintext-Referenzen vs. PDF-Links pro Seite?
- Fuer Migration noetige Daten auf der Seite selbst vorhanden:
  - `pdf:` im Frontmatter → PDF-Dateiname
  - `autor:` + `jahr:` → Link-Alias
  - Seitenzahl aus dem Plaintext `(S. N)` → `#page=N`
- **Output:** `| Seite | Plaintext-Refs | PDF-Links | Status | Migrierbar |`

**2.5 Review-Freshness:**
- `reviewed:` Wert lesen
  - `false` → seit wann? (`synth-datum:` oder `ingest-datum:` als Referenz)
  - ISO-Datum → wie alt?
  - >30 Tage seit Erstellung ohne Review → WARN
- **Output:** `| Seite | reviewed | Alter (Tage) | Status |`

---

### Phase 3: Meta-Konsistenz

**3.1 _log.md — Offene Marker:**
- Read `wiki/_log.md` (falls vorhanden)
- Suche nach `[INGEST UNVOLLSTAENDIG]` und `[SYNTHESE UNVOLLSTAENDIG]`
- Jeder offene Marker → melden mit Kontext (welcher Ingest/Synthese, Datum)
- **Output:** Liste offener Marker mit Kontext

**3.2 _index/ — Eintraege vs. Seiten:**
- Fuer jede `_index/*.md`-Datei:
  - Extrahiere alle Eintraege (Wikilinks in der Index-Datei)
  - Pruefe: Existiert die verlinkte Seite? → Verwaister Index-Eintrag
  - Umgekehrt: Gibt es Seiten des entsprechenden Typs die NICHT im Index stehen? → Fehlender Eintrag
- **Output:** `| Index-Datei | Verwaiste Eintraege | Fehlende Eintraege |`

**3.3 _pending.json — Verwaist?**
- Existiert `wiki/_pending.json`?
  - Ja → lesen, Zeitstempel pruefen
  - `timestamp` aelter als 2 Stunden → WARN: Vermutlich verwaist
  - Melden: Typ, Stufe, Quelle, Alter
- **Output:** Status der Pipeline-Lock

**3.5 Bootstrap-Vollstaendigkeit (content-driven):**

Nutze **TYP_VERZEICHNIS_MAP** aus Phase 0.9 und **INVENTAR** aus Phase 0.8.
Kein Verzeichnis wird pauschal als fehlend gemeldet — die Bewertung haengt
davon ab ob das Wiki Inhalte hat die das Verzeichnis brauchen.

Fuer jedes Typ→Verzeichnis-Paar aus der Map:
1. **Verzeichnis existiert** → OK
2. **Verzeichnis fehlt + Seiten dieses Typs existieren an anderer Stelle**
   (z.B. `type: norm` in `wiki/konzepte/` statt `wiki/normen/`)
   → ERROR: "N Seiten vom Typ X liegen falsch. Verzeichnis anlegen und verschieben."
3. **Verzeichnis fehlt + Quellenseiten referenzieren diesen Typ**
   (z.B. Quellenseiten enthalten Normverweise aber `normen/` fehlt)
   → WARN: "Verzeichnis nicht angelegt, aber N Quellen verweisen auf Inhalte dieses Typs."
4. **Verzeichnis fehlt + kein Inhalt dieses Typs im Wiki**
   → INFO: "Verzeichnis nicht angelegt. Wird beim ersten Ingest/Synthese mit Inhalt
   dieses Typs automatisch benoetigt."

Sonderregeln:
- `moc/` → erst ab >=10 Konzeptseiten als WARN melden ("Navigation via MOCs empfohlen"),
  darunter nur INFO
- `_index/` und `pdfs/` (Infrastruktur) → immer ERROR wenn fehlend
  (ohne Index keine Katalog-Uebersicht, ohne pdfs/ keine PDF-Verlinkung)

- **Output:** `| Verzeichnis | Soll-Typ | Status | Seiten | Empfehlung |`

**3.6 config/valid-types.txt — Sync mit seitentypen.md:**
- Lade `hooks/config/valid-types.txt` (aus Phase 0.4)
- Lade **TYP_VERZEICHNIS_MAP** (aus Phase 0.9)
- Vergleiche: Jeder Typ in valid-types.txt muss in seitentypen.md existieren und umgekehrt
  - Typ in valid-types.txt aber NICHT in seitentypen.md → ERROR: "Typ in Hook-Config aber nicht in Governance"
  - Typ in seitentypen.md aber NICHT in valid-types.txt → ERROR: "Typ in Governance aber nicht in Hook-Config"
  - Alle synchron → OK
- **Output:** `| Typ | valid-types.txt | seitentypen.md | Status |`

**3.4 _vokabular.md — Aggregierte Nutzungsanalyse:**
- Alle definierten Terme in `wiki/_vokabular.md` laden
- Fuer jeden Term: In wie vielen Seiten wird er im `schlagworte:`-Feld verwendet?
  - 0 Verwendungen → melden als "potentiell veraltet"
- Umgekehrt: Alle `schlagworte:`-Werte aus allen Seiten sammeln
  - Term nicht in `_vokabular.md` definiert? → melden als "undefiniert"
- **Output:** `| Term | Definiert | Verwendet (Anzahl Seiten) | Status |`

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

**3b.7 BIBTEX-KEY-CHECK (bedingt):**

Nur aktiv wenn `literatur.bib` ODER `literatur/QUELLEN-MATRIX.md` im Projekt-Root
oder unter `Masterarbeit/literatur/` existiert.

- Fuer JEDE Wiki-Quellenseite: Hat sie ein `bibtex-key:` Feld im Frontmatter?
- Zaehle: X von Y Quellenseiten haben bibtex-key
- Falls fehlende:
  → WARN: "X von Y Quellenseiten ohne bibtex-key. Fuer Wiki-Bridge-Integration
  (SPEC-013) muessen bibtex-keys nachgepflegt werden."
- KEIN FAIL — rein informativ. Fehlende bibtex-keys verhindern kein Review.

---

### Phase 4: Abdeckungs-Check

**4.1 Konzept-Kandidaten ohne eigene Seite:**
- Primaer: Lies `_konzept-reife.md` → alle Eintraege mit `status: reif` ohne Konzeptseite
- Fallback (falls `_konzept-reife.md` nicht existiert):
  Alle `konzept-kandidaten:`-Eintraege aus allen Quellenseiten sammeln,
  gruppieren nach `term:`, Terme mit >=2 Quellen und ohne Konzeptseite → melden
- **Output:** `| Kandidat | Quellen (Anzahl) | Quellenseiten | Quelle (Reife-Datei/Frontmatter) |`

**4.2 Verwaiste Quellenseiten:**
- Quellenseiten die von KEINER Konzeptseite im `## Quellen`-Abschnitt verlinkt werden
- Melden als: "Quellenseite ohne Konzept-Verlinkung — Synthese-Kandidat"
- **Output:** `| Quellenseite | Eingehende Konzept-Links |`

---

### Phase 5: Ergebnis + Stufe-2-Empfehlung

Quick-Scan Report (Chat-Output, kein File):

```markdown
## Quick-Scan: [DATUM]

### Obsidian-Integritaet (exhaustiv, N Seiten)
- Frontmatter: X/N vollstaendig, Y fehlende Felder
- Links: X aufloesbar, Y gebrochen
- Dateinamen: X/N konform, Y Verstoesse
- Graph: X Waisen, Y Sackgassen, Z MOC-lose Konzepte
- Dataview: X/N kompatibel, Y Typfehler
- Vault-Konfiguration: .obsidian/ [vorhanden|fehlt], app.json [X/Y Keys korrekt], Graph-Gruppen [X/Y Typen konfiguriert]

### Content-Qualitaet (Stichprobe, M Seiten)
- Struktur (Konzeptseiten): X/M aktuelle H2-Reihenfolge
- check-wiki-output: X/M PASS
- Quellenqualitaet: Durchschnitt N Quellen pro Konzeptseite
- PDF-Link-Drift: X/M Quellenseiten mit Plaintext-Refs statt PDF-Links
- Widerspruchs-Format: X aktuell (Callout), Y veraltet (Plaintext)
- Reviews: X ueberfaellig (>30 Tage)

### Meta-Konsistenz
- _log.md: X offene Marker
- _index/: X verwaiste Eintraege, Y fehlende Eintraege
- _pending.json: [frei | verwaist seit HH:MM | nicht vorhanden]
- _vokabular.md: X unbenutzte Terme, Y undefinierte Schlagworte
- Bootstrap: X ERROR, Y WARN, Z INFO [Details pro Verzeichnis]

### Discovery-Gesundheit
- Discovery-Dateien: [vorhanden | fehlen (Synthese gelaufen: ja/nein)]
- Stale: [aktuell | N Synthese-Laeufe seit letztem Update]
- Reife Kandidaten ohne Seite: X (aeltester seit [Datum])
- Schlagwort-Rueckstau: X offene Vorschlaege (aeltester seit [Datum])
- Konsistenz: X Kandidaten nicht in Reife-Datei
- Ghosts: X "erstellt"-Eintraege ohne Konzeptseite

### Abdeckung
- Konzept-Kandidaten mit >=2 Quellen ohne Seite: X
- Verwaiste Quellenseiten: Y

### Empfehlung
[Alles OK — kein Full-Audit noetig]
ODER
[Full-Audit empfohlen:
  - Obsidian: N Probleme (Frontmatter: X, Links: Y, Dateinamen: Z)
  - Content-Drift: M gleiche Muster in Stichprobe (Typ: [Beschreibung])
  - Abdeckung: K Synthese-Kandidaten]
```

**Schwellwerte fuer Full-Audit-Empfehlung:**
- Obsidian-Layer: JEDER Fund → Full-Audit empfehlen fuer die betroffene Kategorie
  (ein gebrochener Link ist einer zu viel)
- Vault-Konfiguration: Fehlende `.obsidian/` → sofortige Empfehlung (kein Full-Audit noetig,
  sondern direkte Behebung: Konfiguration anlegen). Falsche Keys/fehlende Graph-Gruppen
  → als Obsidian-Fix in den Migrationsplan aufnehmen (kein Full-Audit-Trigger,
  da die Loesung immer dieselbe ist: Setup korrigieren)
- Content-Layer: >=2 Seiten mit dem GLEICHEN Drift-Muster in der 15er Stichprobe
  → Full-Audit empfehlen (ein Einzelfund ist Ausreisser, zwei sind Muster)
- Abdeckung: Rein informativ, kein Full-Audit-Trigger

**Nutzer entscheidet** ob Full-Audit durchgefuehrt wird.

---

### Phase 6: Full-Audit (batchweise, auf Nutzer-Anfrage)

<NICHT-VERHANDELBAR>
Full-Audit wird NUR nach expliziter Nutzer-Bestaetigung durchgefuehrt.
Nie automatisch starten, auch wenn der Quick-Scan Befunde hat.
</NICHT-VERHANDELBAR>

**Batch-Strategie (nach Verzeichnis, wegen Token-Budget):**

| Batch | Verzeichnis | Beschreibung |
|-------|-------------|-------------|
| 1 | `wiki/quellen/` | Alle Quellenseiten |
| 2 | `wiki/konzepte/` | Alle Konzeptseiten |
| 3 | `wiki/normen/` + `wiki/verfahren/` + `wiki/baustoffe/` | Spezialseiten |
| 4 | `wiki/_index/` + MOCs + Sonderdateien | Navigationsstruktur |

Pro Batch: Report generieren, dann naechster Batch.
Grund: Token-Budget. 50 Seiten x 500 Zeilen = 25K Zeilen → Split noetig.

**Pro Seite (Obsidian + Content komplett):**

1. **Frontmatter-Drift:** Fehlende Pflicht-Felder (aus aktuellem Template, Phase 0)
2. **Link-Drift:** Falsche Syntax, gebrochene Links, fehlende Aliases
3. **PDF-Link-Drift:** Plaintext `(S. N)` statt `[[pdf#page=N|Autor Jahr, S. N]]`
4. **Struktur-Drift:** H2-Reihenfolge gegen **SOLL_REIHENFOLGE** (nur Konzeptseiten)
5. **Konventions-Drift:** Dateinamen, Umlaut-Handling
6. **Inhalts-Qualitaet:** `quellen-anzahl`, Wikilink-Dichte, offene Marker
7. **check-wiki-output.sh:** Alle 12 deterministischen Checks ausfuehren
8. **Review-Alter:** `reviewed: false` seit wann?

**Befunde kategorisieren:**

| Kategorie | Behebbar | Beispiel |
|---|---|---|
| **Obsidian-Fix** | Automatisch (Frontmatter, Links) | `materialgruppe:` fehlt, Link-Alias korrigieren |
| **PDF-Link-Migration** | Automatisch (mechanisch) | `(S. 32)` → `[[pdf#page=32\|Autor Jahr, S. 32]]` |
| **Restrukturierung** | Semi-automatisch (/synthese) | Randbedingungen nach statt vor Formeln |
| **Inhaltsluecke** | Manuell (/ingest, /synthese) | Konzept hat nur 1 Quelle |
| **Veraltet** | Review noetig | `reviewed: false` seit >30 Tagen |

**Migrationsplan generieren:**

```markdown
## Full-Audit Report: [DATUM]

### Befund-Uebersicht
- N Seiten geprueft
- X Migrationen (automatisch behebbar)
- Y Restrukturierungen (Synthese noetig)
- Z Inhaltsluecken (Ingest/Synthese noetig)
- W Reviews ueberfaellig

### Migration-Batch: Frontmatter (automatisch)
Die folgenden X Seiten brauchen nur Frontmatter-Ergaenzungen.
Soll ich das als Batch durchfuehren? (Schreibt via /synthese oder direkt)

| Seite | Fehlend | Aktion |
|---|---|---|
| [pfad] | [felder] | Ergaenze: `[feld]: [wert]` |
| ... | ... | ... |

### Migration-Batch: PDF-Links (automatisch)
Die folgenden X Seiten haben Plaintext-Seitenangaben `(S. N)` die
mechanisch in klickbare PDF-Links umgewandelt werden koennen.
Alle noetigten Daten stehen auf der Seite selbst:
- `pdf:` Frontmatter-Feld → PDF-Dateiname
- `autor:` + `jahr:` → Link-Alias
- Seitenzahl aus `(S. N)` → `#page=N`

Transformation: `(S. N)` → `([[pdf-datei.pdf#page=N|Autor Jahr, S. N]])`

Soll ich das als Batch durchfuehren?

| Seite | Plaintext-Refs | PDF-Datei | Migrierbar |
|---|---|---|---|
| [pfad] | [anzahl] | [pdf-feld] | ja/nein (pdf:-Feld vorhanden?) |
| ... | ... | ... | ... |

Nicht migrierbar (kein `pdf:`-Feld, z.B. Markdown/URL-Quellen): separat listen.

### Restrukturierungen (manuell — Nutzer entscheidet)
| Seite | Problem | Vorschlag |
|---|---|---|
| [pfad] | [beschreibung] | `/synthese [konzept]` mit aktualisiertem Template |
| ... | ... | ... |

### Inhaltsluecken
| Konzept-Kandidat | Quellen | Vorschlag |
|---|---|---|
| [term] | [anzahl] Quellen | `/synthese [term]` |
| ... | ... | ... |

### Review-Kandidaten
| Seite | reviewed | Alter (Tage) | Vorschlag |
|---|---|---|---|
| [pfad] | false | [n] | Review anstossen |
| ... | ... | ... | ... |

### Naechste Schritte
1. Migration-Batch ausfuehren? (X Seiten, ~Y Min)
2. Re-Synthese fuer Z Seiten einplanen?
3. Reviews fuer W Seiten terminieren?
```

**Report speichern:**
- Datei: `wiki/_reviews/review-[DATUM].md` (YYYY-MM-DD Format)
- Verzeichnis `wiki/_reviews/` beim ersten Full-Audit anlegen falls nicht vorhanden
- Bestehende Reports NICHT ueberschreiben (datierter Verlauf)
- Eintrag in `wiki/_log.md`:
  ```
  ## [DATUM] — Wiki-Review (Full-Audit)
  - Seiten geprueft: N
  - Befunde: X Obsidian-Fix, P PDF-Link-Migration, Y Restrukturierung, Z Inhaltsluecke, W Veraltet
  - Report: [[_reviews/review-[DATUM]]]
  ```

---

## Edge Cases

| Situation | Verhalten |
|---|---|
| Leeres Wiki (0 Seiten) | "Wiki ist leer. Starte mit `/ingest`." — Kein Scan |
| Wiki nur mit Quellenseiten | Abdeckungs-Analyse betonen, Konzept-Kandidaten prominent listen |
| Wiki >200 Seiten | Obsidian-Layer bleibt exhaustiv (lightweight: nur Frontmatter + Links). Content-Layer sampelt wie gehabt (15 Seiten) |
| Template hat sich seit letztem Ingest geaendert | Genau dafuer ist der Drift-Check: alte Seiten gegen neuen Standard melden |
| `_pending.json` offen waehrend Review | Melden, nicht loeschen (Review ist read-only) |
| `_log.md` mit offenem Marker | Melden + Link zum letzten Ingest-Eintrag |
| Vokabular-Term in 0 Seiten | Melden als "potentiell veraltet" (nicht loeschen) |
| Review waehrend laufendem Ingest | Harmlos (read-only), aber Ergebnis kann verrauscht sein — Hinweis ausgeben |

---

## Haeufigkeit

Wiki-Review sollte regelmaessig laufen:
- Nach jedem 3. Ingest
- Alle 14 Tage
- Vor groesseren Synthese-Durchlaeufen

`using-bibliothek` prueft automatisch beim Session-Start:
1. Kein `wiki/_reviews/` → "Noch kein Review. `/wiki-review` empfohlen?"
2. Letzter Review >3 Ingests oder >14 Tage her → "Review empfohlen"
3. Sonst → Schweigen (kein Hinweis)
