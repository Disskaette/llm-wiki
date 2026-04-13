# SPEC-005: Domain-Agnostik — Universelles Wiki-Plugin

**Status:** Planned
**Version:** 1.0
**Erstellt:** 2026-04-13
**Aktualisiert:** 2026-04-13

## Zusammenfassung

Das Plugin wird von einem Bauingenieurwesen-spezifischen Tool zu einem
universellen Wissens-Wiki generalisiert. Core-Typen (quelle, konzept) bleiben
fest. Domain-Typen (norm, baustoff, verfahren, moc, ...) entstehen dynamisch
aus dem Inhalt. Kategorien werden vom Worker angelegt und von Gate 4 validiert.
Bedingte Gates ersetzen immer-aktive domain-spezifische Regeln.

Fuer das bestehende Bauingenieur-Wiki aendert sich am Verhalten nichts — alle
Typen und Gates bleiben aktiv. Der Unterschied: konfiguriert statt hardcoded.

## Anforderungen

1. Core/Domain-Split in seitentypen.md (2 Core-Typen fest, Rest domain-konfiguriert)
2. Bedingte Gates in hard-gates.md (Gate aktiv nur wenn zugehoeriger Domain-Typ existiert)
3. Dynamische Kategorien via Vokabular-Oberbegriffe (Worker legt an, Gate 4 validiert)
4. Ingest-Bootstrap nur mit Core-Verzeichnissen, Domain-Verzeichnisse on-demand
5. Dispatch-Templates domain-agnostisch formuliert (keine hardcoded Beispiel-Domänen)
6. Shell-Hooks lesen Typen/Gates aus Config-Dateien statt hardcoded
7. Bestehendes Bauingenieur-Wiki funktioniert ohne Aenderung (Rueckwaertskompatibel)

## Nicht-Ziele

- Kein Multi-Domain-Wiki (ein Wiki = eine Domaene, aber die Domaene ist frei waehlbar)
- Keine GUI/Web-Konfiguration — alles via Markdown-Dateien und Config
- Kein Rewrite der Pipeline-Mechanik (Lock, Counter, FAIL-Check bleiben)

## Technische Details

### 3-Schichten-Architektur

```
CORE (immer, nicht konfigurierbar)
├── Typen: quelle, konzept
├── Verzeichnisse: quellen/, konzepte/, _index/
├── Gates: 8 universelle (VOLLSTAENDIGE-LESUNG, SEITENANGABE, ZAHLENWERT, ...)
├── Pipeline: Lock, Counter, FAIL-Check, ID-Matching
└── Infrastruktur: _vokabular.md, _log.md, pdfs/

DOMAIN (konfiguriert, entsteht aus Inhalt)
├── Typen: norm, baustoff, verfahren, moc, ... (beliebig erweiterbar)
├── Verzeichnisse: on-demand angelegt wenn erster Inhalt entsteht
├── Gates: bedingt (z.B. NORMBEZUG nur wenn Typ "norm" aktiv)
├── Kategorien: Level-1-Terme in _vokabular.md
└── Quellen-Unterordner: pdfs/<kategorie>/ on-demand

INSTANZ (das konkrete Wiki)
├── Quellen, Konzeptseiten, Normseiten, ...
├── Spezifisches Vokabular
└── Spezifische Kategorie-Hierarchie
```

### Aenderung 1: seitentypen.md — Core/Domain-Split

Aktuelle Struktur (6 feste Typen in einer Tabelle) wird aufgeteilt:

```markdown
## Core-Typen (immer vorhanden, nicht konfigurierbar)

| Typ | Beantwortet | Verzeichnis |
|-----|------------|-------------|
| quelle  | "Was steht in dieser Quelle?" | wiki/quellen/  |
| konzept | "Was ist das? Wie funktioniert es?" | wiki/konzepte/ |

## Domain-Typen (aktiv in diesem Wiki, erweiterbar)

| Typ | Beantwortet | Verzeichnis | Bedingter Gate |
|-----|------------|-------------|----------------|
| norm      | "Was fordert die Norm?"            | wiki/normen/     | KEIN-NORMBEZUG-OHNE-ABSCHNITT |
| baustoff  | "Welche Eigenschaften hat das Material?" | wiki/baustoffe/  | — |
| verfahren | "Wie rechne ich das nach?"         | wiki/verfahren/  | — |
| moc       | "Was gehoert thematisch zusammen?" | wiki/moc/        | — |
```

- Core-Typen: Hardcoded in der Spec, werden nie geaendert
- Domain-Typen: Editierbar. Neuer Typ = neue Zeile in der Tabelle
- Worker legt Domain-Typ + Verzeichnis automatisch an wenn er im Inhalt
  entsprechende Strukturen erkennt (Normverweise → norm, Materialkenndaten → baustoff)
- Gate 4 (Vokabular-Pruefer) validiert neue Typen
- config/valid-types.txt wird aus seitentypen.md synchronisiert (beide Tabellen)

### Aenderung 2: Bedingte Gates in hard-gates.md

Neues Feld `Bedingung:` pro Gate:

```markdown
<HARD-GATE: KEIN-NORMBEZUG-OHNE-ABSCHNITT>
Bedingung: Domain-Typ "norm" ist in seitentypen.md aktiv.
Jeder Normverweis (EC, DIN, EN, ISO, CEN/TS, ...) braucht eine
Abschnittsnummer oder Paragraphen-Angabe.
</HARD-GATE>
```

Gates OHNE Bedingung (die 8 universellen) gelten immer.
Gates MIT Bedingung: Agent liest seitentypen.md → prueft ob Domain-Typ existiert → wendet Gate an oder ueberspringt.

Betroffene Dateien:
- hard-gates.md (Bedingung hinzufuegen)
- using-bibliothek/SKILL.md (Inline-Kopie der Hard Gates synchron halten)
- Alle Skill-Governance-Tabellen (Spalte "Bedingung" ergaenzen)
- gate-dispatch-template.md (Agents pruefen Domain-Typ-Liste)
- quellen-pruefer Agent (Part A prueft Normbezuege nur wenn norm-Typ aktiv)

### Aenderung 3: Dynamische Kategorien

Aktuell: `kategorie: Holzbau | Stahlbeton | Bauphysik | ...` als festes Enum.
Neu: Level-1-Terme (`## Heading`) in `_vokabular.md` = erlaubte Kategorien.

Worker-Ablauf:
1. Quelle gelesen → Themenfeld identifiziert
2. Check _vokabular.md: existiert passender Level-1-Term?
3. Ja → als `kategorie:` verwenden
4. Nein → neuen Level-1-Term in _vokabular.md anlegen + als `kategorie:` setzen
5. Gate 4 validiert: Synonym eines bestehenden Terms? Duplikat? Falsche Hierarchie-Ebene?
6. Bei Gate-FAIL → Korrektur + Re-Gate

Erster Ingest in leeres Wiki: Worker bootstrappt die ersten Oberbegriffe.
Gate 4 prueft ob sie sinnvoll strukturiert sind.

Keine Config-Datei, keine Enum-Liste — das Vokabular IST die Konfiguration.

Betroffene Dateien:
- seitentypen.md (kategorie-Enum entfernen, Verweis auf _vokabular.md)
- ingest-dispatch-template.md (kategorie-Kommentar aendern)
- synthese-dispatch-template.md (materialgruppe analog)
- vokabular-regeln.md (Level-1 = Kategorien dokumentieren)
- ingest SKILL.md (Phase 2f: Kategorie-Abgleich beschreiben)

### Aenderung 4: Bootstrap nur Core-Verzeichnisse

Aktuelle Bootstrap-Liste in ingest SKILL.md Phase 0:
```
wiki/quellen/ konzepte/ normen/ baustoffe/ verfahren/ moc/ _index/ _pdfs/
```

Neue Bootstrap-Liste (nur Core + Infrastruktur):
```
wiki/quellen/ konzepte/ _index/ pdfs/
```

Alles andere wird on-demand angelegt:
- Worker erkennt Normverweise → `mkdir wiki/normen/` + Normseite erstellen
- Worker erkennt Materialkenndaten → `mkdir wiki/baustoffe/` + Baustoffseite erstellen
- 10+ Konzeptseiten → moc/ vorschlagen (wiki-review Phase 3.5 meldet das)

Betroffene Dateien:
- ingest SKILL.md Phase 0 Bootstrap (Liste kuerzen)
- wiki-claude-md.md (Verzeichnis-Dokumentation anpassen)
- obsidian-setup.md (Index-Dateien nur fuer Core)
- check-consistency.sh (erwartete Verzeichnisse dynamisch pruefen)

### Aenderung 5: Dispatch-Templates domain-agnostisch

Aktuell: Templates enthalten Bauingenieur-Beispiele (EC2, BSH, Holzbau...).
Neu: Generische Formulierungen + Platzhalter fuer domain-spezifische Regeln.

Neuer Platzhalter: `{{DOMAIN_GATES}}` — wird vom Hauptagent befuellt mit den
aktiven bedingten Gates (aus hard-gates.md + seitentypen.md abgeleitet).

Beispiel:
```
Aktive Domain-Gates fuer dieses Wiki:
{{DOMAIN_GATES}}
```

Bei einem Bauingenieur-Wiki wird das zu:
```
Aktive Domain-Gates fuer dieses Wiki:
- KEIN-NORMBEZUG-OHNE-ABSCHNITT: Jeder Normverweis braucht Abschnittsnummer
```

Bei einem Philosophie-Wiki: leer (keine domain-spezifischen Gates).

Betroffene Dateien:
- ingest-dispatch-template.md (Beispiele generalisieren, {{DOMAIN_GATES}})
- synthese-dispatch-template.md (analog)
- gate-dispatch-template.md (bedingte Prueflogik)

### Aenderung 6: Agents — Beispiele parametrisieren

Agent-Definitionen enthalten aktuell konkrete Bauingenieur-Beispiele
(EC2 §9.2.5, BSH GL24h, Rollschub-BSP). Diese werden durch generische
Platzhalter oder domain-agnostische Formulierungen ersetzt.

Betrifft:
- quellen-pruefer.md (Part A Normbezuege → nur wenn norm-Typ aktiv)
- konsistenz-pruefer.md (Beispiele generalisieren)
- norm-reviewer.md (wird zu "domain-type-reviewer" oder bleibt mit Bedingung)
- vollstaendigkeits-pruefer.md (schon weitgehend generisch)
- vokabular-pruefer.md (Kategorie-Validierung ergaenzen)

### Aenderung 7: Shell-Hooks und Config

check-wiki-output.sh liest bereits config/valid-types.txt. Erweiterung:

```
hooks/config/
├── valid-types.txt          ← existiert, wird um neue Domain-Typen erweitert
└── domain-gates.txt         ← NEU: Liste aktiver bedingter Gates
```

domain-gates.txt wird von check-consistency.sh gegen hard-gates.md validiert.

Synchronisation: check-wiki-output.sh liest valid-types.txt (wie bisher).
Wenn der Worker einen neuen Domain-Typ anlegt, ergaenzt er AUCH valid-types.txt
(eine Zeile append). check-consistency.sh validiert dass valid-types.txt und
seitentypen.md synchron sind — bei Mismatch: FAIL.

### Aenderung 8: wiki-review Anpassungen

wiki-review Phase 0.8 liest bereits seitentypen.md dynamisch. Ergaenzungen:
- Phase 3.5 ist schon content-driven (bereits implementiert)
- Neu: Pruefen ob config/valid-types.txt mit seitentypen.md synchron ist
- Neu: Melden wenn Domain-Typ in seitentypen.md steht aber kein Inhalt existiert
  (→ INFO, kein Fehler — Typ ist vorbereitet aber noch nicht befuellt)

## Akzeptanzkriterien

- [ ] seitentypen.md hat Core/Domain-Split mit klarer Trennung
- [ ] hard-gates.md hat Bedingungs-Feld bei domain-spezifischen Gates
- [ ] Worker legt Domain-Typ + Verzeichnis automatisch an bei Bedarf
- [ ] Worker legt Kategorien als Vokabular-Oberbegriffe an
- [ ] Gate 4 validiert neue Kategorien und Domain-Typen
- [ ] Bootstrap erstellt nur Core-Verzeichnisse + Infrastruktur
- [ ] Dispatch-Templates haben {{DOMAIN_GATES}} Platzhalter
- [ ] Agent-Beispiele sind domain-agnostisch oder parametrisiert
- [ ] config/valid-types.txt wird aus seitentypen.md abgeleitet
- [ ] Bestehendes Bauingenieur-Wiki funktioniert ohne Aenderung
- [ ] check-consistency.sh validiert Core/Domain-Split
- [ ] 19/19 Konsistenz-Checks PASS
- [ ] Alle bestehenden Hook-Tests PASS (Rueckwaertskompatibilitaet)

## Edge Cases

| Situation | Verhalten |
|---|---|
| Leeres Wiki, erster Ingest | Worker bootstrappt Core + erste Domain-Typen + Kategorien |
| Quelle passt in keinen bestehenden Domain-Typ | Worker erstellt nur Quellenseite + Konzeptseiten (Core) |
| Zwei Worker schlagen gleichen neuen Typ vor | Zweiter findet Verzeichnis schon vor, nutzt es |
| Domain-Typ wird aus seitentypen.md entfernt | Bestehende Seiten bleiben, wiki-review meldet Inkonsistenz |
| Gate mit Bedingung, Typ nicht aktiv | Gate-Agent ueberspringt die bedingte Pruefung, meldet "N/A" |
| valid-types.txt nicht synchron mit seitentypen.md | check-consistency.sh meldet FAIL |

## Abhaengigkeiten

- Keine externen Abhaengigkeiten
- Voraussetzung fuer SPEC-006 (Multi-Format-Ingest)
