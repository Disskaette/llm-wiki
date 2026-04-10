---
name: [skill-name]
description: [Einzeiler — was macht dieser Skill?]
---

## Governance-Vertrag

> Governance (Hard Gates) ist permanent im System-Kontext aktiv.
> Dieser Skill ist verantwortlich fuer: [relevante Gates].
> Subagent-Dispatch ist IRON LAW — kein Output ohne Review.

| Gate | Durchsetzung | Wie |
|------|-------------|-----|
| KEIN-BUCH-OHNE-VOLLSTAENDIGE-LESUNG | ✅/🔄/⚪ | [Wie] |
| KEIN-INHALT-OHNE-SEITENANGABE | ✅/🔄/⚪ | [Wie] |
| KEIN-ZAHLENWERT-OHNE-QUELLE | ✅/🔄/⚪ | [Wie] |
| KEIN-NORMBEZUG-OHNE-ABSCHNITT | ✅/🔄/⚪ | [Wie] |
| KEINE-KONZEPTSEITE-OHNE-QUERVERWEIS | ✅/🔄/⚪ | [Wie] |
| KEIN-SCHLAGWORT-OHNE-VOKABULAR | ✅/🔄/⚪ | [Wie] |
| KEIN-UPDATE-OHNE-DIFF | ✅/🔄/⚪ | [Wie] |
| KEIN-WIDERSPRUCH-OHNE-MARKIERUNG | ✅/🔄/⚪ | [Wie] |
| KEINE-WIKI-AENDERUNG-OHNE-QUELLENLESUNG | ✅/🔄/⚪ | [Wie] |
| KORREKTE-UMLAUTE | ✅/🔄/⚪ | [Wie] |

---

## Phasen

### Phase 0: Kontext + Vorpruefung

1. [Was muss gelesen/geprueft werden bevor die Arbeit beginnt?]
2. [Welche Dateien werden als Input benoetigt?]

### Phase 0.5: Planmodus-Pruefung

Wenn diese Aktion >=3 Dateien betrifft:
→ EnterPlanMode BEVOR die erste Datei editiert wird.

### Phase N: [Kernarbeit]

[Die eigentliche Arbeit des Skills]

### Phase N+1: Subagent dispatchen (IRON LAW)

Dispatch: `[agent-name]` via Agent-Tool.
- Bei FAIL: Korrigieren → erneut dispatchen
- Max 3 Iterationen, dann an den Nutzer eskalieren

### Phase N+2: Nebeneffekte + Abschluss (BLOCKER)

Pflicht-Nebeneffekte (falls zutreffend):
- [ ] _index/ aktualisieren (betroffene Teilindizes)
- [ ] _log.md Eintrag schreiben
- [ ] Betroffene MOCs aktualisieren
- [ ] _vokabular.md aktualisieren (neue Terme via /vokabular)

"Mach ich spaeter" ist VERBOTEN.
