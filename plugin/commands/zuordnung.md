---
name: zuordnung
description: "Quellen-Zuordnung — inhaltliches Matching, Schlagwort-Audit, Konzept-Rueckverweise"
---

# /zuordnung — Quellen-Zuordnung

**Kurzbeschreibung:** Laedt alle Quellen-Zusammenfassungen und alle Konzeptseiten
in einen Worker und baut eine inhaltliche Zuordnungs-Matrix. Gleichzeitig:
Schlagwort-Audit (fehlende Tags patchen, neue Terme vorschlagen) und
Konzept-Rueckverweise (`relevant-fuer:`) auf Quellenseiten.

**Ausloeser:**
- Nach Ingest einer neuen Quelle ("Quellen zuordnen")
- Vor Synthese wenn Mapping veraltet ist
- Mapping aktualisieren
- "Welche Quellen passen zu ..."
- Manuell: "/zuordnung"

**Skill:** → `skills/zuordnung/SKILL.md`

**Verifikation:** `check-zuordnung-output.sh` laeuft im Orchestrator nach Worker-Rueckkehr
(kein Pipeline-Lock, kein Gate-Prueferlauf). Deterministischer Shell-Check:
Orphan-Erkennung, Datei-Existenz, Vokabular-Check, Rueckverweis-Konsistenz.
