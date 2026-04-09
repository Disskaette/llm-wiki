---
name: synthese
description: "Konzeptseiten vertiefen — Quellen vergleichen, Formeln ausarbeiten, Widersprueche dokumentieren"
---

## Governance-Vertrag

> Synthese nimmt existierende Wiki-Seiten und vertieft sie durch Vergleich von Quellen,
> Ausarbeitung von Formeln, Markierung von Widerspruechen und Validierung.
> Mehrere Core-Gates sind aktiv; Phase 0.5 liest Original-PDFs (Gate 9 ist BLOCKIEREND).

| Gate | Durchsetzung | Wie |
|------|-------------|-----|
| KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG | ⚪ N/A | Synthese liest Kapitel, nicht ganze Buecher |
| KEIN-INHALT-OHNE-SEITENANGABE | ✅ Aktiv | Phase 1 + 2 setzen Seitenangaben bei jeden Aussage |
| KEIN-ZAHLENWERT-OHNE-QUELLE | ✅ Aktiv | Phase 1 recherchiert + vergleicht Zahlenwerte |
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | ✅ Aktiv | Phase 1 identifiziert Norm-Paragraphen exakt |
| KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS | ⚪ N/A | Synthese traegt zu Querverweisen bei, setzt sie nicht |
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | 🔄 Delegiert | Dispatch: vokabular-pruefer |
| KEIN-UPDATE-OHNE-DIFF | ✅ Aktiv | Phase 2 dokumentiert Diffs zwischen Alt + Neu |
| KEIN-WIDERSPRUCH-OHNE-MARKIERUNG | ✅ Aktiv | Phase 2 markiert ALLE Widersprueche mit [WIDERSPRUCH] |
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | ✅ Aktiv | Phase 0.5 liest ALLE referenzierten Quellen (PDF) |
| KORREKTE-UMLAUTE | ✅ Aktiv | Synthese-Output wird auf Umlaute geprueft |

**EXTERNER-INHALT-Marker:** Synthese liest PDFs → Wrapper erforderlich.

---

## Phasen

### Phase 0: Target identifizieren + Quellen laden

1. **Target-Seite laden:**
   - Existiert die Konzeptseite / Normseite / Verfahrensseite?
   - Frontmatter auslesen (aktuelle Quellen, Review-Status)
   - Existierende Wikilinks + Schlagworte notieren

2. **Referenzierte Quellen identifizieren:**
   - Alle Quellenangaben im Text durchlaufen
   - Alle Wikilinks zu Quellenseiten ([quellen/...])
   - Alle Norm-Paragraph-Verweise
   - Dateilisten erstellen: welche PDFs muessen geladen werden?

3. **Token-Budget pruefen:**
   - Zaehlen: Zielseite + alle Quell-Kapitel?
   - Falls >700K Tokens: Split-Plan erstellen (Quelle 1-2, dann 3-4, ...)
   - Falls <100K Tokens: Single-Shot moeglich

---

### Phase 0.5a: Planmodus-Pruefung

Synthese betrifft typischerweise >=2 Dateien (Konzeptseite + _index + _log).
→ EnterPlanMode BEVOR die erste Datei geschrieben wird.

Plan dokumentiert:
- Welche Konzeptseite wird vertieft?
- Welche PDFs muessen geladen werden?
- Welche Nebeneffekte (_index, _log, MOCs) werden beruehrt?

### Phase 0.5b: PDF-Lesung (BLOCKIERENDES GATE 9)

<NICHT-VERHANDELBAR>
Alle in Phase 0 identifizierten PDF-Kapitel MUESSEN vollstaendig gelesen werden.
Das ist Gate 9: KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG.
Kein Skipping, kein "scheint nicht relevant".
</NICHT-VERHANDELBAR>

1. **Pro referenzierte Quelle:**
   - PDF laden (SCHREIBPFAD — siehe CLAUDE.md)
   - Wrap: `<EXTERNER-INHALT>` marker
   - Relevante Kapitel komplett durchlesen
   - Extrahieren: Formeln, Zahlenwerte, Grenzen, Methoden, Widersprueche

2. **Kontext-Budget-Stopp:**
   - Falls Anzeichen von Kontext-Engpass: STOPP
   - Meldung an den Nutzer:
     "Synthese kann nicht abgeschlossen werden: X von Y Quellen gelesen.
     Empfehlung: Split-Synthese aktivieren oder Session fortsetzen."

---

### Phase 1: Vergleichende Analyse

**1a: Formeln vergleichen**
- Gibt es Formeln in den Quellen zu diesem Konzept?
- Alle Formeln auflisten mit:
  - Quelle (Buch + Seite)
  - Formel-Text
  - Herleitung / Annahmen
  - Gueltigkeitsbereich
- Sind Formeln identisch oder unterschiedlich?
- Falls unterschiedlich: Was sind die Unterschiede? Welche Annahmen erklaeren das?

**1b: Zahlenwerte vergleichen**
- Alle empirischen Zahlenwerte (z.B. "Reibungskoeffizient = 0.5") auflisten
- Pro Zahlenwert: Quelle, Kontext (Material? Temperatur?), Toleranzbereich
- Konvergieren oder divergieren die Werte?
- Falls divergent: Gibt es erklaerbare Gruende (unterschiedliche Materialien, Standards, ...)?

**1c: Norm-Paragraph-Analyse**
- Welche Normen werden referenziert?
- Exakte Abschnitte? (z.B. "EC5 3.2.3" oder nur "EC5 Kapitel 3")
- Wie interpretieren verschiedene Quellen denselben Absatz?
- Gibt es Unterschiede in der Interpretation?

**1d: Randbedingungen + Gueltigkeitsgrenzen**
- Pro Konzept: Unter welchen Bedingungen ist die Aussage gueltig?
- Material? Geometrie? Temperatur? Feuchte?
- Wo liegen die Grenzen?
- Sind diese explizit in den Quellen genannt oder implizit?

**1e: Widerspruch-Identifikation**
- Finden sich in den verschiedenen Quellen Aussagen die sich widersprechen?
- Z.B. Unterschiedliche Formeln fuer denselben Effekt?
- Z.B. Norm Edition 1 sagt A, Edition 2 sagt B?
- Dokumentieren ALLER Widersprueche mit Kontext

---

### Phase 2: Seite ausarbeiten + Diffs dokumentieren

**2a: Struktur aufbauen:**

```markdown
# Konzept: [NAME]

## Zusammenfassung
[1-3 Saetze Definition + Anwendungsbereich]

## Formeln

### Formel 1: [Name/Anwendungsfall]
[Formel in LaTeX oder Text]
- **Quelle:** [Buch], Seite N
- **Annahmen:** [Aufzaehlung]
- **Gueltig fuer:** [Randbedingungen]

[Wiederhole fuer alle Formeln]

## Zahlenwerte + Parameter

| Parameter | Wert | Einheit | Quelle | Bereich |
|-----------|------|--------|--------|---------|
| Reibungskoeff. | 0.5 | - | [Buch], S. N | 0.4-0.6 |

## Norm-Referenzen

- **EC5 3.2.3:** Querkraft-Nachweis → [Kommentar]
- **EC2 6.2:** Bewehrung → [Kommentar]

## Randbedingungen

- Materialgruppe: Nadelholz
- Klasse des Schwindens: [...]
- Gueltig bis: [...]

## Widersprueche

[WIDERSPRUCH] Quelle A und B widersprechen sich bei der Definition von [Konzept]:
- **A meint:** [Aussage mit Seitenzahl]
- **B meint:** [Aussage mit Seitenzahl]
- **Erklaerung:** Moegliche Ursachen...

[Wiederholen fuer alle markierten Widersprueche]

## Verwandte Konzepte

- [[Konzept1]]
- [[Konzept2]]

## Quellen (nach Verarbeitung)

- [Quelle1], Kapitel X, Seite N
- [Quelle2], Kapitel Y, Seite M
```

**2b: Diffs dokumentieren**
- Wenn Seite bereits existiert: Diff zwischen Alt + Neu aufzeigen
- Was wurde hinzugefuegt? Was hat sich geaendert?
- Diff-Format: [DIFF ADDED], [DIFF MODIFIED], [DIFF REMOVED]

**2c: Frontmatter aktualisieren**
- `quellen:` mit alle genutzten Quellen
- `schlagworte:` mit Termen aus kontrolliertem Vokabular (_vokabular.md)
- `reviewed:` auf `false` (weil Synthese neue Inhalte hinzufuegt)
- `synth-datum:` setzen mit heutigem Datum

---

### Phase 3: Dispatch Review-Gates

<NICHT-VERHANDELBAR>
Alle generierten/aktualisierten Konzeptseiten werden an 2 Gates dispatcht.
</NICHT-VERHANDELBAR>

**Gate 1: quellen-pruefer**
- Dispatch: `quellen-pruefer`
- Prueft: Jede Aussage hat Seitenangabe? Formeln-Quellen korrekt? Zahlenwerte verifizierbar?

**Gate 2: konsistenz-pruefer**
- Dispatch: `konsistenz-pruefer`
- Prueft: Widersprueche korrekt gekennzeichnet? Verweise zu verwandten Konzepten kohaerent?

**Bei FAIL:** Synthese korrigiert + erneutes Dispatch. Max 3 Iterationen (konsistent mit /ingest).

---

### Phase 4: Vokabular-Pruefung

- Dispatch: `vokabular-pruefer`
- Prueft: Alle Schlagworte im Frontmatter existieren im Vokabular?
- Falls neue Schlagworte noetig: Delegation an `/vokabular`

---

### Phase 5: Nebeneffekte

**Pflicht:**
- [ ] **Seite speichern** (mit Seitenangaben, Formeln, Widersprueche)
- [ ] **_index aktualisieren** (Konzeptseite hinzufuegen falls neu)
- [ ] **_log.md Eintrag:**
  ```markdown
  ## [2026-04-09] synthese | Querkraft-Transfer
  - Target: konzepte/querkraft-transfer.md (UPDATED)
  - Quellen re-gelesen: Fingerloos EC2, CEN/TS 19103
  - Formeln: 2 neu hinzugefuegt + 1 korrigiert
  - Widersprueche: 1 markiert (Norm-Versionen)
  - Gates: quellen-pruefer PASS, konsistenz-pruefer PASS
  ```
- [ ] **MOC pruefen:** Wenn neue Konzeptseite → in relevante MOCs eintragen
- [ ] **check-wiki-output.sh auf die Seite**

---

## Konflikt + Eskalation

**Problem: Widerspruch ist so fundamental, dass ich ihn nicht auflosen kann.**

→ Dokumentieren mit [WIDERSPRUCH]-Marker
→ Kommentar hinzufuegen: "Requires manual review — siehe _log"
→ Dispatch: `struktur-reviewer` (Nutzer konsultiert dann selbst)

---

## Split-Synthese (falls >700K Tokens)

1. Phase 0 plant: Quellen 1-2 (Durchgang 1), Quellen 3-4 (Durchgang 2)
2. Durchgang 1: Verarbeite Quellen 1-2, speichere Zwischen-Seite mit [SPLIT]-Marker
3. Durchgang 2: Lade Zwischen-Seite, fuege Quellen 3-4 hinzu
4. Final: Konsolidierung, [SPLIT]-Marker entfernen
5. 2-Gate Review auf Finale Seite

---

## Umlaut-Check

Synthese-Output (Formeln, Definitionen, Widersprueche-Doku) auf Umlaute geprueft.
