---
name: normenupdate
description: "Normstaende pruefen und aktualisieren — neue Ausgaben einarbeiten"
---

## Governance-Vertrag

> **Bedingung:** Dieser Skill ist nur relevant wenn Domain-Typ "norm"
> in seitentypen.md aktiv ist. Pruefe beim Skill-Start ob der Typ existiert.
> Falls nicht: "Kein norm-Typ in diesem Wiki aktiv. /normenupdate nicht verfuegbar."

> Normenupdate verwaltet Norm-Editions-Wechsel (z.B. EC2 2011 → EC2 2020).
> Wenn eine Norm eine neue Ausgabe bekommt, werden ALLE Wiki-Seiten die
> diese Norm referenzieren aktualisiert + Unterschiede dokumentiert.
> Mehrere Gates sind aktiv; Vergleich alter vs. neuer Ausgabe erfordert Gate 9.

| Gate | Durchsetzung | Wie | Bedingung |
|------|-------------|-----|-----------|
| KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG | ⚪ N/A | Normenupdate liest Norm-Auszuege, keine Buecher | — |
| KEIN-INHALT-OHNE-SEITENANGABE | ⚪ N/A | Seitenangaben werden erhalten | — |
| KEIN-ZAHLENWERT-OHNE-QUELLE | ⚪ N/A | Zahlenwerte in Normen bleiben gekennzeichnet | — |
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | ✅ Aktiv | Phase 1 + 2 aktualisieren Abschnitts-Nummern | norm-Typ aktiv |
| KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS | ⚪ N/A | Querverweise bleiben erhalten | — |
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | ⚪ N/A | Keine neuen Schlagworte durch Normenupdate | — |
| KEIN-UPDATE-OHNE-DIFF | ✅ Aktiv | Phase 1 dokumentiert Diffs (alt vs. neu) | — |
| KEIN-WIDERSPRUCH-OHNE-MARKIERUNG | ✅ Aktiv | Phase 2 markiert Aenderungen mit [NORM-CHANGED] | — |
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | ✅ Aktiv | Phase 0.5 liest beide Norm-Versionen (PDF) | — |
| KORREKTE-UMLAUTE | ✅ Aktiv | Normenupdate-Output auf Umlaute geprueft | — |

**EXTERNER-INHALT-Marker:** Normenupdate liest Norm-PDFs → Wrapper erforderlich.

---

## Phasen

### Phase 0: Norm + Nachfolger identifizieren

1. **Alte Normseite laden:**
   - Existiert `wiki/normen/[norm-key].md`?
   - Frontmatter auslesen: `norm-id`, `edition`, `jahr`, `nachfolger` (falls vorhanden)
   - Alle Quellenseiten durchsuchen die diese Norm referenzieren

2. **Neue Norm-Edition identifizieren:**
   - Welche neue Edition soll eingefuehrt werden?
   - Existiert bereits eine Wiki-Seite fuer die neue Edition?
   - Falls ja: Link-sie als `nachfolger:` in der alten Seite ein
   - Falls nein: Neue Normseite anlegen (Phase 0.5b)

3. **Betroffene Seiten identifizieren:**
   - Alle Konzept-/Norm-/Verfahrensseiten durchsuchen die auf die ALTE Norm verweisen
   - Liste erstellen: x Seiten referenzieren EC2-2011, y Seiten referenzieren EC5-2012, etc.

---

### Phase 0.5a: Planmodus-Pruefung

Normenupdate betrifft typischerweise >=3 Dateien (alte Normseite + neue Normseite + Konzeptseiten).
→ EnterPlanMode BEVOR die erste Datei geschrieben wird.

Plan dokumentiert:
- Welche Normseiten werden erstellt/aktualisiert?
- Wie viele Konzeptseiten sind betroffen?
- Welche Zahlenwerte muessen propagiert werden?

### Phase 0.5b: Norm-PDFs lesen (BLOCKIERENDES GATE 9)

<NICHT-VERHANDELBAR>
Beide Norm-Versionen (alt + neu) MUESSEN vollstaendig gelesen werden.
Kein Skipping von Kapiteln.
</NICHT-VERHANDELBAR>

**0.5b-1: Alte Edition lesen**

1. PDF laden (SCHREIBPFAD)
2. Wrap: `<EXTERNER-INHALT>` marker
3. Komplett durchlesen (oder zumindest alle in Schritt 3 identifizierten Abschnitte)
4. Extrahieren:
   - Alle Abschnitts-Nummern die in Schritt 1 identifiziert wurden
   - Text, Formeln, Beispiele fuer diese Abschnitte
   - Besonderheiten, Einschraenkungen

**0.5b-2: Neue Edition lesen**

1. PDF der neuen Norm laden (SCHREIBPFAD)
2. Wrap: `<EXTERNER-INHALT>` marker
3. Vergleichslesung: Finde die identischen (oder ersetzten) Abschnitte
4. Dokumentieren:
   - Alte Nummer → Neue Nummer (falls Abschnitte renummeriert)
   - Texte identisch? Formulierung geaendert? Neue Werte?
   - Abschnitt entfernt? Neuer Abschnitt hinzugefuegt?

**0.5b-3: Kontext-Budget-Stopp**

Falls Anzeichen von Kontext-Engpass waehrend Lesung:
- STOPP
- Meldung: "Kann nicht beide Norm-Versionen vergleichen. Empfehlung: Session fortsetzen."

---

### Phase 1: Vergleichende Analyse

**1a: Abschnitts-Mapping**

Pro in Schritt 0 identifizierten Abschnitt:
```
EC2 2011 Abschnitt X.Y.Z (Seite n)
    ↓
EC2 2020 Abschnitt X.Y.Z' oder X'.Y.Z (Seite m)
    ↓
Aenderung: [RENUMMERIERT | IDENTISCH | GEAENDERT | GELOESCHT]
```

**1b: Inhalts-Vergleich**

Fuer jeden geaenderten Abschnitt:
- Was hat sich textuell geaendert?
- Haben sich Zahlenwerte geaendert?
- Gibt es neue Einschraenkungen / entfernte Randbedingungen?
- Sind Beispiele / Formeln betroffen?

**1c: Diff-Dokumentation**

Struktur:
```markdown
## Vergleich: EC2 2011 vs. EC2 2020

### Abschnitt 6.2 — Biegung + Querkraft

**Alte Version (2011):**
- Abschnitt 6.2.1: [Text gekuerzt]
- Formel: M = ... (Seite 120)

**Neue Version (2020):**
- Abschnitt 6.2.1: [Text gekuerzt, mit Aenderungen]
- Formel: M = ... (Seite 115, GEAENDERT)

**Unterschied:**
- [NORM-CHANGED] Abschnitt renummeriert (6.2.1 → 6.2.1a)
- [NORM-CHANGED] Formel X hat neuen Koeffizienten (0.5 → 0.6)
- [NORM-REMOVED] Zusatzbedingung Y entfernt
```

---

### Phase 2: Wiki-Seiten aktualisieren

**2a: Alte Normseite updaten**

Datei: `wiki/normen/[norm-key].md`

Aenderungen:
```markdown
---
norm-id: ec2
edition: 2011
jahr: 2011
nachfolger: ec2-2020
status: ersetzt
---

# Eurocode 2 — 2011 Ausgabe

_Diese Norm ist durch [EC2 2020](wiki/normen/ec2-2020.md) abgeloest worden._

[Restliche Inhalte unveraendert]
```

**2b: Neue Normseite erstellen (falls nicht vorhanden)**

Datei: `wiki/normen/[norm-key-neu].md`

Struktur:
```markdown
---
norm-id: ec2
edition: 2020
jahr: 2020
vorgaenger: ec2-2011
status: aktuell
kategorie: euronorm
sprache: de
update-datum: [HEUTE]
---

# Eurocode 2 — 2020 Ausgabe

Zusammenfassung der Norm, Gueltigkeitsbereich.

## Aenderungen gegenueber Vorgaenger (2011)

[Referenz zu Diff-Dokumentation aus Phase 1c]

## Abschnitte

[Wie in Phase 0, pro relevantem Abschnitt]
```

**2c: Konzept-/Verfahrensseiten aktualisieren**

Fuer JEDE Seite die alte Norm referenziert:

1. Laden
2. Alle Norm-Verweise durchsuchen
3. Alt-Abschnitt identifizieren → Neu-Abschnitt mappen
4. Verweise aktualisieren: "EC2 2011 Abschnitt 6.2" → "EC2 2020 Abschnitt 6.2.1a"
5. Falls Abschnitt geloescht oder wesentlich geaendert:
   - [NORM-CHANGED] Marker setzen
   - Kommentar hinzufuegen: "Norm-Edition X: Abschnitt Y entfernt"
6. Aktualisieren: Frontmatter `reviewed:` auf `false`, `update-datum:` setzen

**Diff-Beispiel:**
```markdown
[NORM-CHANGED] EC2 2011 § 6.2.1 durch EC2 2020 § 6.2.1a ersetzt.
Formel-Koeffizient aktualisiert (0.5 → 0.6) — siehe [Norm](wiki/normen/ec2-2020.md).
```

**2d: MOCs pruefen**

Falls neue Norm-Seite erstellt: In relevante MOCs eintragen

---

### Phase 3: Dispatch Review-Gate

Dispatch: `norm-reviewer`
- Prueft: Abschnitts-Mappings korrekt? Formeln korrekt aktualisiert?
- Spot-Check: 3-5 zufaellige Konzept-Seiten gegen neue Norm verifizieren

**Bei FAIL:** Korrigieren → Erneutes Dispatch

---

### Phase 4: Nebeneffekte

**Pflicht:**

- [ ] **Alle betroffenen Wiki-Seiten speichern**
- [ ] **_index aktualisieren:**
  - Alte Norm: `status: ersetzt, nachfolger: neue-norm`
  - Neue Norm: `vorgaenger: alte-norm, status: aktuell`
- [ ] **_log.md Eintrag:**
  ```markdown
  ## [2026-04-09] normenupdate | EC2 2011 → EC2 2020
  - Alte Normseite: normen/ec2-2011.md (UPDATE: status=ersetzt)
  - Neue Normseite: normen/ec2-2020.md (NEU)
  - Betroffene Konzeptseiten: 12 aktualisiert (querkraft.md, durchstanzen.md, ...)
  - Abschnitte umbenummeriert: 5 Mappings hinzugefuegt
  - Neue Formel-Koeffizienten: 2 Zahlenwerte aktualisiert
  - Gate: norm-reviewer PASS
  ```
- [ ] **check-wiki-output.sh auf alle betroffenen Dateien**

---

## Haeufigkeit + Trigger

Normenupdate wird angestossen wenn:
- Neue Norm-Edition offiziell veroeffentlicht
- Norm-Tranitionsphasen enden (z.B. alte Norm ist nicht mehr gueltig)
- Nutzer erwirbt / findet neue Norm-Ausgabe

---

## Konflikt-Handling

**Problem: Abschnitt X ist in neuer Ausgabe geloescht, aber noch viele Konzepte verweisen drauf.**

→ Dokumentieren mit [NORM-CHANGED] Marker
→ Kommentar: "Abschnitt in EC2 2020 entfernt — Falls Bezug noch relevant, auf alternatives Kapitel pruefen"
→ Dispatch: `struktur-reviewer` (Nutzer entscheidet ob Konzept-Inhalt angepasst werden muss)

---

## Umlaut-Check

Normenupdate-Dokumentation (Diffs, Mappings, _log) auf Umlaute geprueft.
