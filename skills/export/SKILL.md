---
name: export
description: "Wiki-Inhalte exportieren — Uebersichten, Vergleichstabellen, Zusammenfassungen"
---

## Governance-Vertrag

> Export ist ein READ-ONLY Skill zur Generierung von Dokumenten aus Wiki-Inhalten.
> Er modifiziert das Wiki niemals, verursacht daher keine Diffs oder Nebeneffekte.
> Nur KORREKTE-UMLAUTE ist aktiv; alle anderen Gates sind nicht anwendbar.

| Gate | Durchsetzung | Wie |
|------|-------------|-----|
| KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG | ⚪ N/A | Export liest bestehende Wiki-Seiten |
| KEIN-INHALT-OHNE-SEITENANGABE | ⚪ N/A | Nur Leseoperationen |
| KEIN-ZAHLENWERT-OHNE-QUELLE | ⚪ N/A | Nur Leseoperationen |
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | ⚪ N/A | Nur Leseoperationen |
| KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS | ⚪ N/A | Nur Leseoperationen |
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | ⚪ N/A | Nur Leseoperationen |
| KEIN-UPDATE-OHNE-DIFF | ⚪ N/A | Keine Aenderungen |
| KEIN-WIDERSPRUCH-OHNE-MARKIERUNG | ⚪ N/A | Nur Leseoperationen |
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | ⚪ N/A | Keine Aenderungen |
| KORREKTE-UMLAUTE | ✅ Aktiv | Export-Output wird auf korrekte Umlaute geprueft |

---

## Phasen

### Phase 0: Anfrage analyse

1. **Anfrage-Typ klassifizieren:**
   - **Zusammenfassung:** Abstrakt eines Konzepts / einer Quelle
   - **Vergleichstabelle:** Mehrere Konzepte / Quellen gegenueberstellen
   - **Thema-Uebersicht:** Alle Seiten zu einem Schlagwort/MOC auflisten
   - **Lektuerempfehlung:** Buecher zu einem Thema empfehlen (Reihenfolge + Beggruendung)
   - **Formel-Sammlung:** Alle Formeln zu einem Konzept+Quellen
   - **Zahlenwert-Tabelle:** Alle Parameter+Werte aus mehreren Quellen

2. **Scope definieren:**
   - Welche Wiki-Seiten sind relevant?
   - Wie tief soll der Export gehen? (nur Frontmatter / Zusammenfassung / Volltexte?)
   - Format: Markdown / HTML / Tabelle (TSV/CSV)?

---

### Phase 1: Daten sammeln + strukturieren

**1a: Zusammenfassung (Konzept oder Quelle)**

Lade Zielseite:
- Frontmatter (Titel, Schlagworte, Quellen, Kategorie)
- Erste 2-3 Absaetze oder "Zusammenfassung"-Sektion
- Alle Wikilinks zu verwandten Konzepten
- Quellen-Tabelle (aus Konzeptseiten: "Wo nachschlagen")

Output:
```markdown
# [Titel]

**Kategorie:** [aus Frontmatter]
**Schlagworte:** [Komma-separiert]

## Definition
[Zusammenfassung aus Seite]

## Verwandte Themen
- [[Konzept1]]
- [[Konzept2]]

## Hauptquellen
| Quelle | Kapitel | Seiten | Schwerpunkt |
|--------|---------|--------|-------------|
[Aus Tabelle]
```

**1b: Vergleichstabelle (Mehrere Konzepte)**

Lade alle Zielseiten:
- Pro Seite: Titel, Definition (kurz), Schlagworte, Quellenanzahl, Review-Status
- Optional: Pro Zeile ein spezielles Attribut (z.B. "Formeln vorhanden?", "Gueltigkeitsbereich")

Output: Markdown-Tabelle oder CSV/TSV

```markdown
| Konzept | Definition | Quellen | Formeln | Review |
|---------|-----------|---------|---------|--------|
| Querkraft | ... | 5 | Ja | aktuell |
| Durchstanzen | ... | 3 | Nein | alt |
```

**1c: Thema-Uebersicht**

Lade alle Seiten mit Schlagwort X:
- Durchsuche _index nach Schlagwort
- Oder durchsuche MOC-Seite nach Eintraegen
- Pro Seite: Titel, Seitentyp (Konzept/Norm/Verfahren/Baustoff), Quellenanzahl

Output: Nested List oder Tabelle

```markdown
# Thema: Querkraft-Transfer

## Konzepte (3)
- [[Querkraft-Transfer]]
- [[Aufhaengebewehrung]]
- [[Rueckstau]]

## Normen (2)
- [[EC5 3.2.3]]
- [[EC2 6.2]]

## Quellen (7)
- Fingerloos EC2 (Kapitel 6)
- ...
```

**1d: Lektuerempfehlung**

Lade Quellenseiten zu einem Thema:
- Pro Quelle: Titel, Relevanz (Frontmatter), Kapitel die Thema X decken, Seitenzahl, Voraussetzungen
- Sortiere nach: Reihenfolge des Lesens (von einfach zu komplex oder chronologisch)

Output: Nummerierte Liste mit Begruendungen

```markdown
# Lektuerempfehlung: Querkraft-Transfer

## Stufe 1 — Grundlagen
1. **Schrift A** — Kap. 2, S. 30-50
   - Einfache Intro, gute Diagramme
   - ~2h Lesedauer

## Stufe 2 — Vertiefung
2. **Schrift B** — Kap. 5-6, S. 120-180
   - Formeln, rechnerische Beispiele
   - Benoetigt: Verstaendnis von Stufe 1
   - ~4h Lesedauer
```

**1e: Formel-Sammlung**

Lade alle Konzeptseiten zu Thema X:
- Durchsuche nach "## Formeln"-Sektion
- Pro Formel: Quelle, Annahmen, Gueltigkeitsbereich, Text-Erklaerung

Output: Markdown mit Formel-Liste + Quellenverweise

```markdown
# Formeln: Querkraft-Transfer

## Formel 1: Querkraft-Kapazitaet (EC5)

$V = k_1 \cdot f_v \cdot A$

**Quelle:** EC5 3.2.3, [Buch], Seite N
**Variablen:**
- $V$: Querkraft-Kapazitaet [kN]
- $k_1$: Form-Faktor [-]
- $f_v$: Schubfestigkeit [N/mm²]
- $A$: Scherflasche [mm²]

**Gueltig fuer:** Nadelholz, Nutzungsklasse 1+2
**Quellen:** [Fingerloos], [CEN/TS], ...
```

**1f: Zahlenwert-Tabelle**

Lade Konzeptseiten + ihre "Zahlenwerte"-Sektionen:
- Durchsuche nach "## Zahlenwerte"-Tabellen
- Extrahiere alle Eintraege
- Sammle in einer grossen Vergleichstabelle

Output: Markdown-Tabelle oder CSV

```markdown
# Parameter + Werte: HBV-Baustoffe

| Parameter | Material | Wert | Einheit | Quelle | Bereich |
|-----------|----------|------|--------|--------|---------|
| Reibungskoeff. | BSH | 0.5 | - | [A], S. N | 0.4-0.6 |
| Rollschub | BSP | 0.8 | N/mm² | [B], S. M | 0.6-1.0 |
```

---

### Phase 2: Formatierung + Metadaten

**2a: Markdown-Rendering**
- Alle Wikilinks [[...]] beibehalten (zum Einschaetzen von Kontext)
- LaTeX-Formeln in `$...$` oder `$$...$$`
- Tabellen nach Markdown-Syntax
- Listen strukturiert

**2b: Quellenverweise einbinden**
- Pro Zeile/Abschnitt: Seitenangabe + Quellenangabe beibehalten
- Format: `[Quelle, S. N]` oder Fussnotenziffer

**2c: Header + Metadaten**

Jeder Export hat einen Meta-Header:
```markdown
---
export-typ: [zusammenfassung | vergleichstabelle | uebersicht | empfehlung | formeln | parameter]
thema: [Thema-Name]
export-datum: [HEUTE]
quellen: [Comma-separated wiki-links]
---

# [Titel]
```

---

### Phase 3: Ausgabe-Optionen

Export kann in mehreren Formaten bereitgestellt werden:

1. **Markdown:** Direkt im Chat zeigen oder als `.md`-Datei
2. **HTML:** Fuer Web-Rendering (ggf. CSS-Styling)
3. **CSV/TSV:** Fuer Tabellen-Exporte (importierbar in Excel)
4. **PDF:** Falls angefordert (via Pandoc oder Export-Skill)

Nutzer kann Format waehlen: "Gib mir die Tabelle als CSV"

---

### Phase 4: Ausgabe

1. **Umlaut-Check:** Export auf korrekte Umlaute prueft
2. **Quellenangaben verifizieren:** Alle Seitenangaben vorhanden?
3. **Zum Chat oder zur Datei ausgeben** (je nach Anfrage)

---

## Beispiele

**Anfrage 1:**
"Gib mir eine Zusammenfassung von Querkraft-Transfer"

→ Lade konzepte/querkraft-transfer.md
→ Output: Definition + Verwandte Themen + Tabelle "Wo nachschlagen"

---

**Anfrage 2:**
"Vergleiche Querkraft und Durchstanzen — Tabelle"

→ Lade beide Konzeptseiten
→ Output: Vergleichstabelle (Definition | Formeln | Quellen | Review-Status)

---

**Anfrage 3:**
"Welche Buecher sollte ich lesen zum Thema indirekte Lagerung? Gib eine Reihenfolge."

→ Lade katalog → Such Quellen zu "indirekt"
→ Output: Nummerierte Lektuerempfehlung mit Stufen + Lesedauer

---

**Anfrage 4:**
"Sammle alle Formeln zum Querkraft-Transfer in eine Tabelle (CSV)"

→ Durchsuche konzepte/querkraft-transfer.md + verwandte Seiten
→ Extrahiere Formel-Sektionen
→ Output: CSV mit Spalten: Formel | Name | Quelle | Seite | Gueltigkeitsbereich

---

## Nebeneffekte

**Keine.** Export modifiziert das Wiki nicht. Alle Ausgaben sind abgeleitet.

---

## Haeufigkeit + Trigger

Export wird angestossen wenn:
- Nutzer Synthesen / Vergleiche fuer seine Arbeit braucht
- Lektuereihenfolge fuer neues Thema geplant wird
- Tabellen fuer Literaturzusammenfassung gebraucht werden
- Formel-Sammlungen fuer Implementierung benoetigt werden
