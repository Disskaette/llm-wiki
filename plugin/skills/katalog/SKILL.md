---
name: katalog
description: "Bestandsuebersicht — Wiki navigieren, Abdeckung pruefen, Statistiken"
---

## Governance-Vertrag

> Katalog ist ein READ-ONLY Skill zur Navigation und Analyse des Wikis.
> Er modifiziert niemals Wiki-Inhalte, verursacht daher keine Nebeneffekte.
> Nur KORREKTE-UMLAUTE ist aktiv; alle anderen Gates sind nicht anwendbar.

| Gate | Durchsetzung | Wie | Bedingung |
|------|-------------|-----|-----------|
| KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG | ⚪ N/A | Katalog liest nicht; zeigt bestehende Metadaten | — |
| KEIN-INHALT-OHNE-SEITENANGABE | ⚪ N/A | Nur Leseoperationen | — |
| KEIN-ZAHLENWERT-OHNE-QUELLE | ⚪ N/A | Nur Leseoperationen | — |
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | ⚪ N/A | Nur Leseoperationen | — |
| KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS | ⚪ N/A | Nur Leseoperationen | — |
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | ⚪ N/A | Nur Leseoperationen | — |
| KEIN-UPDATE-OHNE-DIFF | ⚪ N/A | Keine Aenderungen | — |
| KEIN-WIDERSPRUCH-OHNE-MARKIERUNG | ⚪ N/A | Nur Leseoperationen | — |
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | ⚪ N/A | Keine Aenderungen | — |
| KORREKTE-UMLAUTE | ✅ Aktiv | Katalog-Output wird auf korrekte Umlaute geprueft | — |

---

## Phasen

### Phase 0: Indexdateien laden

1. **Verzeichnisstruktur auslesen:**
   - `wiki/_index/` komplett durchsuchen
   - Kategorien werden aus den Verzeichnissen unter wiki/ und den Typen in seitentypen.md dynamisch abgeleitet
   - _vokabular.md laden

2. **Metadaten sammeln:**
   - Pro Indexdatei: Anzahl Seiten, Review-Status, Kategorien
   - Relevante _MOC.md-Dateien identifizieren

---

### Phase 1: Query beantworten

**Query-Typen:**

1. **"Welche Buecher decken Thema X ab?"**
   - Suche in _index/quellen.md nach Stichworten (im Frontmatter + Kapitelindex)
   - Liste alle Quellenseiten mit Kapitel-Referenzen auf
   - Pro Quelle: Aufsummierung der relevanten Kapitel und deren Seitenangaben

2. **"Wie ist die Abdeckung von Thema X?"**
   - Suche in _index/konzepte.md nach Konzeptseite zu X
   - Zähle Quellen die das Konzept referenzieren
   - Identifiziere Luecken: Gibt es wenig oder nur alte Quellen?
   - Beurteile Abdeckung als gut/mittel/unzureichend mit Begruendung

3. **"Wie viele Buecher zu Kategorie Y?"**
   - Zaehle Seiten in wiki/quellen/ nach kategorie (Frontmatter)
   - Unterscheide Verarbeitungsstatus (vollstaendig / partiell / katalog-only)

4. **"Was ist unzureichend dokumentiert?"**
   - Suche nach Konzeptseiten mit <3 Quellenreferenzen
   - Suche nach verwaisten Normseiten (Norm vorhanden, aber keine Konzepte die sie nutzen)
   - Listen mit Verbesserungsvorschlaegen

---

### Phase 2: Statistiken (optional)

Falls angefordert, aus Wiki-Metadaten berechnen:

- **Quellen-Statistik:** Gesamt-, Vollstaendig-, Partiell-, Katalog-Only Seiten
- **Buecher nach Kategorie:** Tabelle mit Kategorie | Anzahl | Review-Status
- **Seiten insgesamt:** Alle Wiki-Dateien zaehlen (quellen + konzepte + normen + baustoffe + verfahren)
- **Seitenumfang:** Gesamtseiten aus allen Quellen (summieren aus ingest-log)
- **Review-Status:** % of complete pages with reviewed: true vs. false
- **Vokabular:** Anzahl Terme im _vokabular.md, nach Ebene/Hierarchie

---

### Phase 3: Ausgabe

1. **Kompakt-Modus:** Kurze, fokussierte Antwort auf die Frage
2. **Tabellen verwenden:** Uebersichtliche Formatierung fuer Vergleiche
3. **Vollstaendig-Links:** Wiki-Links [[...]] zu Konzept-/Normseiten
4. **Empfehlungen:** Ggf. Vorschlaege was als naechstes gelesen werden sollte

---

## Nebeneffekte

**Keine.** Katalog modifiziert das Wiki nicht.

---

## Dispatch

Katalog ist meist Ausgangspunkt fuer andere Skills:
- **Nach Katalog-Abdeckungsanalyse** → Ggf. `/synthese` fuer unterversorgte Konzepte
- **Nach Statistik** → Ggf. `/wiki-lint` zur tieferen Gesundheitspruefung

---

## Beispiele

**Anfrage:**
"Welche Buecher decken Thema X ab?"

**Katalog antwortet:**
- Listet Quellenseite + Kapitel/Seiten auf
- Zeigt, welche Quellen das Thema direkt oder indirekt behandeln
- Schlaegt vor zu /synthese zu gehen um Konzeptseite zu vertiefen

---

## Umlaut-Check

Alle Katalog-Ausgaben (Tabellenheader, Listentext) werden auf korrekte Umlaute geprueft.
