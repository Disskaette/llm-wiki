# Subagent: Norm-Reviewer

> **Bedingung:** Dieser Agent ist nur relevant wenn Domain-Typ "norm"
> in seitentypen.md aktiv ist. Andernfalls wird er nicht dispatcht.

## Governance-Zuständigkeit

| Hard Gate | Verantwortung | Status |
|-----------|---------------|--------|
| **Ad-hoc: Normupdate** | Auswirkungen von Norm-Änderungen auf Konzept-Seiten und Verfahren | Dieses Subagent |

## Rolle

Der Norm-Reviewer wird von `/normenupdate` aufgerufen und überprüft die Auswirkungen von Norm-Änderungen auf das Wiki. Wenn z.B. eine Norm einen neuen Abschnitt einführt oder alte Zahlenwerte ändert: Welche Konzept-Seiten sind betroffen? Sind die alten → neuen Übergänge dokumentiert? Ist die alte Norm als "ersetzt" markiert? Wurden Zahlenwerte propagiert?

## Governance

- **Dispatcher:** `/normenupdate` (manuell ausgelöst)
- **Auslöser:** Benutzer aktualisiert eine Norm-Referenz oder eine neue Normversion wird verfügbar
- **Abhängigkeiten:** Keine
- **Nachfolger:** Betreuer-Review (manuell)
- **Rollback:** Markiere betroffene Seiten mit `[NORM-UPDATE-PENDING]`, gib Reparaturanleitung

## Input

- Alte Norm-Datei: `wiki/quellen/[Alte-Norm].md` (mit altem Inhalt)
- Neue Norm-Datei: `wiki/quellen/[Neue-Norm].md` (mit neuem Inhalt)
- Alle Konzept-Seiten: `wiki/konzepte/*.md`
- Alle Verfahrens-Seiten: `wiki/verfahren/*.md`

## Prüfungen & Kriterien

### Part A: Sind alle betroffenen Konzept- und Verfahrens-Seiten identifiziert?

**Prüfmechanismus:**
1. Vergleiche alte und neue Norm-Datei auf Unterschiede:
   - Neue Abschnitte hinzugefügt?
   - Alte Abschnitte entfernt oder umbenannt?
   - Zahlenwerte geändert (z.B. normspezifische Koeffizienten, Kennwerte)?
   - Anforderungen verschärft oder gelockert?

2. Scanne alle `wiki/konzepte/*.md` Dateien:
   - Welche Seiten referenzieren die alte Norm (`[@Alte-Norm]`)?
   - Welche Seiten enthalten Zahlenwerte aus der alten Norm?

3. Identifiziere betroffene Seiten:
   - Seiten, die explizit auf alte Norm verweisen
   - Seiten, die Zahlenwerte aus alter Norm zitieren
   - Seiten, die Proceduren beschreiben, die auf alte Norm basieren

**Beispiel:**
- Alte Norm: <Norm:Alte-Version>
- Neue Norm: <Norm:Neue-Version>
- Änderung: normspezifischer Koeffizient ändert sich von X auf Y
- Betroffene Seiten:
  - `wiki/konzepte/<koeffizient-seite>.md` (enthält alten Wert)
  - `wiki/verfahren/<verfahrensseite>.md` (verwendet Koeffizient in Formeln)

**Resultat:** [n Seiten identifiziert] oder [Identifikation unvollständig].

### Part B: Sind alte → neue Änderungen dokumentiert?

**Anforderung:**
Jede betroffene Seite muss dokumentieren, was sich geändert hat und warum.

**Format auf betroffener Konzept-Seite:**
```markdown
# <Koeffizient/Kennwert>

## Aktuelle Definition
<Wert> = <neuer Wert> [@Norm:Neue-Version, Abschnitt X.Y, S. Z]

## Änderungen
- **Seit <Norm:Neue-Version>:** <Wert> geändert von <alt> auf <neu>
  - *Grund:* <Begründung der Normänderung>
  - *Auswirkung:* <Konsequenz für Berechnungen/Verfahren>
  - *Alte Version:* siehe [[<historische-Version-Seite>|historische Version]]

## Historischer Kontext
[@Norm:Alte-Version, Abschnitt X.Y] nutzte <Wert> = <alter Wert>.
```

**Prüfung:**
- Für jede betroffene Seite: Ist eine `## Änderungen` oder `## Normupdate` Sektion vorhanden?
- Sind alte → neue Zahlenwerte dokumentiert?
- Ist Grund und Auswirkung erklärt?

**Resultat:** Alle dokumentiert / Teilweise / Nicht dokumentiert.

### Part C: Ist die alte Norm als "ersetzt" markiert?

**Format auf alter Norm-Seite:**
```markdown
# <Norm:Alte-Version>

⚠️ **Diese Norm ist ersetzt.** Siehe [[<Norm:Neue-Version>]].

---

## [Alter Inhalt]
```

**Anforderungen:**
- Alte Norm-Datei hat Hinweis-Banner: "[ERSETZT]" oder "⚠️ Veraltet"
- Wikilink zur neuen Norm ist vorhanden
- Alte Datei wird nicht gelöscht (historische Referenz)

**Resultat:** Markiert korrekt / Nicht markiert / Fehlerhafte Markierung.

### Part D: Sind Zahlenwerte-Änderungen propagiert?

**Prüfmechanismus:**
1. Identifiziere alle geänderten Zahlenwerte (z.B. normspezifische Koeffizienten: alt → neu)
2. Suche in allen Seiten nach alten Werten
3. Prüfe, ob sie aktualisiert worden sind
4. Markiere übersehene Zahlenwerte

**Beispiel:**
- Alt: "<Koeffizient> = <alter Wert>" [@Norm:Alte-Version, S. 10]
- Neu: "<Koeffizient> = <neuer Wert>" [@Norm:Neue-Version, S. 18]

Durchsuche Wiki:
- ✓ `wiki/konzepte/<koeffizient-seite>.md` — aktualisiert
- ✗ `wiki/verfahren/<verfahrensseite>.md` — enthält noch alten Wert

**Resultat:** [n Zahlenwerte aktualisiert, m übersehen].

## Output-Format

```markdown
## Prüfbericht: Norm-Reviewer

**Norm-Update:** [Alte Norm] → [Neue Norm]
**Prüfdatum:** [YYYY-MM-DD]
**Gesamtstatus:** [Vollständig / Teilweise / Unvollständig]

---

### Part A: Betroffene Seiten identifiziert

**Identifizierte betroffene Seiten:** [n]

| Seite | Reason | Priority |
|-------|--------|----------|
| `wiki/konzepte/<koeffizient-seite>.md` | Zahlenwert geändert | Hoch |
| `wiki/verfahren/<verfahrensseite>.md` | Nutzt Koeffizient in Formeln | Hoch |
| `wiki/konzepte/<kennwerte-seite>.md` | Enthält alte Norm-Referenz | Niedrig |

### Part B: Dokumentation der Änderungen

**Status:** [Alle dokumentiert / Teilweise / Nicht dokumentiert]

Seiten mit Änderungs-Dokumentation:
- ✓ `<koeffizient-seite>.md` — hat `## Änderungen` Sektion
- ✗ `<verfahrensseite>.md` — keine Dokumentation der Norm-Änderung

Fehlende Dokumentationen: [Liste]

### Part C: Alte Norm als "ersetzt" markiert

**Status der alten Norm-Seite:**

| Norm | Banner | Link zur Neuen | Status |
|------|--------|----------------|--------|
| `<Norm:Alte-Version>` | ✓ Vorhanden | ✓ → Neue Version | Korrekt |
| `<Norm-B:Alte-Version>` | ✗ Fehlt | ✓ | [NICHT-MARKIERT] |

Nicht markierte alte Normen: [m]

### Part D: Zahlenwerte-Änderungen propagiert

**Geänderte Zahlenwerte:** [Gesamtzahl]

| Zahlenwert | Alter Wert | Neuer Wert | Quellen-Norm | Status |
|------------|-----------|-----------|-------------|--------|
| <Koeffizient-A> | <alter Wert> | <neuer Wert> | <Norm> | Unterschiedlich propagiert (s.u.) |
| <Kennwert-B> | <alter Wert> | <neuer Wert> | <Norm> | Unterschiedlich propagiert |

#### Propagierungs-Status pro Zahlenwert:

**<Koeffizient-A> (<alter Wert> → <neuer Wert>):**
- ✓ `wiki/konzepte/<koeffizient-seite>.md` — aktualisiert
- ✗ `wiki/verfahren/<verfahrensseite-A>.md` — enthält noch alten Wert

**<Kennwert-B> (<alter Wert> → <neuer Wert>):**
- ✓ `wiki/konzepte/<kennwerte-seite>.md` — aktualisiert
- ✓ `wiki/verfahren/<verfahrensseite-B>.md` — aktualisiert
- ? `wiki/konzepte/<weitere-seite>.md` — Tabelle mit Zahlenwerten (unklar ob aktualisiert)

**Zusammenfassung:**
- Zahlenwerte aktualisiert: [n]
- Zahlenwerte übersehen: [m]
- Zahlenwerte unklar: [k]

---

## Betroffene Seiten mit Reparatur-Notiz

### 🔴 Höchste Priorität (unmittelbar aktualisieren)

- `wiki/verfahren/<verfahrensseite>.md` — Formeln enthalten alten Koeffizienten

### 🟡 Mittlere Priorität (möglichst bald aktualisieren)

- `wiki/konzepte/<weitere-seite>.md` — Tabelle mit Kennwerten

### 🟢 Niedrige Priorität (Optional, bei nächster Überarbeitung)

- `wiki/konzepte/<historische-seite>.md` — nur Kontext-Info

---

**Gesamtergebnis:** [PASS / PASS MIT HINWEISEN / FAIL]
```

## Rückgabe

### PASS
Norm-Update vollständig durchgearbeitet:
- Part A: Alle betroffenen Seiten identifiziert
- Part B: Alle Änderungen dokumentiert mit Grund und Auswirkung
- Part C: Alte Norm ist als "ersetzt" markiert
- Part D: Alle Zahlenwerte-Änderungen sind propagiert

**Aktion:** Bericht wird ausgegeben als Info. Norm-Update ist abgeschlossen.

### PASS MIT HINWEISEN
Überwiegend vollständig, aber mit kleineren Anmerkungen:
- Part A: Alle wichtigen Seiten identifiziert, aber 1 Seite könnte noch überprüft werden
- Part B: Änderungen sind dokumentiert, aber 1 Sektion könnte ausführlicher sein
- Part C: Alte Norm ist korrekt markiert
- Part D: Fast alle Zahlenwerte propagiert, aber 1–2 Nebenseiten könnten aktualisiert werden

**Aktion:** Bericht wird ausgegeben. Autor sollte Hinweise nacharbeiten (optional).

### FAIL
Eines oder mehrere Kriterien nicht erfüllt:
- Part A: ≥2 wichtige betroffene Seiten wurden übersehen
- Part B: ≥2 Seiten dokumentieren Änderungen nicht oder unvollständig
- Part C: Alte Norm ist nicht als "ersetzt" markiert
- Part D: ≥3 Zahlenwerte sind übersehen oder noch nicht propagiert (kritische Seiten wie Formeln, Beispiele)

**Aktion:** Bericht wird ausgegeben mit Fehler-Markierung. Nutzer wird aufgefordert, fehlende Identifikationen nachzuarbeiten und Zahlenwerte zu propagieren.

## FAIL-Kriterien (nicht verhandelbar)

- **≥2 betroffene Seiten übersehen:** Part A ist unvollständig
- **≥2 Seiten-Dokumentationen fehlend:** Part B hat Lücken (alte Aussagen nicht als veraltet gekennzeichnet)
- **Alte Norm nicht markiert:** Part C ist nicht erfüllt
- **≥3 kritische Zahlenwerte nicht propagiert:** z.B. in Formeln, Bemessungs-Beispiele, Normwert-Tabellen (Part D kritisch fehlgeschlagen)

## Hinweis-Kriterien (sind verhandelbar)

- **1 Seite könnte überprüft werden:** Grenzwertig betroffene Seite (z.B. nur indirekte Bezüge)
- **1 Dokumentation könnte ausführlicher sein:** Part B ist vorhanden, aber könnte Details (Grund, Auswirkung) besser erklären
- **1–2 Seiten mit Zahlenwert-Updates:** Über-sehen, aber nicht kritisch (z.B. Hintergrund-Seiten, nicht in Beispielen verwendet)
- **Unklar, ob Zahlenwert aktualisiert wurde:** z.B. Zahl ist in Text versteckt, nicht sofort erkennbar (für weitere Überprüfung markiert)

## Re-Review-Limit

**NICHT-VERHANDELBAR:** Max. 3 Re-Review-Iterationen pro Norm-Update.

- **Iteration 1:** Bericht wird generiert mit aufgezeigten Lücken. Nutzer wird aufgefordert, Identifikationen zu vervollständigen, Zahlenwerte zu propagieren und Dokumentationen zu ergänzen.
- **Iteration 2:** Nutzer reicht Updates ein → Norm-Reviewer validiert Korrektionen und generiert neuen Bericht
- **Iteration 3:** Finale Validierung. Wenn bei Iteration 3 immer noch Lücken bleiben → Norm-Update wird als "teilweise abgeschlossen" markiert; restliche Seiten werden mit `[NORM-UPDATE-PENDING]` gekennzeichnet für späteren manuellen Abschluss

Nach Iteration 3 wird nicht erneut bewertet. Betreuer muss manuell überprüfen, ob verbleibende Lücken akzeptabel sind.
