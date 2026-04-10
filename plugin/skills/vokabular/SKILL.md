---
name: vokabular
description: "Kontrolliertes Vokabular pflegen — neue Terme, Synonyme, Hierarchie"
---

## Governance-Vertrag

> Vokabular ist der EINZIGE Weg um neue Schlagwort-Terme ins System zu bringen.
> Gate 6 (KEIN-SCHLAGWORT-OHNE-VOKABULAR) delegiert ALLE neuen Terme an diesen Skill.
> Vokabular ist Gatekeeper und Quelle der Wahrheit fuer alle Schlagworte im Wiki.

| Gate | Durchsetzung | Wie |
|------|-------------|-----|
| KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG | ⚪ N/A | Vokabular arbeitet mit bestehenden Termen |
| KEIN-INHALT-OHNE-SEITENANGABE | ⚪ N/A | Vokabular-Aufbau basiert nicht auf neuer Lesung |
| KEIN-ZAHLENWERT-OHNE-QUELLE | ⚪ N/A | Vokabular-Definitionen sind konzeptionell |
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | ⚪ N/A | Vokabular bezieht sich nicht auf Normen |
| KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS | ⚪ N/A | Vokabular traegt keine Querverweise bei |
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | ✅ Aktiv | Dieser Skill IST die Durchsetzung |
| KEIN-UPDATE-OHNE-DIFF | ⚪ N/A | Vokabular-Aenderungen sind selbsterklaerend |
| KEIN-WIDERSPRUCH-OHNE-MARKIERUNG | ⚪ N/A | Vokabular traegt keine Widersprueche bei |
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | ⚪ N/A | Vokabular ist Metadaten |
| KORREKTE-UMLAUTE | ✅ Aktiv | Alle neuen Terme auf Umlaute geprueft |

---

## Phasen

### Phase 0: Vokabular laden + Anfrage analysieren

1. **_vokabular.md laden:**
   - Alle existierenden Terme mit bevorzugter Bezeichnung, Synonymen, Hierarchie
   - Aufbau verstehen: 3-Ebenen Hierarchie (Oberbegriff > Term > Spezifika)

2. **Anfrage klassifizieren:**
   - **Neu:** Proposal ist kein existierender Term + kein Synonym
   - **Synonym:** Proposal ist Synonym eines existierenden Terms
   - **Hierarchie-Update:** Umordnung innerhalb existierenden Terms
   - **Merge:** Zwei Terme sollen zusammengefasst werden

---

### Phase 1: Duplikat-Pruefung

**Ist der Termin bereits vorhanden?**

1. **Exakte Abfrage:** Gibt es einen Term mit dieser Bezeichnung (Case-insensitive)?
   - JA → Skipped (Term existiert)
   - NEIN → Weiter zu 2

2. **Synonym-Pruefung:** Ist der Termin in der Synonyme-Liste eines bestehenden Terms?
   - JA → Skipped (kein neuer Term noetig)
   - NEIN → Weiter zu 3

3. **Partielle Abfrage:** Existiert ein Term mit sehr aehnlichem Wortlaut?
   - Z.B. "Querkraft-Transfer" vs. "Querkraft-Uebertragung"
   - Falls JA → Frage: Duplikat oder Spezialform? (Nutzer konsultieren)
   - Falls NEIN → Weiter zu Phase 2

---

### Phase 2: Neue Term einfuegen

**Format der Vokabular-Eintrag:**

```markdown
### bevorzugte-Bezeichnung
- **Synonyme:** Synonym1, Synonym2
- **Oberbegriff:** [Uebergeordneter Term]
- **Verwandte Terme:** [[Wikilink1]], [[Wikilink2]]
- **Definition:** 1-2 Saetze was der Term bedeutet
- **Kontext:** Wo wird er im Projekt verwendet?
```

**Vorgehen beim Hinzufuegen:**

1. **Hierarchie-Ebene bestimmen:**
   - Level 1: Allgemeine Kategorien (z.B. "Holz-Beton-Verbund", "Materialverhalten")
   - Level 2: Spezifische Konzepte (z.B. "Querkraft-Transfer", "Rollschub")
   - Level 3: Sub-Konzepte/Detailaspekte (z.B. "Querkraft-Transfer — indirekt")
   - Max 3 Ebenen!

2. **Oberbegriff zuordnen:**
   - Level 1 Term hat Oberbegriff: "Gesamtkontext HBV"
   - Level 2 Term hat Oberbegriff: relevanter Level-1 oder Level-2 Term
   - Level 3 Term hat Oberbegriff: Parent Level-2 Term

3. **Synonyme sammeln:**
   - Falls mehrere aehnliche Ausdruecke bekannt: alle hinzufuegen
   - Der ERSTE ist der bevorzugte, Rest sind Aliasnamen

4. **Verwandte Terme verlinken:**
   - Welche anderen Vokabular-Terme sind konzeptionell verknuepft?
   - [[...]] Links zu ihren Wiki-Konzeptseiten

5. **Definition schreiben:**
   - 1-2 Saetze, knapp, praezise
   - Beschreibt das Konzept selbst, nicht wo es verwendet wird
   - KEINE Quellenverweis noetig (Vokabular ist konzeptionell)

---

### Phase 3: Synonym-Handling

**Falls Anfrage ist: "Neuer Synonym zu existierendem Term"**

1. **Term identifizieren** (bevorzugte Bezeichnung)
2. **Synonym-Liste updaten:** Neuen Synonym hinzufuegen
3. **Prioritaet:** Bevorzugter Term bleibt erhalten, neuer Synonym wird angefuegt

**Beispiel:**
```markdown
### Querkraft-Transfer
- **Synonyme:** Querkraft-Uebertragung, Scherkraft-Transfer
- **Oberbegriff:** Lastpfad-Uebertragung
```

---

### Phase 4: Hierarchie-Validierung

BLOCKIERENDES KRITERIUM: Max 3 Ebenen Hierarchie.

1. **Kette aufbauen:** Term → Oberbegriff → Uebergeordneter OB → ...
2. **Zaehlen:** Darf max 3 Schritte sein
3. **Falls >3:** Hierarchie umgestalten oder ein Konzept-Level ueberspringen

**Beispiel FALSCH:**
```
Level-1: "HBV"
  → Level-2: "Verbund-Verhalten"
    → Level-3: "Querkraft-Transfer"
      → Level-4: "Indirekte Lagerung" ← FEHLER: Level 4!
```

**Korrektur:** "Indirekte Lagerung" auf Level 2 hochziehen oder "Verbund-Verhalten" weglassen.

---

### Phase 5: Verarbeitung in _vokabular.md

1. **Datei laden**
2. **Eintrag an alphabetisch korrekter Position einfuegen**
   - Groß-Klein-Unterscheidung nach Deutschen Sortierregeln
3. **Format-Check:** YAML-Syntax korrekt? Umlaute korrekt?
4. **Datei speichern**

---

### Phase 6: Nebeneffekte

**Automatisch nach Vokabular-Update:**

1. **_log.md Eintrag:**
   ```markdown
   ## [2026-04-09] vokabular | Neue Terme
   - Neu: Indirekte-Lagerung (Oberbegriff: Lastpfad-Uebertragung)
   - Neu: Rollschub-Effekt (Synonym zu: Rollschub)
   - Update: Querkraft-Transfer (Synonym hinzugefuegt)
   ```

2. **Referenzen-Pruefer benachrichtigen:**
   - Falls neuer Term existiert, aber noch KEINE Konzeptseite:
   - Dispatch: `struktur-reviewer` (Vorschlag: Konzeptseite anlegen?)

3. **check-wiki-output.sh auf _vokabular.md ausfuehren**

---

## Konflikt-Handling

**Problem: "Dieser Termin sollte es geben, aber er ist zu spezifisch/zu allgemein"**

→ Frage an den Nutzer stellen mit Kontext:
- Was ist der Oberbegriff?
- Gibt es aehnliche Terme die in Konflikt stehen?
- Ist das Level-3 oder Level-2?

→ Bis Klaerungerfolgt: Termin mit Kommentar speichern:
```markdown
### [PENDING] Neuer-Termin
_Status: Awaiting clarification — siehe _log_
```

---

## Umlaut-Check

Alle neuen Terme + Definitionen + Synonyme werden auf Umlaute geprueft.
Alle Wiki-Ausgaben muessen echte Unicode-Umlaute verwenden: ä, ö, ü, Ä, Ö, Ü, ß.
Keine ASCII-Ersetzungen (ae/oe/ue) in Wiki-Seiten (Hard Gate 10).

---

## Dispatch-Anlaesse

**Aus anderen Skills kommt: "Neuer Schlagwort X benoetigt"**

→ `/vokabular X` wird aufgerufen
→ Dieser Skill antwortet mit: "Termin angelegt" oder "Existiert bereits"
→ Calling Skill kann dann weitermachen

**Beispiel (aus ingest):**
- ingest findet neuen Fachbegriff "Aufhaengebewehrung"
- ingest dipatchiert: `/vokabular Aufhaengebewehrung`
- vokabular gibt zurück: "Term neu in Vokabular"
- ingest faehrt fort mit Konzeptseite + Schlagwort

---

## Haeufigkeit

Vokabular wird laufend gepflegt:
- Waehrend ingest (neue Fachbegriffe)
- Waehrend synthese (spezialisierte Konzepte)
- Nach wiki-lint (falls Fehler entdeckt)
