# Namenskonvention — Bibliothek-Plugin

## Agent-Suffixe

| Suffix | Funktion | Output | Beispiel |
|--------|----------|--------|----------|
| **-pruefer** | Enge Pruefung, spezifische Gates | PASS/FAIL | vollstaendigkeits-pruefer, quellen-pruefer, konsistenz-pruefer, vokabular-pruefer |
| **-reviewer** | Breite Bewertung, mehrere Aspekte | Report mit Befunden | struktur-reviewer, norm-reviewer |
| **-validator** | Formatpruefung, technische Korrektheit | Syntax-Check | duplikat-validator |

## Bestehende Agents (7)

| Agent | Typ | Dispatcht von |
|-------|-----|---------------|
| vollstaendigkeits-pruefer | Pruefer | /ingest (Gate 1) |
| quellen-pruefer | Pruefer | /ingest (Gate 2) |
| konsistenz-pruefer | Pruefer | /ingest (Gate 3) |
| vokabular-pruefer | Pruefer | /ingest (Gate 4) |
| struktur-reviewer | Reviewer | /wiki-lint |
| norm-reviewer | Reviewer | /normenupdate |
| duplikat-validator | Validator | /wiki-lint, /ingest (Pre-Flight) |

## Gate-Reihenfolge (/ingest-Pipeline)

| Gate | Agent | Prueft |
|------|-------|--------|
| Gate 1 | vollstaendigkeits-pruefer | Alle Kapitel erfasst? Seitenangaben vorhanden? Schlagworte vollstaendig? |
| Gate 2 | quellen-pruefer | Seitenangaben korrekt? Zahlenwerte mit Quelle? Normverweise mit Abschnitt? |
| Gate 3 | konsistenz-pruefer | Widersprueche zu bestehenden Wiki-Seiten? Querverweise korrekt? |
| Gate 4 | vokabular-pruefer | Alle Schlagworte normiert? Keine Ad-hoc-Begriffe? |

## Rechtschreibung — Zwei Welten

| Kontext | Schreibweise | Beispiel |
|---------|-------------|---------|
| **Dateinamen** | ASCII, lowercase, Bindestriche | `aufhaengebewehrung.md` |
| **Schlagworte (Frontmatter)** | Deutsche Rechtschreibung, Nomen gross | `Querkraftübertragung` |
| **Vokabular (_vokabular.md)** | Deutsche Rechtschreibung, Nomen gross | `### Aufhängebewehrung` |
| **Wiki-Text** | Normale deutsche Sprache | Wie in einem Fachbuch |
| **Wikilinks** | Anzeigename deutsch, Aufloesung case-insensitive | `[[Querkraftübertragung]]` |

Grund: Dateinamen muessen maschinenlesbar sein (Shell, Git, URLs).
Alles was Menschen lesen folgt der deutschen Rechtschreibung.
check-wiki-output.sh Check 3 matcht case-insensitive (grep -qi).

## Dateinamen-Regeln

- Alle Dateinamen: Kleinbuchstaben, ASCII, Bindestriche
- Keine Umlaute in Dateinamen (ae statt ä, oe statt ö, ue statt ü, ss statt ß)
- Keine Leerzeichen (Bindestriche statt)
- Keine Sonderzeichen ausser Bindestrich

Beispiele:
- `quellen/fingerloos-ec2-2016.md` (nicht: `Fingerloos EC2 2016.md`)
- `konzepte/aufhaengebewehrung.md` (nicht: `Aufhängebewehrung.md`)
- `normen/ec2-9-2-5.md` (nicht: `EC2 §9.2.5.md`)

## Dateinamen-Eindeutigkeit (NICHT-VERHANDELBAR)

Dateinamen MUESSEN ueber ALLE Wiki-Verzeichnisse hinweg eindeutig sein.
Grund: Obsidian "shortest path" Wikilink-Aufloesung verlangt Eindeutigkeit.

VERBOTEN: `wiki/konzepte/querkraft.md` + `wiki/moc/querkraft.md` (Namenskollision)
ERLAUBT: `wiki/moc/moc-querkraft.md` (Praefix unterscheidet)

## Link-Konventionen

Drei Link-Typen, kontextabhaengig:

| Kontext | Ziel | Syntax |
|---------|------|--------|
| Beleg im Fliesstext | PDF mit Seitenangabe | `[[datei.pdf#page=N\|Autor Jahr, S. N]]` |
| ## Quellen-Abschnitt | Wiki-Quellenseite | `[[quellenseite\|Autor Jahr]]` |
| Fachbegriff | Konzeptseite | `[[konzeptname\|Anzeigename]]` |

Obsidian Shortest-Path-Aufloesung: Voller Pfad nicht noetig wenn Dateiname eindeutig.

### Alias-Konvention (title:-Feld)

Dateinamen bleiben ASCII-lowercase. Anzeigenamen ueber:
- Frontmatter `title:` → Obsidian zeigt in Sidebar
- Wikilink-Alias `[[dateiname|Anzeigename]]` → schoener Name im Text
