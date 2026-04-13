# Seitentypen — Bibliothek-Wiki

6 Seitentypen. Jeder Typ beantwortet eine andere Frage.
Jeder Typ hat Pflicht-Frontmatter-Felder.

---

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

## Abgrenzung Konzept vs. Verfahren

Ein **Konzept** beschreibt ein Phaenomen — was passiert mechanisch?
Ein **Verfahren** beschreibt eine Rechenmethode — wie weise ich nach?

Beispiele:
- Rollschub → Konzept (Versagensmechanismus in BSP-Querlagen)
- Querdruck → Konzept (Druckbeanspruchung quer zur Faser)
- Querdrucknachweis nach EC5 §6.1.5 → Verfahren (Schritt-fuer-Schritt)
- Gamma-Verfahren → Verfahren (Berechnungsmethode nach EC5 Anhang B)
- Verbundwirkung → Konzept (Zusammenwirken zweier Materialien)
- Push-Out-Versuch → Verfahren (Pruefverfahren nach DIN EN 1075)

Faustregel: Wenn der Kern der Seite eine Formel oder ein Ablaufdiagramm ist → Verfahren.
Wenn der Kern eine Erklaerung eines Phaenomens ist → Konzept.

## Pflicht-Frontmatter pro Seitentyp

### Quelle

```yaml
---
type: quelle
title: "Vollstaendiger Buchtitel"
autor: [Nachname1, Vorname1; Nachname2, Vorname2]
jahr: 2021
verlag: "Verlagsname"
seiten: 842
kategorie: Holzbau  # Level-1-Term aus _vokabular.md (keine feste Enum-Liste)
verarbeitung: vollstaendig  # vollstaendig | gesplittet | nur-katalog | fehlerhaft
pdf: "[[_pdfs/stahlbeton/fingerloos-ec2-2016.pdf]]"  # Obsidian-Link zum Original-PDF
reviewed: false
ingest-datum: 2026-04-09
schlagworte: [term1, term2, term3]
kapitel-index:
  - nr: 1
    titel: "Kapitelname"
    seiten: "1-42"
    relevanz: niedrig  # hoch | mittel | niedrig
    schlagworte: [term1, term2]
konzept-kandidaten:  # Optional — vom Ingest-Agent befuellt
  - term: "Begriffsname"
    kontext: "Kurzbeschreibung, Kap. X, S. Y-Z"
---
```

### Konzept

```yaml
---
type: konzept
title: "Begriffsname"
synonyme: [Synonym1, Synonym2]
schlagworte: [term1, term2]
quellen-anzahl: 5
created: 2026-04-09
updated: 2026-04-09
synth-datum: 2026-04-10  # Datum der letzten Synthese
mocs: [moc-holzbau, moc-verbundbau]  # Optional — in welchen MOCs verlinkt
reviewed: false
---
```

### Norm

```yaml
---
type: norm
title: "EC2 §9.2.5 — Indirekte Lagerung"
norm: "DIN EN 1992-1-1"
abschnitt: "9.2.5"
ausgabe: "2011-01"
ndp: "DIN EN 1992-1-1/NA"
status: gueltig  # gueltig | ersetzt | entwurf
nachfolger: null  # Verweis auf Nachfolger-Seite wenn ersetzt
schlagworte: [term1, term2]
created: 2026-04-09
updated: 2026-04-09
reviewed: false
---
```

### Baustoff

```yaml
---
type: baustoff
title: "BSH GL24h"
kategorie: Holz  # Materialgruppe, Level-1-Term aus _vokabular.md
norm: "EN 14080"
schlagworte: [term1, term2]
created: 2026-04-09
updated: 2026-04-09
reviewed: false
---
```

### Verfahren

```yaml
---
type: verfahren
title: "Gamma-Verfahren"
norm-basis: "EC5, Anhang B"
anwendung: "Nachgiebig verbundene Biegetraeger"
schlagworte: [term1, term2]
quellen-anzahl: 4
created: 2026-04-09
updated: 2026-04-09
reviewed: false
---
```

### MOC (Map of Content)

```yaml
---
type: moc
title: "Querkraft"
aktualisiert: 2026-04-09
---
```

MOC-Seiten haben KEINE Pflicht-Schlagworte (sie SIND die Navigation).
MOC-Seiten haben KEINE Seitenangaben-Pflicht (sie verlinken nur).
MOC-Seiten sind von Gate 2 (KEIN-INHALT-OHNE-SEITENANGABE) ausgenommen.

## Dateinamen-Konvention

- Kleinbuchstaben, Bindestriche statt Leerzeichen, keine Umlaute
- Quellen: `nachname-kurztitel-jahr.md` → `fingerloos-ec2-2016.md`
- Konzepte: `begriffsname.md` → `rollschub.md`, `aufhaengebewehrung.md`
- Normen: `norm-abschnitt.md` → `ec2-9-2-5.md`, `ec5-6-1-5.md`
- Baustoffe: `bezeichnung.md` → `bsh-gl24h.md`, `beton-c25-30.md`
- Verfahren: `verfahrensname.md` → `gamma-verfahren.md`
- MOCs: `thema.md` → `querkraft.md`, `holz-beton-verbund.md`
