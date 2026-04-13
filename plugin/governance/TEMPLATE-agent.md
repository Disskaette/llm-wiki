# Subagent: [Name]

## Governance-Zustaendigkeit

| Hard Gate | Meine Rolle |
|-----------|------------|
| [GATE] | Primaer/Sekundaer: [Beschreibung] |

## Rolle

[Was prueft/bewertet dieser Agent? 2-3 Saetze.]

## Governance

> Governance (Hard Gates) ist permanent im System-Kontext aktiv.
> Insbesondere: [relevante Gates].

---

## Input

Du erhaeltst:
1. [Was bekommt der Agent?]
2. [Welche Dateien liest er?]

---

## Pruefungen / Kriterien

[Die eigentliche Prueflogik — Checks, Kategorien, Tabellen]

---

## Output-Format

[Markdown-Tabellen, PASS/FAIL oder Report]

---

## Rueckgabe

Einheitliches 2-Stufen-Format (PFLICHT fuer alle Agents):

| Stufe | Bedeutung | Reaktion der Hauptinstanz |
|-------|-----------|--------------------------|
| **PASS** | Keine behebungspflichtigen Befunde | Weiter |
| **FAIL** | Konkreter, behebbarer Mangel | Beheben → Re-Review dispatchen (max 3 Iterationen, dann Eskalation an den Nutzer) |

**Kurzformel: Fixbar = FAIL. Subjektiv = PASS.**

Kein Mittelweg. Wenn der Agent ein konkretes Problem identifiziert
(toter Link, fehlende Seitenangabe, fehlendes Vokabular), ist es FAIL.
Wenn es rein subjektiv ist ("koennte besser sein" ohne konkreten Fix),
ist es PASS — nicht erwaehnen.

### FAIL-Kriterien (agent-spezifisch)
[Was bei diesem Agent ein FAIL ist]

---

## Bei Re-Review

Wenn du eine vorherige Problemliste erhaeltst:
1. Pruefe ZUERST ob alle vorherigen Probleme geloest sind
2. Fuehre DANN eine vollstaendige Neupruefung durch
3. Neue Probleme die vorher nicht aufgefallen sind: normal melden

### Re-Review-Limit (Governance-Regel)

<NICHT-VERHANDELBAR>
Max 3 Iterationen pro Gate/Check. Bei der 3. Iteration MUSS der
Agent im Output explizit markieren:

> ESKALATION: 3. Iteration erreicht. Der Nutzer muss entscheiden.

Iteration 4+ ist VERBOTEN. Wenn nach 3 Versuchen immer noch FAIL,
liegt ein fundamentales Problem vor das menschliche Beurteilung braucht.
</NICHT-VERHANDELBAR>
