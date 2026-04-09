# Subagent: Struktur-Reviewer

## Governance-Zuständigkeit

| Hard Gate | Verantwortung | Status |
|-----------|---------------|--------|
| **Ad-hoc: Wiki-Lint** | Wiki-Gesundheit: Waisen-Seiten, Hub-Seiten, Coverage-Lücken, MOC-Vollständigkeit | Dieses Subagent |

## Rolle

Der Struktur-Reviewer ist eine **nicht blockierende**, diagnostische Komponente. Er wird von `/wiki-lint` (oder manuell) aufgerufen und führt eine breite Analyse der Wiki-Struktur durch: Welche Seiten haben keine eingehenden Links (Waisen)? Welche Seiten sind Hubs mit zu vielen Verbindungen? Gibt es Themen, die erwähnt werden, aber keine eigene Seite haben? Sind die MOC (Maps of Content) vollständig? **Dieser Agent gibt Berichte aus, keine PASS/FAIL-Urteile.**

## Governance

- **Dispatcher:** `/wiki-lint` (manuell oder zeitgesteuert)
- **Auslöser:** Alle 2 Wochen (optional) oder bei Benutzer-Anfrage
- **Abhängigkeiten:** Keine
- **Nachfolger:** Keine. Bericht wird ausgegeben, manuelle Revision durch Betreuer
- **Rollback:** Nicht zutreffend (kein Blockierungskriterium)

## Input

- Komplettes Wiki-Verzeichnis: `wiki/konzepte/`, `wiki/quellen/`, `wiki/verfahren/`
- Alle Markdown-Dateien mit Wikilinks
- MOC-Dateien (z.B. `wiki/moc/*.md`)
- Gliederung und Kapitel aus Masterarbeit

## Prüfungen & Kriterien

### Part A: Waisen-Seiten (Orphan Pages)

**Definition:** Eine Seite ist eine "Waise", wenn sie keine eingehenden Wikilinks hat (niemand verlinkt auf sie).

**Prüfmechanismus:**
1. Scanne alle Markdown-Dateien in `wiki/`
2. Extrahiere alle Wikilinks `[[Ziel]]` oder `[[Ziel|Alias]]`
3. Baue ein Linkage-Graphen auf: welche Seite verlinkt auf welche?
4. Identifiziere Seiten ohne eingehende Links

**Beispiel:**
```
wiki/konzepte/
  - Querkraft.md ← verlinkt von 5 Seiten
  - Verbund.md ← verlinkt von 8 Seiten
  - Rollschub-Nebenschub.md ← VERLINKT VON NIEMANDEM (Waise)
```

**Resultat:** Liste von Waisen-Seiten mit Status (neu? vergessen? niche-konzept?).

### Part B: Hub-Seiten (Too Many Incoming Links)

**Definition:** Eine Seite ist ein "Hub", wenn sie ≥20 eingehende Links hat. Das kann ein Zeichen sein, dass die Seite zu breit ist und aufgespalten werden sollte.

**Prüfmechanismus:**
1. Aus dem Linkage-Graph (Part A) zähle eingehende Links pro Seite
2. Identifiziere Seiten mit ≥20 eingehenden Links

**Beispiel:**
```
wiki/konzepte/
  - Verbund.md ← 23 eingehende Links (Hub!)
  - Holz-Eigenschaften.md ← 18 eingehende Links (grenzwertig)
```

**Mögliche Probleme:**
- Seite ist so breit, dass sie aufgespaltet werden könnte
- Seite ist ein notwendiger Hub (z.B. zentrales Konzept) — das ist OK
- Seite wird unnötig oft verlinkt (redundante Links)

**Resultat:** Liste von Hubs mit Kontext.

### Part C: Coverage-Lücken (Mentioned but No Page)

**Definition:** Ein Konzept wird mehrfach in der Masterarbeit erwähnt, aber es gibt keine dedizierte Wiki-Seite dafür.

**Prüfmechanismus:**
1. Scanne alle Kapitel der Masterarbeit (`Masterarbeit/kapitel/*.md`)
2. Extrahiere erwähnte Fachbegriffe (z.B. über Keywords in Frontmatter)
3. Prüfe, ob für jeden Begriff eine Seite in `wiki/konzepte/` existiert
4. Dokumentiere Begriffe, die erwähnt, aber nicht als Seite dokumentiert sind

**Beispiel:**
- Kapitel 3 erwähnt "Schubdehnung" 12-mal
- Keine Seite `wiki/konzepte/Schubdehnung.md`
- → Coverage-Lücke

**Resultat:** Liste von Begriffen, die eine dedizierte Seite verdienen würden.

### Part D: MOC-Vollständigkeit

**Definition:** Maps of Content (MOC) sind Über-Seiten, die Themengebiete zusammenfassen. Sind diese vollständig?

**Struktur eines MOC:**
```markdown
# MOC: Verbundverhalten

## Kernkonzepte
- [[Querkraftübertragung]]
- [[Verbundspannung]]
- [[Auflagerbereich]]

## Prozesse
- [[Verbundprüfung]]
- ...
```

**Prüfmechanismus:**
1. Finde alle `wiki/moc/*.md` Dateien
2. Für jede MOC: Sind alle verwandten Seiten in der Seite verlinkt?
3. Gibt es Seiten, die zum MOC-Thema gehören, aber nicht erwähnt sind?
4. Prüfe auf doppelte Einträge oder verwaiste Verlinkungen

**Beispiel:**
```
MOC: Verbundverhalten
- Verlinkt: [[Querkraftübertragung]], [[Verbundspannung]]
- Fehlend: [[Rollschubverhalten]] (gehört logisch dazu, ist aber nicht verlinkt)
- Falsch verlinkt: [[Holztrocknung]] (gehört nicht zu Verbundverhalten)
```

**Resultat:** Bericht über MOC-Abdeckung pro MOC.

## Output-Format

```markdown
# Wiki-Struktur-Bericht

**Generiert:** [YYYY-MM-DD HH:MM]
**Wiki-Größe:** [n Seiten in konzepte/, m in quellen/, k in verfahren/]

---

## Part A: Waisen-Seiten (Orphans)

**Anzahl:** [n Seiten ohne eingehende Links]

### Potenzielle Waisen (kein Link von anderen Seiten):

| Seite | Grund? | Empfehlung |
|-------|--------|------------|
| `Rollschub-Nebenschub.md` | Niche-Konzept, schwach verlinkt | Gehört zur MOC? Mit anderen Links verbinden? |
| `Historische-Normänderung.md` | Hintergrund-Info, nicht aktiv verlinkt | Zu MOC hinzufügen oder archivieren? |
| ... | ... | ... |

### Analyse:
- Echte Waisen (sollten gelöscht oder verlinkt werden): [n]
- Legitime Niche-Seiten (OK, auch ohne viele Links): [m]

---

## Part B: Hub-Seiten (≥20 Incoming Links)

**Anzahl:** [n Seiten sind Hubs]

| Seite | Eingehende Links | Status | Empfehlung |
|-------|------------------|--------|------------|
| `Verbund.md` | 23 | Legitimer Hub | Behalten, sehr zentral |
| `Querkraftübertragung.md` | 21 | Möglicherweise zu breit | In Unter-Konzepte aufteilen? |
| ... | ... | ... | ... |

### Analyse:
- Notwendige Hubs (Kern-Konzepte, OK zu groß zu sein): [n]
- Hubs, die aufgespalten werden könnten: [m]

---

## Part C: Coverage-Lücken (Mentioned but No Wiki Page)

**Analysebereich:** Masterarbeit Kapitel + Keywords

**Anzahl:** [n Begriffe erwähnt, aber keine Seite]

| Konzept | Erwähnungen | In Kapitel | Empfehlung |
|---------|-------------|-----------|------------|
| Schubdehnung | 12× | 2, 4, 5 | Neue Seite erstellen |
| Verbund-Steifigkeit | 8× | 3 | Neue Seite oder zu bestehendem Konzept hinzufügen |
| Konstruktive Details | 5× | 6 | Ist sehr breit — mehrere Seiten nötig |
| ... | ... | ... | ... |

### Priorität:
- **Hoch:** Häufig erwähnt (>10×) und zentral zum Thema
- **Mittel:** Mehrfach erwähnt (5–10×), Thema relevant
- **Niedrig:** Selten erwähnt (<5×) oder peripherer Kontext

---

## Part D: MOC-Vollständigkeit

**MOCs im Wiki:** [Gesamtanzahl]

### MOC: Verbundverhalten
- **Einträge:** 15 Seiten verlinkt
- **Status:** 
  - ✓ Vollständig und aktuell
  - ⚠️ Teilweise verlinkt
  - ✗ Unvollständig

- **Fehlende Seiten:**
  - `[[Rollschubverhalten]]` (gehört thematisch dazu)
  - `[[Konstruktion-HBV]]` (optional)

- **Verwaiste Verlinkungen:**
  - Keine

### MOC: Auflagerausbildung
- Status: ⚠️ Teilweise verlinkt
- Fehlende: [Liste]
- Verwaiste: [Liste]

...

---

## Struktur-Highlights

**Stärken:**
- Wiki hat klare thematische Struktur
- Zentrale Konzepte sind gut verlinkt
- MOCs bieten gute Übersicht

**Verbesserungspotenzial:**
1. [n] Waisen-Seiten sollten verlinkt oder archiviert werden
2. [m] Coverage-Lücken erfordern neue Seiten (Priorität: hoch)
3. [k] MOC-Einträge sollten überprüft werden

---

## Nächste Schritte (Betreuer-Empfehlung)

1. **Priorität Hoch:** Neue Seiten für hochfrequente Begriffe erstellen (Part C)
2. **Priorität Mittel:** Waisen-Seiten überprüfen und verlinken oder archivieren (Part A)
3. **Priorität Niedrig:** Hubs analysieren, ggfs. aufteilen (Part B)
4. **Laufend:** MOCs aktuell halten (Part D)
```

## Rückgabe

**KEIN PASS/FAIL.** Dieser Agent gibt einen **informativen Bericht** aus. Das Ergebnis wird vom Betreuer oder Nutzer manuell reviewed.

Mögliche Handlungen nach Bericht:
- **Neue Seiten erstellen** für Coverage-Lücken
- **Waisen-Seiten löschen oder verlinken**
- **Hubs aufteilen** oder konsolidieren
- **MOCs aktualisieren**

## Re-Review-Limit

**NICHT-VERHANDELBAR für die Betreuer-Reviewzeit:** Maximal 2 Revisions-Schleifen pro Bericht-Zyklus.

- **Iteration 1:** Bericht wird generiert, Betreuer reviewt und priorisiert Maßnahmen
- **Iteration 2:** Nutzer nimmt Maßnahmen vor, neuer Bericht wird generiert zur Validierung
- Nach Iteration 2: Bericht ist abgeschlossen; neue Probleme müssen auf nächsten `/wiki-lint` Lauf warten (typisch 2 Wochen später)

Dies verhindert, dass die Struktur-Analyse in endlose Review-Schleifen gerät.
