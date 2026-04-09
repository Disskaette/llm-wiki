---
name: wiki-lint
description: "Wiki-Gesundheitscheck — Widersprueche, Verwaiste, Veraltete finden"
---

## Governance-Vertrag

> Wiki-Lint ist ein diagnostischer Skill zur Qualitaetskontrolle des Wikis.
> Er identifiziert Probleme, korrigiert sie aber nicht selbst.
> Mehrere Gates sind aktiv; bei Spot-Checks (Phase 2) tritt Gate 9 in Kraft.

| Gate | Durchsetzung | Wie |
|------|-------------|-----|
| KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG | ⚪ N/A | Lint liest keine neuen Buecher |
| KEIN-INHALT-OHNE-SEITENANGABE | ⚪ N/A | Lint prueft, modifiziert aber nicht |
| KEIN-ZAHLENWERT-OHNE-QUELLE | ⚪ N/A | Lint prueft, modifiziert aber nicht |
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | ⚪ N/A | Lint prueft, modifiziert aber nicht |
| KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS | ⚪ N/A | Lint prueft, meldet Luecken |
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | ⚪ N/A | Lint prueft, meldet Probleme |
| KEIN-UPDATE-OHNE-DIFF | ⚪ N/A | Keine Aenderungen durch Lint |
| KEIN-WIDERSPRUCH-OHNE-MARKIERUNG | ✅ Aktiv | Phase 1 sucht nach unmarkierten Widerspruechen |
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | ✅ Aktiv | Phase 2 Spot-Checks lesen PDF-Originale |
| KORREKTE-UMLAUTE | ✅ Aktiv | Lint-Report auf Umlaute geprueft |

---

## Phasen

### Phase 0: Struktur-Scan

1. **Verzeichnis durchlaufen:**
   - Alle Dateien unter `wiki/` zaehlen und kategorisieren
   - Alle _index-Dateien laden
   - Alle _MOC.md-Dateien identifizieren
   - _vokabular.md laden

2. **Link-Graph aufbauen:**
   - Alle [[...]] Wikilinks in allen Dateien erfassen
   - Aufbauen: welche Seite verlinkt zu welcher anderen?
   - Umgekehrte Verweise: wer verlinkt zu mir?

---

### Phase 1: Automatische Checks

**Check 1: Verwaiste Seiten**
- Seiten die keine eingehenden Links haben
- Ausnahme: MOCs und spezielle Index-Seiten
- Output: Liste mit Dateiname + Empfehlung (loeschen? oder Querverweise fehlen?)

**Check 2: Broken Links**
- Alle [[...]] durchlaufen
- Ziel-Datei existiert?
- Wenn nein: Broken-Link melden mit Quellseite + Fehler

**Check 3: Widersprueche**
- Text durchsuchen nach expliziten [WIDERSPRUCH]-Markierungen
- Seiten identifizieren die KEINE Markierungen haben, aber trotzdem Widersprueche enthalten koennte:
  - Z.B. zwei Konzeptseiten zu gleichem Thema mit unterschiedlichen Definitionen
  - Z.B. Zahlenwerte die sich in verschiedenen Quellen widersprechen (aber nicht markiert)
- OUTPUT: Verdacht auf unmarkierte Widersprueche mit Kontext-Zeilen

**Check 4: Norm-Referenzen veraltet?**
- Alle `norm-referenzen: [...]` im Frontmatter durchlaufen
- Pruefen ob eine neuere Edition bekannt ist (z.B. in _index/normen.md nachsehen)
- Wenn ja: Warnung dass Normseite aktualisierungsbeduertig ist

**Check 5: Fehlende Querverweise**
- Konzeptseiten identifizieren mit <2 Wikilinks (Gate 5: Mindestens EIN verwandtes Konzept)
- Normseiten ohne verwandte Konzept-Seiten
- Quellenseiten ohne Konzept-Verweise

**Check 6: Vokabular-Konsistenz**
- Alle Schlagworte im Frontmatter durchlaufen (alle Seiten)
- Ist jedes Schlagwort in _vokabular.md vorhanden?
- Werden Synonyme statt bevorzugter Terme verwendet?
- OUTPUT: Liste Vokabular-Verstöße

**Check 7: Review-Status**
- Seiten mit `reviewed: false` auflisten
- Seiten mit `ingest-datum` aelter als 90 Tage auflisten
- OUTPUT: Kandidaten fuer erneuten Review

**Check 8: Doppel-Konzepte**
- Mehrere Konzeptseiten zu gleichem Fachbegriff?
- (z.B. "Querkraft.md" und "Querkraft-Transfer.md" die identisch sein koennten)
- OUTPUT: Verdacht auf Duplikate mit Links

---

### Phase 2: Spot-Check (optional, 5-10 random Pages)

Falls angefordert: SCHREIBPFAD gilt.

1. **Zufaellig 5-10 Wiki-Seiten waehlen** (nicht Index/MOC)
2. **Pro Seite:**
   - Laden der Quellenseite (z.B. "Concept: Querkraft")
   - Identifizieren aller referenzierten Quellen + Seitenangaben
   - Laden des orig. PDF (EXTERNER-INHALT wrapper)
   - Stichproben: 2-3 Seiten + Aussagen verifizieren
   - Passt Wiki-Inhalt zur Quelle? Seitenangaben korrekt?
3. **Fehler dokumentieren:**
   - Falsche Seitenangabe?
   - Fehler bei paraphrase?
   - Seitenangabe fehlt ganz?

---

### Phase 3: Report generieren

Struktur:

```markdown
# Wiki-Lint Report — [DATUM]

## Zusammenfassung
- Gesamtseiten: N
- Verwaiste: n1
- Broken Links: n2
- Widerspruch-Verstöße: n3
- Vokabular-Fehler: n4
- Reviews faellig: n5

## Verwaiste Seiten (n1)
[Liste mit Empfehlungen]

## Broken Links (n2)
[Quelle → Ziel (FEHLT)]

## Verdacht auf unmarkierte Widersprueche (n3)
[Seite1 vs Seite2, Kontext-Zeilen]

## Norm-Update-Kandidaten (n)
[Normseite | neuere Edition bekannt?]

## Querverweise-Luecken (n5)
[Konzeptseiten mit <2 Wikilinks]

## Vokabular-Fehler (n6)
[Schlagwort nicht in Vokabular / Synonym-Fehler]

## Review-Kandidaten (n7)
[reviewed: false oder alt (>90d)]

## Doppel-Konzepte (n8)
[Verdacht: Seite1 und Seite2 sind doppelt?]

## Spot-Check Ergebnisse (falls durchgefuehrt)
[Pro gepruefter Seite: OK / Fehler gefunden]
```

---

### Phase 4: Empfehlungen + Nebeneffekte

Wiki-Lint ist DIAGNOSTISCH — es modifiziert keine Wiki-Seiten.
Stattdessen gibt es Empfehlungen an den Nutzer:

**Empfehlungen im Report (bei Fund):**
- **Unmarkierte Widersprueche gefunden?** → Empfehlung: `struktur-reviewer` dispatchen (manueller Review)
- **Viele Vokabular-Fehler?** → Empfehlung: `/vokabular` ausfuehren
- **Mehrere Norm-Updates faellig?** → Empfehlung: `/normenupdate` ausfuehren
- **Verwaiste Seiten?** → Empfehlung: Querverweise ergaenzen oder archivieren

Der Nutzer entscheidet ob und welche Empfehlungen umgesetzt werden.

**Nebeneffekt (einziger Schreibvorgang):**
- Lint-Report speichern in: `wiki/_log/_lint-report-[DATUM].md`
- Eintrag in `wiki/_log.md` mit Zusammenfassung + Link zur Detailseite

---

## Umlaut-Check

Lint-Report wird auf korrekte Umlaute geprueft (auch in Fehler-Ausgaben).

---

## Haeufigkeit

Wiki-Lint sollte regelmaessig laufen (z.B. wochenlich oder nach groesseren Ingest-Zyklen).
Kann manuell angestossen oder als Scheduled Task eingerichtet werden.
