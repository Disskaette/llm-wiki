# Zuordnung-Worker — Dispatch-Template

> Dieses Template wird vom `/zuordnung`-Skill in Phase 1 verwendet.
> ALLE Platzhalter muessen vom Orchestrator befuellt werden.
> Der Worker liest KEINE Dateien selbst — alles wird inline eingefuegt.

## Platzhalter

| Platzhalter | Quelle | Beschreibung |
|-------------|--------|--------------|
| `{{QUELLEN_ZUSAMMENFASSUNGEN}}` | Alle `wiki/quellen/*.md` | Frontmatter + erste 50 Zeilen Body jeder Quellenseite |
| `{{KONZEPTE_ZUSAMMENFASSUNGEN}}` | Alle `wiki/konzepte/*.md` | Frontmatter + Zusammenfassung jeder Konzeptseite |
| `{{VOKABULAR}}` | `wiki/_vokabular.md` | Kontrolliertes Vokabular (kompletter Inhalt) |
| `{{KONZEPT_REIFE}}` | `wiki/_konzept-reife.md` | Reife-Tracker (kompletter Inhalt, falls vorhanden) |
| `{{LOG_HASH}}` | `wiki/_log.md` | Erster Satz des juengsten Eintrags (Drift-Erkennung) |
| `{{WIKI_VERZEICHNIS}}` | `ls wiki/` | Verzeichnisstruktur fuer Pfad-Aufloesung |

---

## Prompt-Template (ab hier wird an den Subagent uebergeben)

```
Du bist der Zuordnung-Worker des Bibliothek-Plugins.
Dein Auftrag: ALLE Quellen inhaltlich zu ALLEN Konzepten zuordnen,
Schlagwort-Audit durchfuehren und Frontmatter patchen.

═══════════════════════════════════════════════════════
KONTEXT
═══════════════════════════════════════════════════════

Wiki-Verzeichnis:   {{WIKI_VERZEICHNIS}}
Letzter Log-Hash:   {{LOG_HASH}}

[ZUORDNUNG-ID:mapping]

═══════════════════════════════════════════════════════
QUELLEN (INLINE)
═══════════════════════════════════════════════════════

Frontmatter + erste 50 Zeilen Body jeder Quellenseite.
Das sind ALLE Quellen im Wiki — keine ist ausgelassen.

{{QUELLEN_ZUSAMMENFASSUNGEN}}

═══════════════════════════════════════════════════════
KONZEPTE (INLINE)
═══════════════════════════════════════════════════════

Frontmatter + Zusammenfassung jeder Konzeptseite.
Das sind ALLE Konzepte im Wiki — keine ist ausgelassen.

{{KONZEPTE_ZUSAMMENFASSUNGEN}}

═══════════════════════════════════════════════════════
VOKABULAR (INLINE)
═══════════════════════════════════════════════════════

Kontrolliertes Vokabular — nur diese Terme duerfen als Schlagworte verwendet werden.

{{VOKABULAR}}

═══════════════════════════════════════════════════════
KONZEPT-REIFE (INLINE)
═══════════════════════════════════════════════════════

Reife-Tracker fuer Konzept-Kandidaten.
Falls leer: kein _konzept-reife.md vorhanden — du bootstrapst die Datei.

{{KONZEPT_REIFE}}

═══════════════════════════════════════════════════════
CONTEXT-BUDGET — FAKTEN
═══════════════════════════════════════════════════════

Du laeuft als Opus-Worker mit 1.000.000 Tokens Context.
Alle Quellen-Zusammenfassungen (50 Zeilen je) belegen typischerweise 20-80K Tokens.
Du hast IMMER genug Platz fuer alle Quellen und alle Konzepte.

KEIN SPLIT erforderlich — auch nicht bei 100+ Quellen.
KEIN Aufteilen auf mehrere Agents.
KEIN "ich mache das in Batches".

Wenn du glaubst der Context reicht nicht: Du hast 1M Tokens.
Lies alle Quellen. Lies alle Konzepte. Bau die Matrix. Fertig.

═══════════════════════════════════════════════════════
AUFTRAG — 3 JOBS IN EINEM DURCHLAUF
═══════════════════════════════════════════════════════

Fuehre ALLE drei Jobs in einem einzigen Durchlauf aus.
Kein Split, kein Batch, keine Teillieferung.

---

Job 1: Quelle → Konzept (inhaltliches Matching)

Fuer JEDE Quelle: Welche Konzeptseiten behandelt sie substanziell?

NICHT nur nach Schlagwort-Ueberlappung pruefen — INHALTLICH:
Hat die Quelle ein Kapitel oder einen Abschnitt der das Konzept wesentlich
beleuchtet? Eine Quelle die "Indirekte Auflagerung" nur im Glossar erwaehnt
aber kein eigenes Kapitel dazu hat → KEINE Zuordnung.

Pro Zuordnung: 1-Satz-Begruendung (z.B. "Kap. 8 behandelt ausfuehrlich
Auflagerdetails fuer indirekte Uebertragung").

Neue Kandidaten: Wenn ein Thema in >=2 Quellen substanziell behandelt wird
aber weder als Konzeptseite noch als Kandidat in _konzept-reife.md existiert
→ neuer Kandidat (direkt in _konzept-reife.md schreiben).

Nicht zugeordnete Quellen: EXPLIZIT listen mit Begruendung
(z.B. "Thematisch ausserhalb des aktuellen Wiki-Fokus").

---

Job 2: Schlagwort-Audit

Fuer JEDE Quelle:
Behandelt sie ein Thema ausfuehrlich das NICHT in ihren schlagworte: steht?
→ Patch-Vorschlag mit Evidenz (Kapitelverweis)

Neue Terme: Fachbegriffe die in >=2 Quellen substanziell vorkommen
und im Vokabular fehlen → Vorschlag fuer _vokabular.md
(Eintrag direkt schreiben, nur additiv).

Rueckwaertsverteilung PFLICHT: Wenn ein neues Schlagwort eingefuehrt wird,
ALLE Quellen im Wiki identifizieren die es erhalten sollten — nicht nur
die gerade bearbeiteten.

---

Job 3: relevant-fuer: Feld patchen

Fuer JEDE Quellenseite die mindestens einer Konzeptseite zugeordnet wurde:
Patche das Frontmatter-Feld `relevant-fuer:` mit der Liste der Konzeptseiten
(Dateinamen ohne .md, lowercase).

NUR ADDITIV — bestehende Eintraege in relevant-fuer: NIEMALS entfernen.
Konsistent mit der Zuordnungs-Matrix aus Job 1.

Beispiel Frontmatter nach Patch:
  schlagworte: [Aufhaengebewehrung, Indirekte Auflagerung, Querkraft]
  relevant-fuer: [aufhaengebewehrung, indirekte-auflagerung, direkte-auflagerung]

═══════════════════════════════════════════════════════
REGELN — NICHT VERHANDELBAR
═══════════════════════════════════════════════════════

- NUR ADDITIV: Schlagworte, relevant-fuer, Vokabular, Konzept-Reife
  → Bestehende Eintraege NIEMALS entfernen oder ueberschreiben
- Schlagworte NUR aus dem kontrollierten Vokabular (oben inline)
  → Neuer Term fehlt im Vokabular? Erst in _vokabular.md eintragen, dann patchen
- _konzept-reife.md direkt schreiben (neue Kandidaten als unreif/reif basierend
  auf Quellen-Anzahl: >=2 Quellen substanziell = reif, 1 Quelle = unreif)
- _quellen-mapping.md KOMPLETT NEU schreiben (kein Merge mit alter Version)
- Kein Split, kein Batch — alle Quellen in einem Durchlauf
- Deutsche Umlaute im Wiki-Text, ASCII in Dateinamen und Frontmatter-Werten

═══════════════════════════════════════════════════════
EXAKTE OUTPUT-STRUKTUR
═══════════════════════════════════════════════════════

Schritt 1: _quellen-mapping.md komplett neu schreiben

Frontmatter PFLICHT:
---
type: meta
title: "Quellen-Zuordnung"
updated: YYYY-MM-DD
mapping-version: N
quellen-stand: N
konzepte-stand: N
kandidaten-stand: N
letzter-log-hash: "{{LOG_HASH}}"
---

Body-Struktur:
# Quellen-Zuordnung

## Zuordnungs-Matrix

| Quelle | Konzepte | Kandidaten | Begruendung |
|--------|----------|------------|-------------|
| [[quellenkey]] | [[konzept1]], [[konzept2]] | Kandidatname | 1-Satz-Begruendung |
| ... | ... | ... | ... |

## Nicht zugeordnete Quellen

Quellen die keinem Konzept und keinem Kandidaten zugeordnet werden konnten:
- [[quellenkey]] — Grund: ...

## Schlagwort-Audit

### Fehlende Zuordnungen (Patches)
| Quelle | Fehlendes Schlagwort | Evidenz |
|--------|---------------------|---------|
| [[quellenkey]] | Termname | Kap. X, S. Y-Z |

### Neue Terme (Vokabular-Vorschlaege)
| Term | Quellen | Status |
|------|---------|--------|
| Termname | quellenkey-a, quellenkey-b | eingetragen |

## Konzept-Kandidaten (neu entdeckt)
| Kandidat | Quellen (>=2) | Reife |
|----------|---------------|-------|
| Kandidatname | quellenkey-a, quellenkey-b | reif |

Schritt 2: Quellenseiten-Patches (Edit-Tool)

Fuer jede Quellenseite mit neuen Schlagworten oder Konzept-Rueckverweisen:
- schlagworte:-Feld erweitern (nur additiv)
- relevant-fuer:-Feld setzen oder erweitern (nur additiv)

Schritt 3: _vokabular.md Ergaenzungen (Edit-Tool, nur additiv)

Schritt 4: _konzept-reife.md Ergaenzungen (neue Kandidaten eintragen)

═══════════════════════════════════════════════════════
PIPELINE-ID (PFLICHT — fuer Hook-Matching)
═══════════════════════════════════════════════════════

Gib am Ende deines Ergebnis-Berichts diese Zeile zurueck:
[ZUORDNUNG-ID:mapping]
```
